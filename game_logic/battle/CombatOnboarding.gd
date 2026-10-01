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
## decides the hand, spells, enemy summons, the slow first clock, and the onboarding "stage"
## (how many of the combat unlocks are learned; -1 once all are). Existing saves
## were migrated with every unlock (SaveMigrations v44), so they get the full
## fight. Pure logic; `BattleOnboarding` applies it.
extends RefCounted

const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

## The ladder entries that change what a fight contains, in unlock order.
const COMBAT_UNLOCKS: Array[String] = ["mend", "kick", UnlockLadder.FEAT_MINIONS, UnlockLadder.FEAT_SPELLS]

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

## Enemies only summon minions once the player can field their own: a level-1
## hero with Strike alone can't keep up with a growing enemy board.
static func enemy_summons(learned: Array) -> bool:
	return shows_hand(learned)

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
