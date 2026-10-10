## Crafting station (GID-182 / TID-762): a cooking fire, alchemy table or workbench.
## Placed by modules/CraftingStations.gd from StationSites. Pressing interact opens
## ProfessionPanel for the station's profession (`interact()`, via the simple-interaction table).
## Static scenery: not saved, not synced, no collision (the tile stays walkable).
extends Node3D

const _ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const _StationSites = preload("res://game_logic/professions/StationSites.gd")
const _CampfireVisual = preload("res://scenes/world/entities/CampfireVisual.gd")
const _WorldEntityBase = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

var site_id: String = ""
var kind: String = ""
## Profession this station crafts ("" for an unknown kind).
var profession: String = ""
## Set by modules/CraftingStations.gd: opens the panel for this station.
var on_interact: Callable = Callable()


func init_from_data(data: Dictionary) -> void:
	site_id = str(data.get("id", ""))
	kind = str(data.get("kind", ""))
	profession = _StationSites.profession_for(kind)


func interact() -> void:
	if on_interact.is_valid():
		on_interact.call(self)


func _ready() -> void:
	var tint: Color = Color.WHITE
	if _ProfessionDefs.PROFESSIONS.has(profession):
		var pdef: Dictionary = _ProfessionDefs.PROFESSIONS[profession]
		tint = pdef["color"] as Color
		var name_text: String = str(pdef["display_name"]) + " station"
		add_child(_SpriteRegistry.make_name_label(name_text, Color.WHITE, 1.9, 26, 0.02))
	if kind == "cooking_fire":
		_CampfireVisual.build(self, true)
	else:
		_build_table(tint)


## A plank top on two legs, in the profession colour.
func _build_table(tint: Color) -> void:
	var mat: StandardMaterial3D = _WorldEntityBase.unshaded_material(tint.darkened(0.35))
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(1.0, 0.12, 0.6)
	top.mesh = top_mesh
	top.material_override = mat
	top.position = Vector3(0.0, 0.95, 0.0)
	add_child(top)
	for sx: float in [-0.42, 0.42]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.1, 0.9, 0.1)
		leg.mesh = leg_mesh
		leg.material_override = mat
		leg.position = Vector3(sx, 0.45, 0.0)
		add_child(leg)
