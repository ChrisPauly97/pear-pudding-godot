## Pure data model for a persistent multiplayer session (GID-095 / TID-345).
##
## Owned by the **authority** — the host in the listen-server model, a dedicated
## server in GID-097. Splits pure serialization (this file, unit-testable like
## `GameState`) from authority-side file I/O (`SessionStore` autoload).
##
## Holds shared world progress plus a roster of per-player **character records**
## keyed by the GID-094 identity token (`MpProfile.get_token()`). A character record
## is the per-player slice that is *scoped to the session* — its own deck, inventory,
## coins, level, skills and position, entirely separate from single-player `save.json`.
##
## JSON-primitive only (Dictionary / Array / String / int / float / bool — no engine
## objects) so `to_dict()` / `from_dict()` round-trip cleanly through the session file.
##
## Callers: preload("res://game_logic/net/SessionState.gd"). No scene dependencies.
class_name SessionState
extends RefCounted

const _CardInstanceUtil = preload("res://game_logic/CardInstanceUtil.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")

## Bump when the on-disk shape changes; `from_dict` runs `_apply_migrations` so old
## session files keep loading (mirrors SaveManager.CURRENT_SAVE_VERSION).
## v2 — adds party_bounties shared progress (TID-369).
## v3 — adds pvp_wins/losses/streak/best_streak per character (TID-368).
## v4 — adds pvp_rating/pvp_games per character for the ranked ladder (TID-370).
## v5 — adds a shared party stash: {cards: Array, coins: int} (GID-102 / TID-376).
## v6 — adds `leaderboards` {spire, coop_clears} PvE score boards (TID-379).
## v7 — adds loot_mode session setting for need/greed chest rolls (TID-381).
const CURRENT_SESSION_VERSION: int = 7

## Cap applied to each PvE leaderboard array by record_pve_score (top N kept).
const PVE_LEADERBOARD_CAP: int = 20

## Loot distribution modes (TID-381). Default keeps the original GID-096
## first-opener-takes behaviour; need/greed is an opt-in host-only setting.
const LOOT_MODE_FIRST_OPENER: String = "first_opener"
const LOOT_MODE_NEED_GREED: String = "need_greed"

## Starter deck template ids — mirrors `SaveManager.new_game` / `ensure_coop_deck`
## so a freshly created session character can battle immediately.
const _STARTER_DECK: Array[String] = [
	"ghost", "skeleton", "zombie", "ghoul",
	"ghost", "skeleton", "zombie", "ghoul",
	"ghost", "skeleton", "zombie", "ghoul",
]
const _STARTER_COINS: int = 200

# --- Identity ---------------------------------------------------------------
var session_id: String = ""
var display_name: String = "Session"

# --- Shared world progress (authority-owned, same for all members) ----------
var current_map: String = "madrian"
var world_seed: int = 42
var time_of_day: float = 0.4
var days_elapsed: int = 0
var defeated_enemies: Array = []
var opened_chests: Array = []
var story_flags: Dictionary = {}

# --- Roster: token -> character record dict ---------------------------------
var members: Dictionary = {}

# --- Shared party bounties (GID-101 / TID-369) ----------------------------
# Array of bounty dicts with shared progress across all party members.
# Shape: {id, type, target, count, progress, contributors: [tokens], completed}
var party_bounties: Array = []

# --- Shared party stash (GID-102 / TID-376) ---------------------------------
# A session-owned chest any member can deposit into / withdraw from. `cards` holds
# full card instance dicts (same shape as a member's owned_cards, via CardInstanceUtil),
# re-keyed into a stash-namespaced uid on deposit. `coins` is a simple shared int pool.
var stash: Dictionary = {"cards": [], "coins": 0}

# --- PvE leaderboards (GID-102 / TID-379) -----------------------------------
# Authority-owned, session-scoped best-score boards. Distinct from the PvP
# `get_leaderboard()` ranked-rating board above (TID-370/373) — this is PvE
# achievement (Endless Spire runs, co-op boss clears), never touches rating.
# Shape: {spire: Array, coop_clears: Array}, each entry {token, name, value, day}.
var leaderboards: Dictionary = {"spire": [], "coop_clears": []}

# --- Loot distribution mode (GID-102 / TID-381) -----------------------------
# Host-only session setting; LOOT_MODE_FIRST_OPENER (default) or LOOT_MODE_NEED_GREED.
var loot_mode: String = LOOT_MODE_FIRST_OPENER


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": CURRENT_SESSION_VERSION,
		"session_id": session_id,
		"display_name": display_name,
		"current_map": current_map,
		"world_seed": world_seed,
		"time_of_day": time_of_day,
		"days_elapsed": days_elapsed,
		"defeated_enemies": defeated_enemies.duplicate(),
		"opened_chests": opened_chests.duplicate(),
		"story_flags": story_flags.duplicate(true),
		"members": members.duplicate(true),
		"party_bounties": party_bounties.duplicate(true),
		"stash": stash.duplicate(true),
		"leaderboards": leaderboards.duplicate(true),
		"loot_mode": loot_mode,
	}


## Rebuild a SessionState from a parsed dict. Always returns a valid object; missing
## or garbage fields fall back to safe defaults so a corrupt file can't crash load.
static func from_dict(data: Dictionary) -> SessionState:
	_apply_migrations(data)
	var s := SessionState.new()
	s.session_id = str(data.get("session_id", ""))
	s.display_name = str(data.get("display_name", "Session"))
	s.current_map = str(data.get("current_map", "madrian"))
	s.world_seed = int(data.get("world_seed", 42))
	s.time_of_day = float(data.get("time_of_day", 0.4))
	s.days_elapsed = int(data.get("days_elapsed", 0))
	var de: Variant = data.get("defeated_enemies", [])
	s.defeated_enemies = (de as Array).duplicate() if de is Array else []
	var oc: Variant = data.get("opened_chests", [])
	s.opened_chests = (oc as Array).duplicate() if oc is Array else []
	var sf: Variant = data.get("story_flags", {})
	s.story_flags = (sf as Dictionary).duplicate(true) if sf is Dictionary else {}
	var mem: Variant = data.get("members", {})
	s.members = (mem as Dictionary).duplicate(true) if mem is Dictionary else {}
	var pb: Variant = data.get("party_bounties", [])
	s.party_bounties = (pb as Array).duplicate(true) if pb is Array else []
	var stash_v: Variant = data.get("stash", {})
	if stash_v is Dictionary:
		var stash_dict: Dictionary = (stash_v as Dictionary).duplicate(true)
		var stash_cards: Variant = stash_dict.get("cards", [])
		s.stash = {
			"cards": (stash_cards as Array).duplicate(true) if stash_cards is Array else [],
			"coins": int(stash_dict.get("coins", 0)),
		}
	else:
		s.stash = {"cards": [], "coins": 0}
	var lb: Variant = data.get("leaderboards", {})
	s.leaderboards = _sanitized_leaderboards(lb as Dictionary if lb is Dictionary else {})
	var lm: String = str(data.get("loot_mode", LOOT_MODE_FIRST_OPENER))
	s.loot_mode = lm if lm == LOOT_MODE_NEED_GREED else LOOT_MODE_FIRST_OPENER
	return s


## Always returns a dict with both "spire" and "coop_clears" Array keys, discarding
## any garbage-typed input so a corrupt/legacy file can never crash a caller that
## assumes the shape (mirrors the tolerant fallback pattern used throughout this file).
static func _sanitized_leaderboards(raw: Dictionary) -> Dictionary:
	var spire: Variant = raw.get("spire", [])
	var coop: Variant = raw.get("coop_clears", [])
	return {
		"spire": (spire as Array).duplicate(true) if spire is Array else [],
		"coop_clears": (coop as Array).duplicate(true) if coop is Array else [],
	}


## Forward-migration scaffold. Entries run in ascending order; each backfills the
## fields a new version added. Mirrors SaveManager._apply_migrations so future
## session-format changes never break existing files.
static func _apply_migrations(data: Dictionary) -> void:
	var ver: int = int(data.get("version", 0))
	if ver < 2:
		# v2: add party_bounties field.
		if not data.has("party_bounties"):
			data["party_bounties"] = []
		data["version"] = 2
	if ver < 3:
		# v3: add pvp stats to each member character record.
		var members: Variant = data.get("members", {})
		if members is Dictionary:
			for token in members.keys():
				var rec: Variant = members[token]
				if rec is Dictionary:
					if not (rec as Dictionary).has("pvp_wins"):
						(rec as Dictionary)["pvp_wins"] = 0
					if not (rec as Dictionary).has("pvp_losses"):
						(rec as Dictionary)["pvp_losses"] = 0
					if not (rec as Dictionary).has("pvp_streak"):
						(rec as Dictionary)["pvp_streak"] = 0
					if not (rec as Dictionary).has("pvp_best_streak"):
						(rec as Dictionary)["pvp_best_streak"] = 0
		data["version"] = 3
	if ver < 4:
		# v4: add pvp_rating/pvp_games to each member character record.
		var members_v4: Variant = data.get("members", {})
		if members_v4 is Dictionary:
			for token in members_v4.keys():
				var rec: Variant = members_v4[token]
				if rec is Dictionary:
					if not (rec as Dictionary).has("pvp_rating"):
						(rec as Dictionary)["pvp_rating"] = 1000
					if not (rec as Dictionary).has("pvp_games"):
						(rec as Dictionary)["pvp_games"] = 0
		data["version"] = 4
	if ver < 5:
		# v5: add the shared party stash.
		if not data.has("stash"):
			data["stash"] = {"cards": [], "coins": 0}
		data["version"] = 5
	if ver < 6:
		# v6: add the leaderboards {spire, coop_clears} PvE score boards.
		if not data.has("leaderboards"):
			data["leaderboards"] = {"spire": [], "coop_clears": []}
		data["version"] = 6
	if ver < 7:
		# v7: add loot_mode session setting (defaults to first-opener-takes so
		# existing sessions keep their original behaviour unchanged).
		if not data.has("loot_mode"):
			data["loot_mode"] = LOOT_MODE_FIRST_OPENER
		data["version"] = 7
	if ver < CURRENT_SESSION_VERSION:
		data["version"] = CURRENT_SESSION_VERSION


# ---------------------------------------------------------------------------
# Member roster
# ---------------------------------------------------------------------------

func has_member(token: String) -> bool:
	return token != "" and members.has(token)


## The character record for a token, or {} if none exists yet.
func get_member(token: String) -> Dictionary:
	var rec: Variant = members.get(token, null)
	return rec if rec is Dictionary else {}


## Return the existing record for `token`, or create + store a seeded starter and
## return it. The display name is refreshed on every call so a returning player's
## latest lobby name is kept without disturbing their progress.
func ensure_member(token: String, member_name: String = "Player") -> Dictionary:
	if has_member(token):
		var existing: Dictionary = members[token]
		existing["display_name"] = member_name
		members[token] = existing
		return existing
	var rec: Dictionary = make_starter_character(token, member_name)
	members[token] = rec
	return rec


## Replace the stored record for `token` (persist-back path; authority only).
func update_member(token: String, record: Dictionary) -> void:
	if token == "":
		return
	members[token] = record


# ---------------------------------------------------------------------------
# Ghost duel snapshots (GID-102 / TID-377)
# ---------------------------------------------------------------------------

## Derive a playable "ghost" opponent snapshot from a member's character record —
## no second source of truth (never persisted separately). Used by
## `SceneManager.enter_ghost_duel` to build a local, AI-piloted (BasicAI) copy of
## another (possibly offline) session member's deck: async competition, zero live
## networking. Returns `{}` for a blank/unknown token or a corrupt (non-Dictionary)
## record — never throws.
##
## `player_deck` is stored as a list of card-instance UIDs (per-instance rolled
## stats); the ghost only needs a playable deck of template ids, so each UID is
## resolved against `owned_cards`. A UID with no matching owned-card entry is
## silently skipped (the ghost fields a slightly smaller deck) rather than
## crashing — a corrupt/edited session file must never break a duel.
##
## Returns `{token, name, deck: Array[String], rating}`. No `color` field:
## character records don't store one (color is a device-local MpProfile/identity
## concept, not part of the session character).
func get_ghost_snapshot(token: String) -> Dictionary:
	if token == "" or not has_member(token):
		return {}
	var rec: Variant = members.get(token, null)
	if not (rec is Dictionary):
		return {}
	var r: Dictionary = rec
	var owned: Variant = r.get("owned_cards", [])
	var uid_to_template: Dictionary = {}
	if owned is Array:
		for inst: Variant in (owned as Array):
			if inst is Dictionary:
				var idict: Dictionary = inst
				uid_to_template[str(idict.get("uid", ""))] = str(idict.get("template_id", ""))
	var deck: Array[String] = []
	var pdeck: Variant = r.get("player_deck", [])
	if pdeck is Array:
		for uid: Variant in (pdeck as Array):
			var tid: String = str(uid_to_template.get(str(uid), ""))
			if tid != "":
				deck.append(tid)
	return {
		"token": token,
		"name": str(r.get("display_name", "Player")),
		"deck": deck,
		"rating": int(r.get("pvp_rating", 1000)),
	}


# ---------------------------------------------------------------------------
# Starter character
# ---------------------------------------------------------------------------

## Build a fresh session character: the 12-card starter deck (same templates as
## single-player `new_game`), a small coin float, and default progression. UIDs are
## salted with the token so instances from different members never collide in one file.
static func make_starter_character(token: String, member_name: String) -> Dictionary:
	var owned: Array = []
	var deck: Array = []
	var counter: int = 0
	for tid: String in _STARTER_DECK:
		var tmpl: Dictionary = _CardRegistry.get_template(tid)
		var uid: String = "%s_%s_%d" % [tid, token, counter]
		counter += 1
		owned.append(_CardInstanceUtil.make(
			uid, tid, "common",
			int(tmpl.get("attack", 0)), int(tmpl.get("health", 0)), int(tmpl.get("cost", 1))))
		deck.append(uid)
	return {
		"token": token,
		"display_name": member_name,
		"owned_cards": owned,
		"player_deck": deck,
		"coins": _STARTER_COINS,
		"essence": 0,
		"xp": 0,
		"level": 1,
		"skill_points": 0,
		"unlocked_skills": [],
		"magic_type": "",
		"corruption_points": 0,
		"redemption_points": 0,
		"map": "madrian",
		"x": 0.0,
		"z": 0.0,
		# PvP champion record (GID-101 / TID-368)
		"pvp_wins": 0,
		"pvp_losses": 0,
		"pvp_streak": 0,
		"pvp_best_streak": 0,
		# PvP ranked rating (GID-102 / TID-370)
		"pvp_rating": 1000,
		"pvp_games": 0,
	}


## Cross-session ranked leaderboard, derived from the member roster so there is no
## second source of truth (the authority owns `members`; a dedicated server in GID-097
## becomes the canonical ladder host). Returns the top `limit` members sorted by
## `pvp_rating` descending, then by games played (ties broken by token for stability).
func get_leaderboard(limit: int = 10) -> Array:
	var rows: Array = []
	for token in members.keys():
		var rec: Variant = members[token]
		if not (rec is Dictionary):
			continue
		var r: Dictionary = rec
		rows.append({
			"token": str(token),
			"name": str(r.get("display_name", "Player")),
			"rating": int(r.get("pvp_rating", 1000)),
			"games": int(r.get("pvp_games", 0)),
			"wins": int(r.get("pvp_wins", 0)),
			"losses": int(r.get("pvp_losses", 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["rating"] != b["rating"]:
			return a["rating"] > b["rating"]
		if a["games"] != b["games"]:
			return a["games"] > b["games"]
		return str(a["token"]) < str(b["token"]))
	if limit > 0 and rows.size() > limit:
		rows.resize(limit)
	return rows


# ---------------------------------------------------------------------------
# PvE leaderboards — Endless Spire runs + co-op boss clears (GID-102 / TID-379)
# ---------------------------------------------------------------------------
# Distinct from the PvP `get_leaderboard()` ranked-rating board above (TID-370):
# these boards track PvE *achievement* (best Spire floor, best co-op clear value)
# and are never touched by rating math. Kept as plain per-board Arrays (not derived
# from `members`, unlike the ranked board) because a player's best PvE result should
# survive even if their character record's fields don't carry it (mirrors how the
# task asks for a standalone {token, name, value, day} entry shape).

## Valid board names for `record_pve_score` / `get_pve_leaderboard`.
const _PVE_BOARDS: Array[String] = ["spire", "coop_clears"]

## Insert-or-update `token`'s best score on `board`, then re-sort (desc by value,
## ties broken by earliest `day` so an established record isn't bumped by a later
## tie) and cap to PVE_LEADERBOARD_CAP. A no-op if `board` isn't recognized or if
## the token already has a stored score >= the new value (a worse or equal result
## never overwrites a better one — "only your own better score overwrites").
func record_pve_score(board: String, token: String, name: String, value: int, day: int = 0) -> void:
	if token == "" or not _PVE_BOARDS.has(board):
		return
	if not (leaderboards.get(board, null) is Array):
		leaderboards[board] = []
	var rows: Array = leaderboards[board]
	var existing_idx: int = -1
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if row is Dictionary and str((row as Dictionary).get("token", "")) == token:
			existing_idx = i
			break
	if existing_idx >= 0:
		var existing: Dictionary = rows[existing_idx]
		if value <= int(existing.get("value", 0)):
			return  # a worse (or equal) score never overwrites the stored best
		rows.remove_at(existing_idx)
	rows.append({"token": token, "name": name, "value": value, "day": day})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["value"]) != int(b["value"]):
			return int(a["value"]) > int(b["value"])
		if int(a["day"]) != int(b["day"]):
			return int(a["day"]) < int(b["day"])
		return str(a["token"]) < str(b["token"]))
	if rows.size() > PVE_LEADERBOARD_CAP:
		rows.resize(PVE_LEADERBOARD_CAP)
	leaderboards[board] = rows


## Read accessor mirroring `get_leaderboard()`. Returns [] for an unrecognized board.
func get_pve_leaderboard(board: String, limit: int = PVE_LEADERBOARD_CAP) -> Array:
	if not _PVE_BOARDS.has(board):
		return []
	var rows: Array = leaderboards.get(board, [])
	if limit > 0 and rows.size() > limit:
		return rows.slice(0, limit)
	return rows.duplicate(true)


## The full {spire, coop_clears} snapshot sent over the wire (both boards together,
## same "send the whole cached thing" pattern as recv_party_bounties_snapshot).
func get_pve_leaderboards_snapshot() -> Dictionary:
	return {
		"spire": get_pve_leaderboard("spire"),
		"coop_clears": get_pve_leaderboard("coop_clears"),
	}
