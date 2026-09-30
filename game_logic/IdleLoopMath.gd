## NPC idle-life schedule (GID-152 / TID-650), pure for unit tests: stand on
## the idle frame for a few seconds, blink, sometimes glance aside for a moment.
## Each NPC rolls its own gaps, so a crowd never blinks in unison.
extends RefCounted

const IDLE := 0
const BLINK := 1
const GLANCE := 2

const HOLD_MIN: float = 2.5
const HOLD_MAX: float = 5.5
const BLINK_TIME: float = 0.14
const GLANCE_TIME: float = 0.9
const GLANCE_CHANCE: float = 0.3


## Next (pose, seconds) after `pose`, using `roll` / `roll2` in 0..1.
static func next(pose: int, roll: float, roll2: float) -> Array:
	if pose != IDLE:
		return [IDLE, lerpf(HOLD_MIN, HOLD_MAX, roll)]
	if roll2 < GLANCE_CHANCE:
		return [GLANCE, GLANCE_TIME]
	return [BLINK, BLINK_TIME]
