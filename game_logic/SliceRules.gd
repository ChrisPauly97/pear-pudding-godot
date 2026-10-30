## SliceRules — what the vertical slice keeps (GID-188 / TID-794).
##
## The slice is a 30–45 minute cut of the full game that proves the core loop:
## explore → real-time card fight → soulbind → the deck changes the next fight
## and opens the world (Dig). Systems outside it are hidden, never deleted:
## turn the project setting `pear_pudding/slice_mode` off and everything returns.
## A player can also opt into the full game from Settings ("Full Game"); that
## choice is per device (FULL_GAME_PATH), so the menu reads it before any save loads.
##
## Single source of truth for the cut. Gate a system with `active()` plus one of
## the tables below; never add a separate slice check with its own list.
## Pure static data, no autoloads.
extends RefCounted

const SETTING: String = "pear_pudding/slice_mode"
const FULL_GAME_PATH: String = "user://full_game.cfg"
const _CFG_SECTION: String = "game"
const _CFG_KEY: String = "full_game"

## Highest player level the slice reaches: XP stops at it (TID-795). Real pacing,
## not compressed (user, 2026-10-30): about 4.5 h to level 10 on XpCurve.
const LEVEL_CAP: int = 10

## The slice boss: the Barrow King (StarterZone.BARROW_KING, level 10). Outside the
## slice he waits for "The Sealed Crypt", which needs Ghost Phase; in the slice he
## wakes once the Dig quest is turned in.
const BOSS_ENEMY_TYPE: String = "barrow_king"
const BOSS_QUEST: String = "old_bones"
## Story flag set when the player closes the completion screen.
const COMPLETE_FLAG: String = "slice_complete"
const COMPLETE_TITLE: String = "Demo Complete"
const COMPLETE_PAGES: Array[String] = [
	("The Barrow King falls, and the old graveyard is quiet at last. Madrian sleeps safe tonight — "
		+ "for now."),
	("Every enemy you beat could become a card, and every card changes the next fight. That is the heart "
		+ "of Pear Pudding."),
	("Thank you for playing the demo. The road south, Ghost Phase, the rifts and the rest of Saimtar's "
		+ "tale are waiting: turn on Settings > Full Game to keep going with this character."),
]

## UnlockLadder rows a slice player can learn. Everything else stays off the
## trainers' lists. Strike is free from the start and is not a ladder row.
const LADDER: Array[String] = [
	"mend",
	"kick",
	"feat_minions",
	"feat_spells",
	"feat_companion",
	"feat_dig",
]

## Main-menu entries the slice shows.
const MENU: Array[String] = ["continue", "new_game", "settings", "diagnostics", "quit"]

## The only battle mode the slice offers (Settings > Battle Mode is ignored).
const BATTLE_MODE: String = "realtime"

## Test override: -1 follows the project setting, 0 forces off, 1 forces on.
static var override: int = -1
## Cached FULL_GAME_PATH value: -1 unread, 0 slice, 1 full game.
static var _full_game: int = -1

static func active() -> bool:
	if override >= 0:
		return override == 1
	return bool(ProjectSettings.get_setting(SETTING, false)) and not full_game_enabled()

## True when the player turned "Full Game" on in Settings.
static func full_game_enabled(path: String = FULL_GAME_PATH) -> bool:
	if _full_game < 0 or path != FULL_GAME_PATH:
		var cfg := ConfigFile.new()
		var on: bool = cfg.load(path) == OK and bool(cfg.get_value(_CFG_SECTION, _CFG_KEY, false))
		if path != FULL_GAME_PATH:
			return on
		_full_game = 1 if on else 0
	return _full_game == 1

## Writes the Settings choice; takes effect immediately.
static func set_full_game(on: bool, path: String = FULL_GAME_PATH) -> Error:
	if path == FULL_GAME_PATH:
		_full_game = 1 if on else 0
	if not on:
		return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK
	var cfg := ConfigFile.new()
	cfg.set_value(_CFG_SECTION, _CFG_KEY, true)
	return cfg.save(path)

## True when ladder row `id` is in play (always, outside the slice).
static func allows_ladder(id: String) -> bool:
	return not active() or LADDER.has(id)

## The quest that wakes the Barrow King (`outside` = the full game's).
static func boss_quest(outside: String) -> String:
	return BOSS_QUEST if active() else outside

## `xp` clamped to the slice's level cap (unchanged outside the slice).
static func capped_xp(xp: int, xp_at_cap: int) -> int:
	return mini(xp, xp_at_cap) if active() else xp

## True when side quest `q` belongs to the slice: offered at or below the level cap,
## and every row it asks the player to learn is on the slice ladder (always, outside).
static func allows_quest(q: Dictionary) -> bool:
	if not active():
		return true
	if int(q.get("min_level", 1)) > LEVEL_CAP:
		return false
	var objectives: Array = q.get("objectives", [])
	for o: Variant in objectives:
		var od: Dictionary = o
		var kind: String = str(od.get("type", ""))
		if kind == "rift_tier" or (kind == "learn" and not LADDER.has(str(od.get("target", "")))):
			return false
	return true

## True when main-menu entry `id` is shown (always, outside the slice).
static func allows_menu(id: String) -> bool:
	return not active() or MENU.has(id)

## The battle mode to use for `setting` (the player's choice).
static func battle_mode(setting: String) -> String:
	return BATTLE_MODE if active() else setting
