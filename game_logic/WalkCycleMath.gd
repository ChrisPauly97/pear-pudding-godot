## Walk-cycle frame picking (GID-152 / TID-645), pure so it can be unit tested.
## A character plays its walk frames while it moves faster than MOVE_SPEED and
## shows its idle frame otherwise; STOP_GRACE keeps a stride from flickering
## back to idle on a single slow frame (chase steps are uneven).
extends RefCounted

const FPS: float = 8.0
## World units / s below which the character counts as standing still.
const MOVE_SPEED: float = 0.3
const STOP_GRACE: float = 0.15


## Advances `state` ({"t": walk clock, "still": seconds below MOVE_SPEED}) by
## `delta` at `speed` and returns the frame to show: -1 = idle, else 0..n-1.
static func step(state: Dictionary, delta: float, speed: float, n_frames: int) -> int:
	if n_frames <= 0:
		return -1
	if speed >= MOVE_SPEED:
		state["still"] = 0.0
	else:
		state["still"] = float(state.get("still", INF)) + delta  # a fresh state starts standing
	if float(state["still"]) > STOP_GRACE:
		state["t"] = 0.0
		return -1
	state["t"] = float(state.get("t", 0.0)) + delta
	return int(floor(float(state["t"]) * FPS)) % n_frames
