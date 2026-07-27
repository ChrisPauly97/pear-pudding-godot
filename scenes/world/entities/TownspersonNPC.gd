extends "res://scenes/world/entities/WorldEntityBase.gd"

const TextureGen = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

var npc_data: Dictionary = {}
var _flag_key: String = ""
var _after_dialogue: String = ""
var _dialogue_group: String = ""

func _ready() -> void:
	add_to_group("interactable")
	_ring = build_highlight_ring(self, 0.55)
	# Stable per-NPC look: same id/name always picks the same variant.
	var variant_seed: int = hash(str(npc_data.get("id", "")) + _extract_name())
	var sprite: Sprite3D = _SpriteRegistry.make_billboard(_SpriteRegistry.townsperson_texture(variant_seed), TextureGen.npc_townsperson(), _SpriteRegistry.HEIGHT_NPC)
	add_child(sprite)
	_add_name_label()

func init_from_data(data: Dictionary) -> void:
	npc_data = data
	_flag_key = str(data.get("flag_key", ""))
	_after_dialogue = str(data.get("after_dialogue", ""))
	_dialogue_group = str(data.get("dialogue_group", ""))

func _add_name_label() -> void:
	var npc_name: String = _extract_name()
	add_child(_SpriteRegistry.make_name_label(npc_name, Color.YELLOW))

func _extract_name() -> String:
	var dlg: String = str(npc_data.get("dialogue", ""))
	var lower: String = dlg.to_lower()
	var name_idx: int = lower.find("my name is ")
	if name_idx >= 0:
		var after: String = dlg.substr(name_idx + 11)
		var end: int = after.find(".")
		if end < 0:
			end = after.find("!")
		if end < 0:
			end = after.find(",")
		if end > 0:
			return after.substr(0, end).strip_edges()
	return "NPC"

func get_dialogue() -> String:
	if _flag_key != "" and SaveManager.get_story_flag(_flag_key):
		return _after_dialogue
	if _dialogue_group != "" and NetworkManager.is_active() and multiplayer.get_peers().size() > 0:
		return _dialogue_group
	return str(npc_data.get("dialogue", "..."))
