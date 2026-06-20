## Mana Well entity for GID-068 ley lines.
## Spawned at ley line intersections on TILE_GRASS tiles; one-time collectible.
extends Node3D

static var _well_mat: StandardMaterial3D
static var _well_mesh: CylinderMesh
static var _crystal_mat: StandardMaterial3D
static var _crystal_mesh: PrismMesh

static func _ensure_shared_resources() -> void:
	if _well_mesh != null:
		return
	_well_mesh = CylinderMesh.new()
	_well_mesh.top_radius = 0.35
	_well_mesh.bottom_radius = 0.55
	_well_mesh.height = 0.25
	_well_mat = StandardMaterial3D.new()
	_well_mat.albedo_color = Color(0.20, 0.22, 0.32)
	_well_mat.emission_enabled = true
	_well_mat.emission = Color(0.05, 0.75, 0.85)
	_well_mat.emission_energy_multiplier = 1.2
	_well_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_crystal_mesh = PrismMesh.new()
	_crystal_mesh.size = Vector3(0.18, 0.40, 0.18)
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.2, 0.9, 1.0, 0.7)
	_crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.05, 0.85, 0.95)
	_crystal_mat.emission_energy_multiplier = 1.8
	_crystal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _ready() -> void:
	_ensure_shared_resources()
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = _well_mesh
	base_inst.material_override = _well_mat
	base_inst.position = Vector3(0.0, 0.125, 0.0)
	add_child(base_inst)
	var crystal_inst := MeshInstance3D.new()
	crystal_inst.mesh = _crystal_mesh
	crystal_inst.material_override = _crystal_mat
	crystal_inst.position = Vector3(0.0, 0.45, 0.0)
	add_child(crystal_inst)

func init_from_data(data: Dictionary) -> void:
	var wid: String = str(data.get("id", ""))
	set_meta("well_id", wid)
