## Blight Heart entity (GID-066).
## Spawned in ~33% of super-regions; engaging it starts a boss battle.
## Defeating it marks the heart cleansed and awards Redemption Points.
extends Node3D

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

static var _heart_mat: StandardMaterial3D
static var _heart_mesh: SphereMesh
static var _glow_mat: StandardMaterial3D
static var _glow_mesh: SphereMesh

static func _ensure_shared_resources() -> void:
	if _heart_mesh != null:
		return
	_heart_mesh = SphereMesh.new()
	_heart_mesh.radius = 0.55
	_heart_mesh.height = 1.1

	_heart_mat = StandardMaterial3D.new()
	_heart_mat.albedo_color = Color(0.20, 0.0, 0.28)
	_heart_mat.emission_enabled = true
	_heart_mat.emission = Color(0.55, 0.0, 0.70)
	_heart_mat.emission_energy_multiplier = 1.8
	_heart_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_glow_mesh = SphereMesh.new()
	_glow_mesh.radius = 0.80
	_glow_mesh.height = 1.6

	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.50, 0.0, 0.65, 0.18)
	_glow_mat.flags_transparent = true
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

var _heart_id: String = ""
var _pulse_tween: Tween = null

func _ready() -> void:
	_ensure_shared_resources()
	var core := MeshInstance3D.new()
	core.mesh = _heart_mesh
	core.material_override = _heart_mat
	core.position = Vector3(0.0, 1.0, 0.0)
	add_child(core)

	var aura := MeshInstance3D.new()
	aura.mesh = _glow_mesh
	aura.material_override = _glow_mat
	aura.position = Vector3(0.0, 1.0, 0.0)
	add_child(aura)

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(core, "scale", Vector3(1.12, 1.12, 1.12), 0.9)
	_pulse_tween.tween_property(core, "scale", Vector3(1.0, 1.0, 1.0), 0.9)

func init_from_data(data: Dictionary) -> void:
	_heart_id = str(data.get("id", ""))

func engage() -> void:
	var deck: Array[String] = EnemyRegistry.get_deck("blight_heart")
	var edata: Dictionary = {
		"id": _heart_id,
		"enemy_type": "blight_heart",
		"enemy_deck": deck,
		"is_boss": true,
		"boss_hp": EnemyRegistry.get_boss_hp("blight_heart"),
		"blight_heart_id": _heart_id,
	}
	GameBus.enemy_engaged.emit(edata)
	queue_free()
