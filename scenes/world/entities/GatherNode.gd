## Gathering node entity (GID-182 / TID-760): a herb patch, ore vein or fishing spot.
## Placeholder look (a coloured mound). A harvest hides it until its respawn time;
## the respawn timer lives on the node and is session-only (not saved).
extends Node3D

const GatherDefs = preload("res://game_logic/professions/GatherDefs.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")

var gather_id: String = ""
var kind: String = ""
var material: String = ""
var _respawn_msec: int = 0


func init_from_data(data: Dictionary) -> void:
	gather_id = str(data.get("id", ""))
	kind = str(data.get("kind", GatherDefs.HERB))
	material = str(data.get("material", ""))
	set_meta("gather_id", gather_id)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.45
	mesh.height = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _WEB.unshaded_material(GatherDefs.color(kind))
	mi.position = Vector3(0.0, 0.1, 0.0)
	add_child(mi)


func node_name() -> String:
	return GatherDefs.display_name(kind)


## True when the node can be harvested now. A depleted node comes back once its
## respawn time has passed.
func is_harvestable() -> bool:
	if visible:
		return true
	if Time.get_ticks_msec() >= _respawn_msec:
		visible = true
		return true
	return false


## Harvests the node. Returns the material id, or "" when it is not ready.
func harvest() -> String:
	if not is_harvestable():
		return ""
	visible = false
	_respawn_msec = Time.get_ticks_msec() + int(GatherDefs.respawn_seconds(kind) * 1000.0)
	return material


## Interact: the material goes to the bag and its profession earns the node XP.
func interact() -> void:
	var mat: String = harvest()
	if mat == "":
		return
	var sm := SceneManager.save_manager
	sm.professions.add_material(mat, 1)
	sm.professions.add_xp(GatherDefs.profession_for(mat), GatherDefs.xp(kind))
	AudioManager.play_sfx("chest_open")
	GameBus.hud_message_requested.emit("Gathered %s from a %s." % [ProfessionDefs.input_name(mat), node_name()])
