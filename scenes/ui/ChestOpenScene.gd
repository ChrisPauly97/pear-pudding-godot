extends Control

signal closed

var card_ids: Array = []
var _vh: float = 0.0
var _vw: float = 0.0
var _landed: int = 0

@onready var _claim_btn: Button = $ClaimButton

func _ready() -> void:
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_claim_btn.pressed.connect(func() -> void: closed.emit())
	_claim_btn.custom_minimum_size = Vector2(_vw * 0.18, _vh * 0.07)
	_add_chest_visual()
	_launch_all()

func _chest_y() -> float:
	return _vh * 0.8

func _add_chest_visual() -> void:
	var cw: float = _vh * 0.1
	var ch: float = _vh * 0.075
	var rect := ColorRect.new()
	rect.color = Color(0.52, 0.35, 0.08)
	rect.custom_minimum_size = Vector2(cw, ch)
	rect.position = Vector2(_vw * 0.5 - cw * 0.5, _chest_y() - ch * 0.5)
	add_child(rect)

func _launch_all() -> void:
	var n: int = card_ids.size()
	if n == 0:
		_claim_btn.show()
		return
	var cw: float = _vh * 0.13
	var ch: float = _vh * 0.21
	var gap: float = _vh * 0.02
	var total_w: float = n * cw + (n - 1) * gap
	var start_x: float = _vw * 0.5 - total_w * 0.5
	var land_y: float = _vh * 0.32
	for i in n:
		var to := Vector2(start_x + i * (cw + gap), land_y)
		_launch_card(i, card_ids[i], to, cw, ch)

# Async: each card runs its own coroutine, staggered by idx * 0.2 s.
func _launch_card(idx: int, card_id: String, to: Vector2, cw: float, ch: float) -> void:
	var card := _make_card(card_id, cw, ch)
	card.z_index = 2
	var from := Vector2(_vw * 0.5 - cw * 0.5, _chest_y() - ch * 0.5)
	card.position = from
	card.modulate.a = 0.0
	add_child(card)

	await get_tree().create_timer(idx * 0.2, true).timeout
	card.modulate.a = 1.0

	var dur: float = 0.5 + randf() * 0.1
	var peak: float = randf_range(_vh * 0.22, _vh * 0.32)
	var spin: float = randf_range(-0.25, 0.25)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:x", to.x, dur).set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(
		func(t: float) -> void:
			card.position.y = from.y + (to.y - from.y) * t - sin(t * PI) * peak,
		0.0, 1.0, dur
	)
	tween.tween_property(card, "rotation", spin, dur)
	await tween.finished

	# Settle onto landing spot
	var settle := create_tween()
	settle.tween_property(card, "rotation", 0.0, 0.08)
	await settle.finished

	var center := Vector2(to.x + cw * 0.5, to.y + ch * 0.5)
	_spawn_shine(center)
	_spawn_sparks(center)

	_landed += 1
	if _landed == card_ids.size():
		await get_tree().create_timer(0.4, true).timeout
		_claim_btn.show()

# -------------------------------------------------------------------------
# Landing effects
# -------------------------------------------------------------------------

func _spawn_shine(pos: Vector2) -> void:
	var size: float = _vh * 0.26
	var glow := TextureRect.new()
	glow.texture = _radial_tex(Color(1.0, 0.85, 0.2, 0.8), 256)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.custom_minimum_size = Vector2(size, size)
	glow.position = pos - Vector2(size * 0.5, size * 0.5)
	glow.z_index = 1
	glow.modulate.a = 0.0
	add_child(glow)

	# Flash in
	var flash := create_tween()
	flash.set_parallel(true)
	flash.tween_property(glow, "modulate:a", 1.0, 0.1)
	flash.tween_property(glow, "scale", Vector2(1.25, 1.25), 0.1)
	await flash.finished

	# Gentle pulse loop
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(glow, "scale", Vector2(1.35, 1.35), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "scale", Vector2(1.1, 1.1), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_sparks(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 22
	p.lifetime = 0.85
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.3, 1.0))
	ramp.set_color(1, Color(1.0, 0.5, 0.0, 0.0))
	p.color_ramp = ramp
	p.z_index = 3
	add_child(p)
	p.emitting = true
	await get_tree().create_timer(2.0, true).timeout
	p.queue_free()

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------

func _radial_tex(color: Color, res: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_offset(0, 0.0)
	var edge: Color = color
	edge.a = 0.0
	grad.set_color(1, edge)
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = res
	tex.height = res
	return tex

func _make_card(card_id: String, cw: float, ch: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(cw, ch)
	var vbox := VBoxContainer.new()
	var tmpl := CardRegistry.get_template(card_id)

	var name_lbl := Label.new()
	name_lbl.text = tmpl.get("name", card_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))

	var stats_lbl := Label.new()
	stats_lbl.text = "%d/%d  (%d)" % [tmpl.get("attack", 0), tmpl.get("health", 0), tmpl.get("cost", 0)]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.013))

	var desc_lbl := Label.new()
	desc_lbl.text = tmpl.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.011))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	vbox.add_child(name_lbl)
	vbox.add_child(stats_lbl)
	vbox.add_child(desc_lbl)
	panel.add_child(vbox)

	var style := StyleBoxFlat.new()
	style.bg_color = tmpl.get("color", Color(0.25, 0.25, 0.3))
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.border_color = Color(1.0, 0.78, 0.15)
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _claim_btn.visible:
		closed.emit()
