## Card illustration on a battle card view. Panels are recycled by index when
## the hand or board shifts, so the art must follow the card, not the panel.
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

const NODE_NAME := "IllustrationRect"

static func texture_for(card: CardInstance) -> Texture2D:
	var tmpl: Dictionary = CardRegistry.get_template_for_face(card.template_id, card.active_face)
	return tmpl.get("illustration") as Texture2D

## Adds, swaps or hides the art on a (possibly reused) card vbox to match
## `card`. The art rect is always the vbox's first child.
static func apply(vbox: VBoxContainer, card: CardInstance, vh: float) -> void:
	set_texture(vbox, texture_for(card), vh)

static func set_texture(vbox: VBoxContainer, illus: Texture2D, vh: float) -> void:
	var art: TextureRect = vbox.get_node_or_null(NODE_NAME) as TextureRect
	if art == null:
		if illus == null:
			return
		art = TextureRect.new()
		art.name = NODE_NAME
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0.0, vh * 0.07)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(art)
		vbox.move_child(art, 0)
	art.texture = illus
	art.visible = illus != null
