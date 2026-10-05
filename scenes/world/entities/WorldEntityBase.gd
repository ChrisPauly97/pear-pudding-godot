extends Node3D

## One pulsing ring material for every entity, and one cylinder per radius:
## each ring used to compile its own Shader on spawn (GID-162).
static var _ring_mat: ShaderMaterial = null
static var _ring_meshes: Dictionary = {}  # radius → CylinderMesh

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

## `unshaded_material` plus an emission glow — the bloom-feeding look shared by
## crystals, flames, loot and beacons. Emission is what glows here: all world
## geometry is unshaded, so lights have no effect on it.
static func glow_material(color: Color, emission: Color, energy: float = 1.0) -> StandardMaterial3D:
	var mat := unshaded_material(color)
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

static func _make_mi(mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

static func build_highlight_ring(parent: Node3D, radius: float) -> MeshInstance3D:
	if _ring_mat == null:
		var sh := Shader.new()
		sh.code = ("shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\nvoid fragment() { "
				+ "float p = sin(TIME * 4.0) * 0.5 + 0.5; ALBEDO = vec3(1.0, 0.85, 0.1); EMISSION = vec3(1.0, 0.85, "
				+ "0.1) * (0.6 + p * 0.8); ALPHA = 0.7 + p * 0.3; }")
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = sh
	var mesh: CylinderMesh = _ring_meshes.get(radius)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.04
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 16
		_ring_meshes[radius] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ring_mat
	mi.position = Vector3(0.0, 0.05, 0.0)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func set_highlighted(on: bool) -> void:
	if _ring != null:
		_ring.visible = on
