## Timing and slop rules for a single long press, without any input wiring.
## Owners feed it the press / move / release they care about and call `tick()`
## each frame; it reports once when the hold passes the threshold. Shared by
## `LongPressDetector` (hold on a Control) and the map overlays (hold on the map
## to drop a waypoint).
extends RefCounted

const THRESHOLD_SEC: float = 0.5
## A press that moves further than this is a drag, not a hold.
const SLOP_PX: float = 12.0

## Where the current (or last) press started.
var start_pos: Vector2 = Vector2.ZERO
var _holding: bool = false
var _elapsed: float = 0.0

func is_holding() -> bool:
	return _holding

func press(pos: Vector2) -> void:
	start_pos = pos
	_elapsed = 0.0
	_holding = true

func cancel() -> void:
	_holding = false

## True once `pos` is further than SLOP_PX from where the press started.
func strayed(pos: Vector2) -> bool:
	return pos.distance_to(start_pos) > SLOP_PX

## Cancels the hold once the pointer strays past SLOP_PX from where it started.
func move(pos: Vector2) -> void:
	if _holding and strayed(pos):
		_holding = false

## Advances the hold; true exactly once, on the frame it reaches THRESHOLD_SEC.
func tick(delta: float) -> bool:
	if not _holding:
		return false
	_elapsed += delta
	if _elapsed < THRESHOLD_SEC:
		return false
	_holding = false
	return true
