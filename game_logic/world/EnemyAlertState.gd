extends RefCounted

## Pure detection/pursuit state machine for tracking enemies (GID-113).
## Separated from EnemyNPC (a scene node with Area3D/CharacterBody3D/scene
## tree dependencies) so the transition rules are unit-testable in isolation —
## mirrors the TerrainMath/Pathfinder/BattlefieldRules pattern.

enum State { IDLE, ALERTED, CHASING }

## IDLE -> ALERTED once distance drops to/within awareness_range. No-op
## otherwise (including already ALERTED/CHASING).
static func check_awareness(state: int, distance: float, awareness_range: float) -> int:
	if state == State.IDLE and distance <= awareness_range:
		return State.ALERTED
	return state

## Ticks the ALERTED reaction beat toward CHASING. No-op outside ALERTED.
static func tick_reaction(state: int, alert_timer: float, delta: float, reaction_time: float) -> Dictionary:
	if state != State.ALERTED:
		return {"state": state, "alert_timer": alert_timer}
	var t: float = alert_timer + delta
	if t >= reaction_time:
		return {"state": State.CHASING, "alert_timer": 0.0}
	return {"state": state, "alert_timer": t}

## Ticks the give-up timer while ALERTED/CHASING; reverts to IDLE after a
## sustained (not single-frame) distance beyond giveup_range — resets to 0
## the instant distance drops back under, so a brief boundary flicker never
## counts. No-op at IDLE.
static func tick_giveup(state: int, giveup_timer: float, delta: float, distance: float,
		giveup_range: float, hold_time: float) -> Dictionary:
	if state == State.IDLE:
		return {"state": state, "giveup_timer": giveup_timer, "gave_up": false}
	if distance > giveup_range:
		var t: float = giveup_timer + delta
		if t >= hold_time:
			return {"state": State.IDLE, "giveup_timer": 0.0, "gave_up": true}
		return {"state": state, "giveup_timer": t, "gave_up": false}
	return {"state": state, "giveup_timer": 0.0, "gave_up": false}

## Ambush classification at contact time (EnemyNPC.engage()). IDLE covers
## both wanderers (never alerted at all) and tracking enemies caught before
## they noticed the player; CHASING means the enemy caught the player
## mid-pursuit. ALERTED (mid-reaction) is neither — a neutral fight. The two
## flags are mutually exclusive by construction (different enum values).
static func classify_ambush(state: int) -> Dictionary:
	return {"player_ambush": state == State.IDLE, "enemy_ambush": state == State.CHASING}
