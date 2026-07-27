## Shared builder for the player-hero walk AnimatedSprite3D.
##
## Used by Player._build_sprite() and RemotePlayer to avoid duplicating
## the sprite construction. Returns a fully-configured AnimatedSprite3D
## ready to add_child() onto any node.
##
## Callers: preload("res://scenes/world/entities/AvatarSprite.gd")
extends RefCounted

# 0x72 DungeonTilesetII "elf_m" hero frames (CC0) — same art as Player.gd
# so remote co-op avatars match the local player.
const _IdleTex:  Texture2D = preload("res://assets/textures/characters/player_hero.png")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _WalkTex1: Texture2D = preload("res://assets/textures/characters/player_hero_walk_1.png")
const _WalkTex2: Texture2D = preload("res://assets/textures/characters/player_hero_walk_2.png")
const _WalkTex3: Texture2D = preload("res://assets/textures/characters/player_hero_walk_3.png")
const _WalkTex4: Texture2D = preload("res://assets/textures/characters/player_hero_walk_4.png")

const ANIM_FPS: float = 6.0
const PIXEL_SIZE: float = 0.05


## Build and return a configured AnimatedSprite3D.
## The sprite is not yet added to the scene tree — caller must add_child() it.
static func build() -> AnimatedSprite3D:
	var walk: Array[Texture2D] = [_WalkTex1, _WalkTex2, _WalkTex3, _WalkTex4]
	var sf: SpriteFrames = _SpriteRegistry.make_idle_walk_frames(_IdleTex, walk, ANIM_FPS)


	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = sf
	sprite.pixel_size = PIXEL_SIZE
	_SpriteRegistry.apply_billboard_flags(sprite)
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Position so bottom edge sits at y=0 (feet on the ground).
	var frame_h: float = _WalkTex1.get_height() * PIXEL_SIZE
	sprite.position = Vector3(0.0, frame_h * 0.5, 0.0)

	return sprite
