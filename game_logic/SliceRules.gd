## SliceRules — what the vertical slice keeps (GID-188 / TID-794).
##
## The slice is a 30–45 minute cut of the full game that proves the core loop:
## explore → real-time card fight → soulbind → the deck changes the next fight
## and opens the world (Dig). Systems outside it are hidden, never deleted:
## turn the project setting `pear_pudding/slice_mode` off and everything returns.
##
## Single source of truth for the cut. Gate a system with `active()` plus one of
## the tables below; never add a separate slice check with its own list.
## Pure static data, no autoloads.
extends RefCounted

const SETTING: String = "pear_pudding/slice_mode"

## Highest player level the slice reaches (enforced by TID-795).
const LEVEL_CAP: int = 10

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

static func active() -> bool:
	if override >= 0:
		return override == 1
	return bool(ProjectSettings.get_setting(SETTING, false))

## True when ladder row `id` is in play (always, outside the slice).
static func allows_ladder(id: String) -> bool:
	return not active() or LADDER.has(id)

## True when main-menu entry `id` is shown (always, outside the slice).
static func allows_menu(id: String) -> bool:
	return not active() or MENU.has(id)

## The battle mode to use for `setting` (the player's choice).
static func battle_mode(setting: String) -> String:
	return BATTLE_MODE if active() else setting
