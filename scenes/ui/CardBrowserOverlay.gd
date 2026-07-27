## Base for the full-screen overlays that list cards and let the player open one
## for a closer look — the collection/deck builder (InventoryScene) and the shop
## (ShopScene). Both had the same _show_inspect verbatim.
##
## Subclass with `extends "res://scenes/ui/CardBrowserOverlay.gd"` and call
## _show_inspect(card_id) from whatever tap target the list builds.
##
## Kept separate from BaseOverlay on purpose: BaseOverlay is generic window
## chrome that ~20 unrelated overlays preload, and it has no business pulling in
## the card stack.
extends "res://scenes/ui/BaseOverlay.gd"

const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")

## The open inspect overlay, or null. Guards against stacking a second one.
var _inspect_overlay: Control = null

## Opens the card-detail overlay for `card_id`. No-op while one is already open,
## or when the id is not in the registry.
func _show_inspect(card_id: String) -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		return
	var tmpl: Dictionary = _CardRegistry.get_template(card_id)
	if tmpl.is_empty():
		return
	var overlay := CardInspectOverlay.new()
	overlay.present(self, CardInstance.new(tmpl), func() -> void: _inspect_overlay = null)
	_inspect_overlay = overlay
