## Combine-3 ritual (GID-180 / TID-742): three copies orbit, spiral together,
## flash, and the new higher-rarity card lands. Full-rect overlay; tap to skip
## the wait once the result shows.
extends Control

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardTile = preload("res://scenes/ui/inventory/CardTile.gd")
const _CardJuice = preload("res://scenes/ui/inventory/CardJuice.gd")

const ORBIT_S: float = 1.1

var _tiles: Array[Control] = []
var _ref: float = 0.0
var _centre: Vector2
var _radius: float = 0.0


func play(sources: Array[Dictionary], result: Dictionary, template: Dictionary, ref: float) -> void:
	_ref = ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_centre = get_viewport_rect().size * 0.5
	_radius = ref * 0.2
	for inst: Dictionary in sources:
		var t: Button = _CardTile.build(inst, template, ref)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size = t.custom_minimum_size
		t.pivot_offset = t.size * 0.5
		add_child(t)
		_tiles.append(t)
	_place(0.0)
	_CardJuice.sound("shuffle")
	var tw := create_tween()
	tw.tween_method(_place, 0.0, 1.0, ORBIT_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_flash.bind(result, template))


## Orbit progress 0..1: angle grows while the radius closes in.
func _place(p: float) -> void:
	for i in range(_tiles.size()):
		var a: float = TAU * (float(i) / float(_tiles.size()) + p * 1.5)
		var r: float = _radius * (1.0 - p)
		var t: Control = _tiles[i]
		t.position = _centre + Vector2(cos(a), sin(a)) * r - t.size * 0.5
		t.rotation = p * 0.6
		t.scale = Vector2.ONE * (1.0 - 0.4 * p)


func _flash(result: Dictionary, template: Dictionary) -> void:
	for t: Control in _tiles:
		t.queue_free()
	_tiles.clear()
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.35)
	var rarity: String = str(result.get("rarity", "common"))
	var card: Button = _CardTile.build(result, template, _ref * 1.4)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = card.custom_minimum_size
	card.position = _centre - card.size * 0.5
	add_child(card)
	_CardJuice.pop(card, 0.35)
	_CardJuice.sparkle(card, rarity, _ref * 1.5)
	_CardJuice.shimmer(card, rarity)
	_CardJuice.sound("place")
	var lbl := _UiUtil.make_label("Forged a %s %s!" % [rarity.capitalize(), str(template.get("name", ""))],
			int(_ref * 0.03), _UiUtil.rarity_color(rarity), HORIZONTAL_ALIGNMENT_CENTER, self)
	lbl.theme_type_variation = &"TitleLabel"
	lbl.size = Vector2(get_viewport_rect().size.x, _ref * 0.06)
	lbl.position = Vector2(0.0, card.position.y + card.size.y + _ref * 0.03)
	gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed:
			queue_free())
	create_tween().tween_interval(2.2).finished.connect(queue_free)
