## Pure need/greed loot-roll helper (GID-102 / TID-381) — mirrors WorldObjectSync.gd's style.
##
## An opt-in alternative to the GID-096 first-opener-takes chest rule: when a session has
## `SessionState.loot_mode == LOOT_MODE_NEED_GREED`, the authority opens a roll session for a
## shared chest drop instead of granting it straight to the opener. Every present member
## submits a `need` / `greed` / `pass` choice; the **authority** rolls the random value for
## each non-pass entrant (never the client) so the outcome is tamper-proof, then resolves the
## winner: need beats greed, ties within the same tier broken by the highest rolled value, and
## an all-pass roll has no winner.
##
## Callers: preload("res://game_logic/net/LootRoll.gd"). No scene dependencies —
## fully unit-testable. JSON-primitive payloads only.
extends RefCounted

const CHOICE_NEED: String = "need"
const CHOICE_GREED: String = "greed"
const CHOICE_PASS: String = "pass"

## Precedence tier per choice — higher wins. Anything unrecognized is treated as a pass.
const _TIER: Dictionary = {
	"need": 2,
	"greed": 1,
	"pass": 0,
}

const _ROLL_MIN: int = 1
const _ROLL_MAX: int = 100

## Equipment drop chance (BID-033) — matches the existing single-player /
## first-opener chest-drop table (WorldScene._open_chest / _maybe_drop_equipment_from_chest):
## treasure-room chests (tier 3, `dtr_` ids) roll higher than the default.
const EQUIPMENT_CHANCE_TREASURE_ROOM: float = 0.40
const EQUIPMENT_CHANCE_DEFAULT: float = 0.15


## Normalize a raw choice string to one of the three constants; anything else -> pass.
static func normalize_choice(choice: String) -> String:
	if choice == CHOICE_NEED or choice == CHOICE_GREED:
		return choice
	return CHOICE_PASS


# ---------------------------------------------------------------------------
# Wire format — authority -> all: open a roll prompt for an item.
# ---------------------------------------------------------------------------

## Pack the roll-start broadcast. `item` is a small JSON-primitive description
## (e.g. {"card_ids": [...], "tier": 2, "coins": 12}) shown in the prompt UI.
## `participant_tokens` is the set of session tokens expected to respond.
static func encode_start(roll_id: String, item: Dictionary, participant_tokens: Array) -> Dictionary:
	var tokens: Array = []
	for t in participant_tokens:
		tokens.append(str(t))
	return {
		"roll_id": str(roll_id),
		"item": (item as Dictionary).duplicate(true) if item is Dictionary else {},
		"participants": tokens,
	}


## Unpack a roll-start payload. Garbage/missing fields fall back to safe defaults.
static func decode_start(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"roll_id": "", "item": {}, "participants": []}
	var item: Variant = payload.get("item", {})
	var participants: Variant = payload.get("participants", [])
	var parts: Array = []
	if participants is Array:
		for t in participants:
			parts.append(str(t))
	return {
		"roll_id": str(payload.get("roll_id", "")),
		"item": (item as Dictionary).duplicate(true) if item is Dictionary else {},
		"participants": parts,
	}


# ---------------------------------------------------------------------------
# Wire format — client -> authority: a single participant's need/greed/pass choice.
# ---------------------------------------------------------------------------

static func encode_choice(roll_id: String, choice: String) -> Array:
	return [str(roll_id), normalize_choice(choice)]


## Unpack a choice intent. Garbage/short payload -> {roll_id:"", choice:"pass"} (ignored
## by callers when roll_id is blank).
static func decode_choice(payload: Variant) -> Dictionary:
	if not (payload is Array) or payload.size() < 2:
		return {"roll_id": "", "choice": CHOICE_PASS}
	return {
		"roll_id": str(payload[0]),
		"choice": normalize_choice(str(payload[1])),
	}


# ---------------------------------------------------------------------------
# Wire format — authority -> all: the resolved outcome.
# ---------------------------------------------------------------------------

## Pack the result broadcast. `rolls` is {token: int} for every non-pass entrant (so the UI
## can show what everyone rolled); `winner_token == ""` means nobody won (all passed).
static func encode_result(roll_id: String, winner_token: String, rolls: Dictionary) -> Dictionary:
	var r: Dictionary = {}
	for k in rolls.keys():
		r[str(k)] = int(rolls[k])
	return {
		"roll_id": str(roll_id),
		"winner_token": str(winner_token),
		"rolls": r,
	}


static func decode_result(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"roll_id": "", "winner_token": "", "rolls": {}}
	var rolls: Variant = payload.get("rolls", {})
	var out_rolls: Dictionary = {}
	if rolls is Dictionary:
		for k in (rolls as Dictionary).keys():
			out_rolls[str(k)] = int((rolls as Dictionary)[k])
	return {
		"roll_id": str(payload.get("roll_id", "")),
		"winner_token": str(payload.get("winner_token", "")),
		"rolls": out_rolls,
	}


# ---------------------------------------------------------------------------
# Core resolver — authority only calls this (it owns the RNG).
# ---------------------------------------------------------------------------

## Resolve the winner of a need/greed roll. `choices` is {token: "need"|"greed"|"pass"}
## (unrecognized values normalize to pass). `rng` is an injected RandomNumberGenerator so
## callers (and tests) can seed it for determinism — the authority is the only one that ever
## calls this, keeping the outcome tamper-proof (clients never see or influence the roll value).
##
## Precedence: need beats greed beats pass. Within the same tier, the highest rolled value
## (1–100) wins; a genuine tie (identical rolled value) is broken by picking the
## alphabetically-first token, which is deterministic and reproducible for tests. Returns
## {"winner_token": String, "rolls": {token: int}}. `rolls` only contains non-pass entrants.
## `winner_token == ""` when every entrant passed (or `choices` is empty).
static func resolve_winner(choices: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rolls: Dictionary = {}
	var best_tier: int = -1
	var best_value: int = -1
	var winner: String = ""
	# Deterministic iteration order so ties resolve reproducibly regardless of Dictionary
	# key insertion order.
	var tokens: Array = []
	for t in choices.keys():
		tokens.append(str(t))
	tokens.sort()
	for token: String in tokens:
		var choice: String = normalize_choice(str(choices[token]))
		if choice == CHOICE_PASS:
			continue
		var value: int = rng.randi_range(_ROLL_MIN, _ROLL_MAX)
		rolls[token] = value
		var tier: int = int(_TIER.get(choice, 0))
		if tier > best_tier or (tier == best_tier and value > best_value):
			best_tier = tier
			best_value = value
			winner = token
	return {"winner_token": winner, "rolls": rolls}


# ---------------------------------------------------------------------------
# Equipment drop-into-the-roll-pool (BID-033) — authority only calls this,
# same RNG-injection contract as resolve_winner above.
# ---------------------------------------------------------------------------

## Rolls whether a chest's resolved loot-roll pool includes one equipment piece, and
## if so, picks which one — mirroring `WorldScene._maybe_drop_equipment_from_chest`'s
## own chance/candidate logic exactly, but pure and injectable (weapon/armor id
## catalogs, the recipient's current ownership, and the RNG are all passed in) so it
## needs neither a live SaveManager nor a live SessionStore to test or call.
##
## `tier` is the chest tier (3 == a `dtr_` treasure-room chest, which rolls at
## `EQUIPMENT_CHANCE_TREASURE_ROOM`; anything else rolls at `EQUIPMENT_CHANCE_DEFAULT`).
## `weapon_ids` / `armor_ids` are the full catalog ids for those two slots (callers pass
## `WeaponRegistry.get_by_slot("weapon"/"armor")`); the starter `"rusty_dagger"` weapon
## is excluded from the pool, matching the single-player table. `owned_weapon_ids` /
## `owned_armor_ids` are the recipient's own current ownership (already-owned ids are
## never re-offered, so a roll winner can't receive a duplicate). `rng` is an injected
## `RandomNumberGenerator` so callers (and tests) can seed it for determinism, and so
## the authority remains the only side that ever rolls this value.
##
## Returns the picked id, or `""` when the chance roll fails or every candidate in
## both pools is already owned (nothing left to drop).
static func roll_equipment_drop(tier: int, weapon_ids: Array, armor_ids: Array,
		owned_weapon_ids: Array, owned_armor_ids: Array, rng: RandomNumberGenerator) -> String:
	var chance: float = EQUIPMENT_CHANCE_TREASURE_ROOM if tier == 3 else EQUIPMENT_CHANCE_DEFAULT
	if rng.randf() >= chance:
		return ""
	var candidates: Array[String] = []
	for wid: Variant in weapon_ids:
		var w: String = str(wid)
		if w != "" and w != "rusty_dagger" and not owned_weapon_ids.has(w):
			candidates.append(w)
	for aid: Variant in armor_ids:
		var a: String = str(aid)
		if a != "" and not owned_armor_ids.has(a):
			candidates.append(a)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]
