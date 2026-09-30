## Pixel-art campfire (GID-152 / TID-649): a looping billboard of burning
## flames (dungeon rest sites) or smouldering embers under a smoke wisp (the
## story's cold wilderness camp). Frames come from LandmarkFrames.campfire().
extends RefCounted

const _LandmarkFrames = preload("res://game_logic/LandmarkFrames.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")
const _SpriteLoop = preload("res://scenes/world/entities/SpriteLoop.gd")

const LIT_FPS: float = 9.0
const SMOULDER_FPS: float = 3.0


## Adds the campfire billboard (and its loop) under `parent`; returns the sprite.
static func build(parent: Node3D, lit: bool) -> Sprite3D:
	var frames: Array[Texture2D] = _LandmarkFrames.campfire(lit)
	var sprite := Sprite3D.new()
	sprite.name = "Campfire"
	_SpriteRegistry.setup_sprite(sprite, frames[0])  # drawn at its height in px
	_SpriteRegistry.apply_billboard_flags(sprite)
	parent.add_child(sprite)
	_SpriteOutline.apply(sprite)
	parent.add_child(_SpriteLoop.with_frames(sprite, frames, LIT_FPS if lit else SMOULDER_FPS))
	return sprite
