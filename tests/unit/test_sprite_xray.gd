## Occluded-silhouette pass: the player sprite shows a rim through scenery
## (sprite_xray next_pass) instead of the terrain shader cutting walls away.
extends "res://tests/framework/test_case.gd"

const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")


func test_xray_pass_is_chained_and_fed() -> void:
	var s := Sprite3D.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	s.texture = ImageTexture.create_from_image(img)
	_SpriteOutline.apply(s)
	_SpriteOutline.apply_xray(s)
	var mat := s.material_override as ShaderMaterial
	var xray := mat.next_pass as ShaderMaterial
	assert_true(xray != null, "x-ray chained as next_pass")
	assert_eq(xray.get_shader_parameter("sprite_tex"), s.texture, "x-ray pass gets the sprite texture")
	var tex2 := ImageTexture.create_from_image(img)
	s.texture = tex2
	_SpriteOutline.refresh(s)
	assert_eq(xray.get_shader_parameter("sprite_tex"), tex2, "refresh re-feeds the x-ray pass")
	_SpriteOutline.apply_xray(s)
	assert_eq(mat.next_pass, xray, "apply_xray is idempotent")
	s.free()


func test_terrain_no_longer_cuts_walls() -> void:
	var src: String = FileAccess.get_file_as_string("res://assets/shaders/terrain.gdshader")
	assert_false(src.contains("occlusion_focus"), "terrain has no wall cutaway")
