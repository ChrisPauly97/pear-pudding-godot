extends Node3D

var _ring: MeshInstance3D = null

## A flat-shaded material in `color` — the look every procedural world entity
## uses for its fallback geometry (posts, lids, plinths, markers). Unshaded keeps
## them readable at the fixed isometric angle, where a lit material just reads as
## a muddy gradient.
##
## Callers that need more (transparency, emission) set it on the returned
## material; this only covers the two lines all 20-odd of them share.
static func unshaded_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func _make_mi(mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

static func build_highlight_ring(parent: Node3D, radius: float) -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\nvoid fragment() { float p = sin(TIME * 4.0) * 0.5 + 0.5; ALBEDO = vec3(1.0, 0.85, 0.1); EMISSION = vec3(1.0, 0.85, 0.1) * (0.6 + p * 0.8); ALPHA = 0.7 + p * 0.3; }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.05, 0.0)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func set_highlighted(on: bool) -> void:
	if _ring != null:
		_ring.visible = on
