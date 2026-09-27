## Shared builder for the player-hero walk AnimatedSprite3D.
##
## Used by RemotePlayer so co-op avatars are drawn by the same layered
## PaperDoll as the local player (GID-137). Returns a fully-configured
## AnimatedSprite3D ready to add_child() onto any node.
##
## Callers: preload("res://scenes/world/entities/AvatarSprite.gd")
extends RefCounted

const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")

const PIXEL_SIZE: float = 0.05


## Build and return a configured AnimatedSprite3D wearing `gear` (slot → item id).
## The sprite is not yet added to the scene tree — caller must add_child() it.
static func build(gear: Dictionary = {}) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = _PaperDoll.build_frames(gear)
	sprite.pixel_size = PIXEL_SIZE
	_SpriteRegistry.apply_billboard_flags(sprite)
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Position so bottom edge sits at y=0 (feet on the ground).
	var frame_h: float = _PaperDoll.FRAME_H * PIXEL_SIZE
	sprite.position = Vector3(0.0, frame_h * 0.5, 0.0)

	return sprite
