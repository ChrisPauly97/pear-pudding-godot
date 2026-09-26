## Real-time combat onboarding (GID-135 / TID-552): new players unlock the
## controls one fight at a time instead of meeting the timer, casts, skills and
## a hand of cards all at once.
##
##   fight 1 — Strike + auto-attack only, slow clock, no hand
##   fight 2 — + Mend
##   fight 3 — + Kick (the enemy's casts are the lesson)
##   fight 4+ — cards join: the full fight
##
## Players already past it (level > MAX_LEVEL, or who finished the ramp) get
## the full fight straight away. Pure logic; `BattleOnboarding` applies it.
extends RefCounted

const STAGES: Array[Dictionary] = [
	{"skills": ["strike"], "hand": false, "slow": true},
	{"skills": ["strike", "mend"], "hand": false, "slow": false},
	{"skills": ["strike", "mend", "kick"], "hand": false, "slow": false},
]
## Above this level the ramp is skipped (an existing save switching to real time).
const MAX_LEVEL: int = 2

## Stage index for this fight: 0..STAGES.size()-1 while onboarding, -1 = full fight.
static func stage_for(fights_done: int, level: int) -> int:
	if level > MAX_LEVEL or fights_done < 0 or fights_done >= STAGES.size():
		return -1
	return fights_done

## Skill ids allowed at `stage` (every id when -1), in bar order.
static func filter_skills(bar_ids: Array[String], stage: int) -> Array[String]:
	if stage < 0:
		return bar_ids.duplicate()
	var allowed: Array = STAGES[stage]["skills"]
	var out: Array[String] = []
	for id: String in bar_ids:
		if allowed.has(id):
			out.append(id)
	return out

static func shows_hand(stage: int) -> bool:
	return stage < 0 or bool(STAGES[stage]["hand"])

static func slow_clock(stage: int) -> bool:
	return stage >= 0 and bool(STAGES[stage]["slow"])

## Skills new at `stage` (for the "New skill" tip): those not in the stage before.
static func new_skills(stage: int) -> Array[String]:
	var out: Array[String] = []
	if stage <= 0:
		return out
	var prev: Array = STAGES[stage - 1]["skills"]
	for id: Variant in STAGES[stage]["skills"]:
		if not prev.has(id):
			out.append(str(id))
	return out
