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


## Swaps `sprite` into new frames (a gear change), keeping its animation and
## re-feeding the outline shader, which only samples on frame changes.
static func wear(sprite: AnimatedSprite3D, frames: SpriteFrames) -> void:
	var anim: StringName = sprite.animation
	sprite.sprite_frames = frames
	sprite.play(anim)
	_SpriteOutline.refresh(sprite)
