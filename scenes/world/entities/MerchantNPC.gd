extends "res://scenes/world/entities/WorldEntityBase.gd"

const TextureGen = preload("res://game_logic/TextureGen.gd")

var npc_data: Dictionary = {}
var _is_traveling: bool = false

func _ready() -> void:
	add_to_group("interactable")
	_ring = build_highlight_ring(self, 0.55)
	var sprite := Sprite3D.new()
	sprite.texture = TextureGen.npc_merchant(_is_traveling)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.04
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(0.0, 0.69, 0.0)
	add_child(sprite)
	_add_name_label()

func init_from_data(data: Dictionary) -> void:
	npc_data = data
	_is_traveling = bool(data.get("is_traveling", false))

func _add_name_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "Traveling Merchant" if _is_traveling else "Merchant"
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = Color(0.85, 0.6, 1.0) if _is_traveling else Color(1.0, 0.85, 0.1)
	add_child(lbl)

func get_dialogue() -> String:
	if _is_traveling:
		return "Rare wares, straight from the ends of the world!"
	return "Welcome, traveller! Browse my wares."
