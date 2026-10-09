## Drag preview for a card on the deck table (GID-180 / TID-738): a lifted mini
## card over a soft shadow that tilts toward the direction it is being moved.
extends Control

const MAX_TILT: float = 0.22
const TILT_PER_PX: float = 0.012

var _last: Vector2 = Vector2.INF
var _card: Control


func setup(card: Control, ref: float) -> void:
	var shadow := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(int(ref * 0.012))
	shadow.add_theme_stylebox_override("panel", sb)
	shadow.size = card.custom_minimum_size
	shadow.position = -card.custom_minimum_size * 0.5 + Vector2(ref * 0.012, ref * 0.018)
	add_child(shadow)
	_card = card
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = card.custom_minimum_size
	card.pivot_offset = card.size * 0.5
	card.position = -card.size * 0.5
	card.scale = Vector2(1.08, 1.08)
	add_child(card)


func _process(_delta: float) -> void:
	if _card == null:
		return
	var p: Vector2 = global_position
	if _last != Vector2.INF:
		var target: float = clampf((p.x - _last.x) * TILT_PER_PX, -MAX_TILT, MAX_TILT)
		_card.rotation = lerpf(_card.rotation, target, 0.25)
	_last = p
