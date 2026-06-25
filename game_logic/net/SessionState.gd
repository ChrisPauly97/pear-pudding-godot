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
const CURRENT_SESSION_VERSION: int = 1

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
	return s


## Forward-migration scaffold. Entries run in ascending order; each backfills the
## fields a new version added. Mirrors SaveManager._apply_migrations so future
## session-format changes never break existing files.
static func _apply_migrations(data: Dictionary) -> void:
	var ver: int = int(data.get("version", 0))
	# No migrations yet — version 1 is the first shipped format. When the shape
	# changes, add: `if ver < N: <backfill>; data["version"] = N`.
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
	}
