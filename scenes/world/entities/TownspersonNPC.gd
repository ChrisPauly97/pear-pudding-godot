extends "res://scenes/world/entities/WorldEntityBase.gd"

const TextureGen = preload("res://game_logic/TextureGen.gd")

var npc_data: Dictionary = {}
var _flag_key: String = ""
var _after_dialogue: String = ""
var _dialogue_group: String = ""

func _ready() -> void:
	add_to_group("interactable")
	_ring = build_highlight_ring(self, 0.55)
	var sprite := Sprite3D.new()
	sprite.texture = TextureGen.npc_townsperson()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.04
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(0.0, 0.69, 0.0)
	add_child(sprite)
	_add_name_label()

func init_from_data(data: Dictionary) -> void:
	npc_data = data
	_flag_key = str(data.get("flag_key", ""))
	_after_dialogue = str(data.get("after_dialogue", ""))
	_dialogue_group = str(data.get("dialogue_group", ""))

func _add_name_label() -> void:
	var npc_name: String = _extract_name()
	var lbl := Label3D.new()
	lbl.text = npc_name
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = Color.YELLOW
	add_child(lbl)

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
