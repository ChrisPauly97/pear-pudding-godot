# Static utility — creates a ShaderMaterial for the pixel-art card frame.
# Preload this in any scene that renders cards; do NOT rely on class_name scanning.
#
# Usage:
#   const CardFrameMaterial = preload("res://game_logic/CardFrameMaterial.gd")
#   var mat := CardFrameMaterial.make(card_color, illustration_texture)
#   color_rect.material = mat

const _Shader: Shader = preload("res://assets/shaders/card_frame.gdshader")

static func make(base_color: Color, illustration: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _Shader
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("selected", false)
	if illustration:
		mat.set_shader_parameter("illustration", illustration)
		mat.set_shader_parameter("has_illustration", true)
	else:
		mat.set_shader_parameter("has_illustration", false)
	return mat
