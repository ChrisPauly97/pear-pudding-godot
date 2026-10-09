## The bag as a little satchel (GID-180 / TID-743): it fills as cards come in,
## bulges near the cap and has cards poking out when full. A mailbox count
## shows when overflow loot is waiting. Drawn, no textures.
extends Control

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _SatchelLines = preload("res://game_logic/inventory/SatchelLines.gd")

const LEATHER := Color(0.55, 0.36, 0.2)
const STRAP := Color(0.36, 0.22, 0.12)

var _used: int = 0
var _cap: int = 1
var _mail: int = 0
var _label: Label


func setup(ref: float) -> void:
	custom_minimum_size = Vector2(ref * 0.17, ref * 0.06)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = _UiUtil.make_label("", int(ref * 0.02), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, self)
	_label.position = Vector2(ref * 0.062, 0.0)
	_label.size = Vector2(ref * 0.11, ref * 0.06)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			GameBus.hud_message_requested.emit(_hint()))


func set_counts(used: int, cap: int, mail: int) -> void:
	_used = used
	_cap = cap
	_mail = mail
	var step: int = _SatchelLines.fullness(used, cap)
	_label.text = "%d/%d%s" % [used, cap, "  ✉%d" % mail if mail > 0 else ""]
	_label.modulate = Color(1.0, 0.45, 0.45) if step == 3 else (Color(1.0, 0.8, 0.4) if step == 2 else Color.WHITE)
	tooltip_text = _hint()
	queue_redraw()


func _hint() -> String:
	var t: String = "Bag: %d of %d slots used. Cards in your deck don't count." % [_used, _cap]
	if _mail > 0:
		t += "\n%d card%s wait in the mailbox — claim them at any town mailbox." % [_mail, "" if _mail == 1 else "s"]
	return t


func _draw() -> void:
	var h: float = size.y
	var step: int = _SatchelLines.fullness(_used, _cap)
	var bulge: float = [1.0, 1.0, 1.08, 1.14][step]
	var w: float = h * 0.9 * bulge
	var body := Rect2(Vector2((h - w) * 0.5 + h * 0.05, h * 0.3), Vector2(w, h * 0.65))
	# Cards poking out of a full (or nearly full) bag.
	if step >= 2:
		var n: int = 2 if step == 2 else 3
		for i in range(n):
			var cx: float = body.position.x + body.size.x * (0.25 + 0.25 * i)
			var card := PackedVector2Array([Vector2(cx - h * 0.09, h * 0.38), Vector2(cx + h * 0.05, h * 0.38),
				Vector2(cx + h * 0.08 + i * 2.0, h * 0.06), Vector2(cx - h * 0.06 + i * 2.0, h * 0.06)])
			draw_colored_polygon(card, Color(0.92, 0.88, 0.75))
	draw_rect(body, LEATHER)
	var fill: float = clampf(float(_used) / float(maxi(_cap, 1)), 0.0, 1.0)
	var fill_col: Color = Color(0.35, 0.75, 0.4) if step < 2 else (Color(1.0, 0.7, 0.3) if step == 2
			else Color(1.0, 0.35, 0.3))
	draw_rect(Rect2(body.position.x + 2.0, body.end.y - body.size.y * fill, body.size.x - 4.0,
			body.size.y * fill - 2.0), Color(fill_col, 0.55))
	# Flap and buckle.
	draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.35)), STRAP)
	draw_rect(Rect2(body.get_center().x - h * 0.05, body.position.y + body.size.y * 0.25, h * 0.1, h * 0.1),
			Color(0.9, 0.75, 0.3))
	# Shoulder strap.
	draw_arc(Vector2(body.get_center().x, body.position.y), body.size.x * 0.4, PI, TAU, 12, STRAP, 2.0)
