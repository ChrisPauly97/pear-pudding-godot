extends RefCounted
## Character sprite outlines (GID-133 / TID-513). `apply(sprite)` swaps a
## world character sprite to `sprite_outline.gdshader` and keeps its texture
## fed: Sprite3D once (and again via `refresh()` if the texture changes),
## AnimatedSprite3D on every `frame_changed` / `animation_changed`.
## One ShaderMaterial per sprite (the texture differs per sprite/frame).

const _SHADER = preload("res://assets/shaders/sprite_outline.gdshader")
const META_OUTLINED := "outlined"
const OUTLINE_COLOR := Color(0.07, 0.05, 0.09)
## Interact glow (GID-134 / TID-526): the outline warms to this when the hero
## can use something nearby.
const GLOW_COLOR := Color(1.0, 0.82, 0.35)


static func apply(sprite: SpriteBase3D) -> void:
	if sprite == null or sprite.has_meta(META_OUTLINED):
		return
	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	sprite.material_override = mat
	sprite.set_meta(META_OUTLINED, true)
	var anim := sprite as AnimatedSprite3D
	if anim != null:
		anim.frame_changed.connect(refresh.bind(sprite))
		anim.animation_changed.connect(refresh.bind(sprite))
	refresh(sprite)


## Blends an outlined sprite's edge from the dark outline (0) to the warm
## interact glow (1).
static func set_glow(sprite: SpriteBase3D, amount: float) -> void:
	var mat := sprite.material_override as ShaderMaterial if sprite != null else null
	if mat == null:
		return
	mat.set_shader_parameter("outline_color", OUTLINE_COLOR.lerp(GLOW_COLOR, clampf(amount, 0.0, 1.0)))


## Current texture of a sprite (the playing frame for AnimatedSprite3D).
static func current_texture(sprite: SpriteBase3D) -> Texture2D:
	var anim := sprite as AnimatedSprite3D
	if anim != null:
		if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
			return null
		return anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	var s := sprite as Sprite3D
	return s.texture if s != null else null


## Re-feeds the texture (call after changing a Sprite3D's texture).
static func refresh(sprite: SpriteBase3D) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("sprite_tex", current_texture(sprite))
