extends "res://scenes/world/entities/WorldEntityBase.gd"

const TextureGen = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _ContactShadow = preload("res://game_logic/ContactShadow.gd")
const _IdleLife = preload("res://game_logic/IdleLife.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")

var npc_data: Dictionary = {}
var _flag_key: String = ""
var _after_dialogue: String = ""
var _dialogue_group: String = ""

func _ready() -> void:
	add_to_group("interactable")
	_ring = build_highlight_ring(self, 0.55)
	# Stable per-NPC look: same id/name always picks the same variant.
	var variant_seed: int = hash(str(npc_data.get("id", "")) + _extract_name())
	var sprite: Sprite3D = _SpriteRegistry.make_billboard(_SpriteRegistry.townsperson_texture(variant_seed),
			TextureGen.npc_townsperson(), _SpriteRegistry.HEIGHT_NPC)
	add_child(sprite)
	_SpriteOutline.apply(sprite)
	_ContactShadow.register(self, _ContactShadow.radius_for_height(_SpriteRegistry.HEIGHT_NPC))
	_IdleLife.register(sprite, _IdleLife.STYLE_BREATHE)
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
	if npc_data.has("name"):
		return str(npc_data["name"])
	# Unnamed extras get a role hashed from their spot, never the raw "NPC".
	var roles: Array[String] = ["Traveller", "Wanderer", "Farmhand", "Pilgrim", "Herbalist", "Shepherd"]
	return roles[absi(hash(Vector2i(int(npc_data.get("x", 0)), int(npc_data.get("z", 0))))) % roles.size()]

func get_dialogue() -> String:
	if _flag_key != "" and SaveManager.get_story_flag(_flag_key):
		return _after_dialogue
	if _dialogue_group != "" and NetworkManager.is_active() and multiplayer.get_peers().size() > 0:
		return _dialogue_group
	return str(npc_data.get("dialogue", "..."))
