extends RefCounted
## Full-screen vignette overlay for the world view (moved out of WorldScene, GID-130).

const LAYER: int = 127


## Builds the vignette CanvasLayer; the caller parents it.
static func make() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = LAYER
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vshader := Shader.new()
	vshader.code = ("shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = length(uv * "
			+ "vec2(1.0, 1.2));\n\tfloat vig = smoothstep(0.35, 0.75, d) * 0.45;\n\tCOLOR = vec4(0.0, 0.0, 0.0, "
			+ "vig);\n}")
	var vmat := ShaderMaterial.new()
	vmat.shader = vshader
	cr.material = vmat
	cl.add_child(cr)
	return cl
