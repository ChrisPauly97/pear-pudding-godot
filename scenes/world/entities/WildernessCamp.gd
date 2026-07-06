extends Node3D

## First-night wilderness camp on the road out of Madrian (GID-108 / TID-402).
## Interacting triggers the rabbit-hunt scripted battle (see docs/human/story.md
## "Chapter 1: Into the Wild World" beat 2), then the next-morning fire-making
## dialogue on a second interaction. Frees itself once both beats are resolved.

# Shared resources — created once across all instances. All geometry in this
# game is unshaded (see scenes/world/entities/WorldItem.gd), so the "glow" is
# an emissive unshaded material rather than a real light.
static var _log_mat: StandardMaterial3D
static var _log_mesh: CylinderMesh
static var _flame_mat: StandardMaterial3D
static var _flame_mesh: CylinderMesh

static func _ensure_shared_resources() -> void:
	if _log_mat != null:
		return
	_log_mat = StandardMaterial3D.new()
	_log_mat.albedo_color = Color(0.35, 0.22, 0.12)
	_log_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_log_mesh = CylinderMesh.new()
	_log_mesh.top_radius = 0.06
	_log_mesh.bottom_radius = 0.06
	_log_mesh.height = 0.5

	_flame_mat = StandardMaterial3D.new()
	_flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(1.0, 0.45, 0.05)
	_flame_mesh = CylinderMesh.new()
	_flame_mesh.top_radius = 0.02
	_flame_mesh.bottom_radius = 0.18
	_flame_mesh.height = 0.4

func _ready() -> void:
	_ensure_shared_resources()

	var log_a := MeshInstance3D.new()
	log_a.mesh = _log_mesh
	log_a.material_override = _log_mat
	log_a.rotation_degrees = Vector3(0.0, 45.0, 90.0)
	log_a.position = Vector3(0.0, 0.08, 0.0)
	add_child(log_a)

	var log_b := MeshInstance3D.new()
	log_b.mesh = _log_mesh
	log_b.material_override = _log_mat
	log_b.rotation_degrees = Vector3(0.0, -45.0, 90.0)
	log_b.position = Vector3(0.0, 0.08, 0.0)
	add_child(log_b)

	var flame := MeshInstance3D.new()
	flame.mesh = _flame_mesh
	flame.material_override = _flame_mat
	flame.position = Vector3(0.0, 0.25, 0.0)
	add_child(flame)

## Three-stage camp interaction. Stage 1 starts the rabbit-hunt tutorial battle;
## stage 2 (next visit, after victory) delivers the fire-making lesson and frees
## this node — its narrative purpose is served. Stage 3 is a defensive fallback
## for a stale node from an earlier session where both flags are already set.
func interact() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_camp_night"):
		GameBus.hud_message_requested.emit(
			"Rain patters on the leaves overhead. Saimtar creeps toward a rustle in the brush — a rabbit. No fire tonight; it'll have to be eaten raw.")
		GameBus.scripted_battle_requested.emit("rabbit_hunt")
		return
	if not sm.get_story_flag("chapter1_learned_fire"):
		GameBus.hud_message_requested.emit(
			"Maiteln kneels by the cold ashes: \"Flint here, tinder there — patience, lad.\" The first flame catches.")
		sm.set_story_flag("chapter1_learned_fire")
		queue_free()
		return
	GameBus.hud_message_requested.emit("The campfire's long since cold — the lesson is learned.")
