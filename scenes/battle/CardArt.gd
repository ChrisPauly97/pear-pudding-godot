## Card illustration on a battle card view. Panels are recycled by index when
## the hand or board shifts, so the art must follow the card, not the panel.
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const CardFace = preload("res://scenes/ui/CardFace.gd")

const NODE_NAME := "IllustrationRect"

static func texture_for(card: CardInstance) -> Texture2D:
	var tmpl: Dictionary = CardRegistry.get_template_view(card.template_id, card.active_face)
	return tmpl.get("illustration") as Texture2D

## Adds, swaps or hides the art on a (possibly reused) card vbox to match
## `card`. The art rect is always the vbox's first child, `art_h` px tall.
## `card_h` (> 0) also lays the branch background behind the art (GID-151).
static func apply(vbox: VBoxContainer, card: CardInstance, art_h: float, card_h: float = 0.0) -> void:
	set_texture(vbox, texture_for(card), art_h)
	var art: TextureRect = vbox.get_node_or_null(NODE_NAME) as TextureRect
	if art != null and card_h > 0.0:
		var tmpl: Dictionary = CardRegistry.get_template_view(card.template_id, card.active_face)
		CardFace.set_art_background(art, str(tmpl.get("magic_branch", card.magic_branch)), card_h)

static func set_texture(vbox: VBoxContainer, illus: Texture2D, art_h: float) -> void:
	var art: TextureRect = vbox.get_node_or_null(NODE_NAME) as TextureRect
	if art == null:
		if illus == null:
			return
		art = CardFace.make_art(null, art_h)
		art.name = NODE_NAME
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(art)
		vbox.move_child(art, 0)
	art.texture = illus
	art.visible = illus != null
