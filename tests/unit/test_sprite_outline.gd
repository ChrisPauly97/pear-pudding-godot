## Unit tests for character sprite outlines (GID-133 / TID-513).
extends "res://tests/framework/test_case.gd"

const SO = preload("res://game_logic/SpriteOutline.gd")


func _tex(color: Color) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func test_sprite3d_gets_outline_material_with_its_texture() -> void:
	var sp := Sprite3D.new()
	sp.texture = _tex(Color.RED)
	SO.apply(sp)
	var mat := sp.material_override as ShaderMaterial
	assert_not_null(mat)
	assert_eq(mat.get_shader_parameter("sprite_tex"), sp.texture)
	SO.apply(sp)
	assert_eq(sp.material_override, mat, "idempotent")
	sp.texture = _tex(Color.BLUE)
	SO.refresh(sp)
	assert_eq(mat.get_shader_parameter("sprite_tex"), sp.texture)
	sp.free()

func test_animated_sprite_follows_frames() -> void:
	var sf := SpriteFrames.new()
	var t0: Texture2D = _tex(Color.RED)
	var t1: Texture2D = _tex(Color.GREEN)
	sf.add_frame("default", t0)
	sf.add_frame("default", t1)
	var an := AnimatedSprite3D.new()
	an.sprite_frames = sf
	SO.apply(an)
	var mat := an.material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("sprite_tex"), t0)
	an.frame = 1
	assert_eq(mat.get_shader_parameter("sprite_tex"), t1, "frame_changed re-feeds the texture")
	an.free()
