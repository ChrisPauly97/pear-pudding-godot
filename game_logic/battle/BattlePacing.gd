## Single source of truth for fixed battle pacing delays (GID-135 / TID-527).
##
## Every scripted wait in a battle — AI "thinking", gaps between AI actions,
## the end-of-turn tail — is a named constant here so the WoW-fluid work in
## GID-135 can tune and budget it in one place. `test_battle_pacing` fails if
## BattleScene grows a literal `_battle_delay(<number>)` again, and asserts the
## per-turn dead time stays inside the budgets below.
##
## All values are seconds at "normal" battle speed; BattleScene multiplies them
## by `_speed_scale` (FAST_SPEED_SCALE when the "fast" setting is on).
extends RefCounted

## Scale applied to every delay/animation when Settings > Battle Speed = fast.
const FAST_SPEED_SCALE: float = 0.45

## Intent banner shown before the AI's first action.
const AI_THINK: float = 1.5
## Pause between consecutive AI actions (after hit + death animations).
const AI_ACTION_GAP: float = 0.6
## Pause after the AI's last action before control returns to the player.
const AI_TURN_TAIL: float = 0.5
## Minion death shrink/fade (BattleFx.animate_death).
const DEATH_ANIM: float = 0.25

## World <-> battle wipe, each direction (TransitionManager.FADE_DURATION covers,
## then uncovers). Mirrored here for the budget; test asserts they agree.
const TRANSITION_HALF: float = 0.3

## Budgets (normal speed). Baseline measured by TID-527; later GID-135 tasks
## lower these as they remove dead time — never raise them.
const BUDGET_AI_TURN_3_ACTIONS: float = 3.8
const BUDGET_ENGAGE_TO_INPUT: float = 0.6

## Pure: fixed wait the player sits through for one AI turn of `action_count`
## actions, excluding hit/death animations (those overlap the gap).
static func ai_turn_dead_time(action_count: int, speed_scale: float = 1.0) -> float:
	var gaps: int = maxi(0, action_count)
	return (AI_THINK + AI_ACTION_GAP * gaps + AI_TURN_TAIL) * speed_scale

## Pure: world → first player input, excluding the optional gambit picker
## (which waits on the player and is skipped by the "auto_skip_gambits" setting).
## The wipe runs in real time, so battle speed doesn't apply.
static func engage_to_input() -> float:
	return TRANSITION_HALF * 2.0
