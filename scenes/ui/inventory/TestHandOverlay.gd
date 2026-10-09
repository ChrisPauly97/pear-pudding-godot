## "Try a hand" (GID-180 / TID-740): shuffles the deck and deals a sample
## opening hand the way a real-time fight would, so a player can feel the deck
## without starting a battle. Full-rect dim layer; tap outside or Close to leave.
extends Control

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardTile = preload("res://scenes/ui/inventory/CardTile.gd")
const _CardJuice = preload("res://scenes/ui/inventory/CardJuice.gd")
const _DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")

var _insts: Array[Dictionary] = []
var _draw_n: int = 3
var _template_for: Callable
var _ref: float = 0.0
var _row: HBoxContainer
var _seed: int = 0


func open(insts: Array[Dictionary], draw_n: int, template_for: Callable, ref: float) -> void:
	_insts = insts
	_draw_n = draw_n
	_template_for = template_for
	_ref = ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed:
			queue_free())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var vb := _UiUtil.make_vbox(int(ref * 0.02), center)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _UiUtil.make_label("Your opening hand", int(ref * 0.032), Color(1.0, 0.9, 0.65),
			HORIZONTAL_ALIGNMENT_CENTER, vb)
	title.theme_type_variation = &"TitleLabel"
	_row = _UiUtil.make_hbox(int(ref * 0.012), vb)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.custom_minimum_size = Vector2(0, _CardTile.tile_size(ref).y * 1.1)
	var btns := _UiUtil.make_hbox(int(ref * 0.012), vb)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_UiUtil.make_button("⟳ Shuffle & draw again", Vector2(ref * 0.26, ref * 0.06), int(ref * 0.021), _deal, btns)
	_UiUtil.make_button("Close", Vector2(ref * 0.14, ref * 0.06), int(ref * 0.021), queue_free, btns)
	_seed = int(Time.get_ticks_usec())
	_deal.call_deferred()


func _deal() -> void:
	_seed += 1
	for c in _row.get_children():
		c.queue_free()
	_CardJuice.sound("shuffle")
	var hand: Array[Dictionary] = _DeckInsights.sample_hand(_insts, _draw_n, _seed)
	for i in range(hand.size()):
		var inst: Dictionary = hand[i]
		var tile: Button = _CardTile.build(inst, _template_for.call(str(inst.get("template_id", ""))), _ref)
		tile.modulate.a = 0.0
		_row.add_child(tile)
		var tw := tile.create_tween()
		tw.tween_interval(0.12 * i + 0.15)
		tw.tween_callback(func() -> void:
			_CardJuice.sound("place")
			_CardJuice.pop(tile, 0.2))
		tw.tween_property(tile, "modulate:a", 1.0, 0.12)
