## Combat onboarding (GID-135 / TID-552, reworked for GID-141 / TID-588): a new
## player's fight only contains what they have learned from a trainer.
##
##   level 1 — Strike + auto-attack only, no hand (first fight on a slow clock)
##   level 2 — + Mend      (learned from the Combat Trainer)
##   level 3 — + Kick
##   level 4 — + the hand: minion cards (`feat_minions`)
##   level 5 — + spell cards in the hand (`feat_spells`)
##
## Skills need no filtering here: SkillBar only ever holds learned ids. This
## decides the hand, spells, the enemy minion cap, the slow first clock, and the onboarding "stage"
## (how many of the combat unlocks are learned; -1 once all are). Existing saves
## were migrated with every unlock (SaveMigrations v44), so they get the full
## fight. Pure logic; `BattleOnboarding` applies it.
extends RefCounted

const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")

## The ladder entries that change what a fight contains, in unlock order.
const COMBAT_UNLOCKS: Array[String] = ["mend", "kick", UnlockLadder.FEAT_MINIONS, UnlockLadder.FEAT_SPELLS]

## Below this character level fights stay small: a short opening hand, one
## enemy minion and fewer Ally slots, so the first card fights aren't crowded.
const EARLY_LEVEL: int = 10
## Opening hand for a real-time fight (early / later).
const EARLY_OPENING_HAND: int = 2
const OPENING_HAND: int = 3
## Allies you can field below EARLY_LEVEL.
const EARLY_ALLY_CAP: int = 2

## Onboarding stage: how many COMBAT_UNLOCKS are learned, or -1 once all are.
static func stage_for(learned: Array) -> int:
	var n: int = 0
	for id: String in COMBAT_UNLOCKS:
		if learned.has(id):
			n += 1
	return -1 if n == COMBAT_UNLOCKS.size() else n

## The hand (and your unit slots) only appear once minions are learned.
static func shows_hand(learned: Array) -> bool:
	return learned.has(UnlockLadder.FEAT_MINIONS)

## Most minions each enemy fields. Before the player can field Allies, one: they
## still see a summon (and their own locked slots) without facing a full board.
## Still one while the hero is below EARLY_LEVEL.
static func enemy_minion_cap(learned: Array, level: int = EARLY_LEVEL) -> int:
	if not shows_hand(learned) or level < EARLY_LEVEL:
		return 1
	return RealtimeCombat.MAX_ENEMY_MINIONS

## Most Allies the player fields at `level`.
static func ally_cap(level: int) -> int:
	return EARLY_ALLY_CAP if level < EARLY_LEVEL else RealtimeCombat.MAX_ALLIES

## Cards in hand when a real-time fight starts at `level`.
static func opening_hand(level: int) -> int:
	return EARLY_OPENING_HAND if level < EARLY_LEVEL else OPENING_HAND

## Spell cards stay out of the battle deck until spells are learned.
static func allows_spells(learned: Array) -> bool:
	return learned.has(UnlockLadder.FEAT_SPELLS)

## The very first fight runs on a slow clock.
static func slow_clock(fights_done: int, learned: Array) -> bool:
	return fights_done <= 0 and stage_for(learned) == 0

## A hand-less fight only works in real time, so battles are real-time until
## minions are learned; after that the Battle Mode setting decides.
static func battle_mode(setting: String, learned: Array) -> String:
	if not shows_hand(learned) and not setting.begins_with("realtime"):
		return "realtime"
	return setting
