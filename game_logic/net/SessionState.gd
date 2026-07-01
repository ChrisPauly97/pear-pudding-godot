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
const CURRENT_SESSION_VERSION: int = 5

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
	return s


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
