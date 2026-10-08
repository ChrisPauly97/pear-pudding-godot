## Real-time draw pile (GID-178 / TID-725): a small stack of card backs with the
## cards-left count, beside the right end of the hand. Drawn cards and returning
## techniques fly out of it (`CardMotion.deal_from`), so a draw reads at a glance.
## Owned by `RealtimeVisuals`; presentation only.
extends RefCounted

const CardMotion = preload("res://scenes/battle/CardMotion.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Card backs drawn in the stack (offset a little each) for a pile with cards.
const STACK: int = 3

var control: Control
var _count: Label
var _backs: Array[Control] = []
var _last: int = -1

## Builds the pile under `parent`; `card` is a hand card's size.
func _init(parent: Control, card: Vector2, font_px: int) -> void:
	var size: Vector2 = card * 0.62
	control = Control.new()
	control.name = "DeckPile"
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.custom_minimum_size = size + Vector2(STACK, STACK) * 3.0
	control.size = control.custom_minimum_size
	parent.add_child(control)
	for i: int in STACK:
		var back: PanelContainer = CardMotion.make_back(size)
		back.position = Vector2(i, -i) * 3.0 + Vector2(0.0, STACK * 3.0)
		control.add_child(back)
		_backs.append(back)
	_count = _UiUtil.make_label("", font_px, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, control)
	_count.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_count.add_theme_constant_override("outline_size", maxi(2, font_px / 5))
	_count.position = Vector2(0.0, size.y * 0.5)
	_count.size = Vector2(size.x, font_px * 1.4)

## Shows `left` cards (an empty pile fades to a faint outline).
func set_count(left: int) -> void:
	if left == _last:
		return
	if _last >= 0 and left < _last:
		_bump()
	_last = left
	_count.text = str(left)
	for i: int in _backs.size():
		_backs[i].visible = left > i or i == 0
	_backs[0].modulate.a = 1.0 if left > 0 else 0.25

## Sits just right of `hand_right` (global x), bottom-aligned with the viewport.
func place(hand_right: float, vp: Vector2, margin: float) -> void:
	var x: float = minf(hand_right + margin * 2.0, vp.x - control.size.x - margin)
	control.position = Vector2(x, vp.y - control.size.y - margin)

## A card left the pile: the top back hops.
func _bump() -> void:
	var top: Control = _backs[mini(_backs.size() - 1, maxi(0, _last - 1))]
	top.pivot_offset = top.size * 0.5
	var tw: Tween = top.create_tween()
	tw.tween_property(top, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(top, "scale", Vector2.ONE, 0.14)
