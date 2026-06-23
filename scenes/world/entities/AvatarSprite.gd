## Shared builder for the wizard walk AnimatedSprite3D.
##
## Used by Player._build_sprite() and RemotePlayer to avoid duplicating
## the sprite construction. Returns a fully-configured AnimatedSprite3D
## ready to add_child() onto any node.
##
## Callers: preload("res://scenes/world/entities/AvatarSprite.gd")
extends RefCounted

const _WalkTex1: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_1_pixel.png")
const _WalkTex2: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_2_pixel.png")
const _WalkTex3: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_3_pixel.png")
const _WalkTex4: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_4_pixel.png")

const ANIM_FPS: float = 6.0
const PIXEL_SIZE: float = 0.05


## Build and return a configured AnimatedSprite3D.
## The sprite is not yet added to the scene tree — caller must add_child() it.
static func build() -> AnimatedSprite3D:
	var sf := SpriteFrames.new()

	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", ANIM_FPS)
	sf.add_frame("idle", _WalkTex1)

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", ANIM_FPS)
	sf.add_frame("walk", _WalkTex1)
	sf.add_frame("walk", _WalkTex2)
	sf.add_frame("walk", _WalkTex3)
	sf.add_frame("walk", _WalkTex4)

	if sf.has_animation("default"):
		sf.remove_animation("default")

	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = sf
	sprite.pixel_size = PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Position so bottom edge sits at y=0 (feet on the ground).
	var frame_h: float = _WalkTex1.get_height() * PIXEL_SIZE
	sprite.position = Vector3(0.0, frame_h * 0.5, 0.0)

	return sprite
