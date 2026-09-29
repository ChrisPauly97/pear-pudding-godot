## Picks the hero's PaperDoll animation each physics frame (GID-137).
##
## Pure so it can be unit-tested; `Player._physics_process` feeds it state.
## Priority: mounted riders sit idle, then airborne (jump while rising, fall
## once airborne past a short grace so slope hops don't flicker), then a
## one-shot (swing / land) still playing, then walk / idle.
extends RefCounted

const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")

## Seconds off the floor before descending counts as a fall.
const FALL_GRACE: float = 0.1
const ONE_SHOTS: Array[StringName] = [&"swing", &"land"]
## Side-view animation → its back-view twin (PaperDoll.BACK_ANIMS, TID-618).
const BACK_OF: Dictionary = {&"idle": &"idle_back", &"walk": &"walk_back"}


static func pick(mounted: bool, on_floor: bool, vel_y: float, air_time: float, moving: bool,
		current: StringName, playing: bool) -> StringName:
	if mounted:
		return &"idle"
	if not on_floor:
		if vel_y > 0.0:
			return &"jump"
		if air_time > FALL_GRACE:
			return &"fall"
	if ONE_SHOTS.has(current) and playing:
		return current
	return &"walk" if moving else &"idle"


## `anim` as seen from behind when `back` (only idle and walk have back views).
static func facing(anim: StringName, back: bool) -> StringName:
	if back and BACK_OF.has(anim):
		var b: StringName = BACK_OF[anim]
		return b
	return anim


static func is_walk(anim: StringName) -> bool:
	return anim == &"walk" or anim == &"walk_back"


## Whether a ground direction heads up-screen (away from the camera, whose
## forward is (−1, 0, −1)) more than sideways. A near-zero `dir` keeps `was_back`.
static func faces_away(dir: Vector3, was_back: bool) -> bool:
	var up: float = -(dir.x + dir.z)
	var side: float = dir.x - dir.z
	if absf(up) < 0.1 and absf(side) < 0.1:
		return was_back
	return up > absf(side) * 0.5


## Swaps `sprite` into new frames (a gear change), keeping its animation and
## re-feeding the outline shader, which only samples on frame changes.
static func wear(sprite: AnimatedSprite3D, frames: SpriteFrames) -> void:
	var anim: StringName = sprite.animation
	sprite.sprite_frames = frames
	sprite.play(anim)
	_SpriteOutline.refresh(sprite)
