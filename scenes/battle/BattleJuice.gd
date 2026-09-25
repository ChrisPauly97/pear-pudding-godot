extends RefCounted
## Battle juice (GID-132 / TID-512): the motion layer on top of BattleFx's
## flashes, lunges and shake. Static helpers; BattleFx owns when they fire.
##
##   * pop_label   — damage/heal numbers pop in (back-ease), arc up with a
##                   little sideways drift, and scale with the amount.
##   * punch       — a struck card/hero squashes, overshoots and wiggles.
##   * sparks      — one-shot CPUParticles2D burst at the hit point.
##   * pop_in      — a card landing on the board grows in from 60 %.
## "Reduce Flashing" (Settings) keeps the motion but drops the sparks and
## softens the flash colour (see `flash_color`).

const BIG_HIT: int = 5
const SPARK_BASE: int = 10
const SPARK_MAX: int = 28


static func reduce_flashing() -> bool:
	return bool(SaveManager.get_setting("reduce_flashing", false))


## Flash tint for a hit (`heal` = green); milder with Reduce Flashing.
static func flash_color(heal: bool) -> Color:
	var c: Color = Color(0.3, 1.0, 0.5) if heal else Color(1.0, 0.3, 0.3)
	return Color.WHITE.lerp(c, 0.45) if reduce_flashing() else c


## Font-size multiplier for a damage/heal number of `amount`.
static func label_scale(amount: int) -> float:
	return clampf(1.0 + float(absi(amount) - 1) * 0.08, 1.0, 1.8)


## Pops, arcs and fades a label already parented and positioned at `pos`.
static func pop_label(lbl: Label, pos: Vector2, amount: int) -> void:
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2.ZERO
	var drift: float = randf_range(-28.0, 28.0)
	var s: float = label_scale(amount)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(s * 1.3, s * 1.3), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(s, s), 0.08)
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 90.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:x", pos.x + drift, 0.75)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(lbl.queue_free)


## Squash-overshoot-wiggle on a struck Control. Safe on freed/recycled nodes.
static func punch(node: Control, big: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var amp: float = 1.0 if not big else 1.6
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.0 + 0.1 * amp, 1.0 - 0.12 * amp), 0.05)
	tw.tween_property(node, "scale", Vector2(1.0 - 0.05 * amp, 1.0 + 0.06 * amp), 0.07)
	tw.tween_property(node, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rot: Tween = node.create_tween()
	for a: float in [4.0, -3.0, 1.5, 0.0]:
		rot.tween_property(node, "rotation", deg_to_rad(a * amp), 0.045)


## One-shot spark burst at `pos` on `layer`; bigger for bigger hits.
static func sparks(layer: Node, pos: Vector2, color: Color, amount: int) -> void:
	if layer == null or not is_instance_valid(layer) or reduce_flashing():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(SPARK_BASE + absi(amount) * 2, SPARK_BASE, SPARK_MAX)
	p.lifetime = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 700)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	# Hot white core → hit colour → fade, bright past the glow threshold early on.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color(1.6, 1.5, 1.2, 1), Color(color.r * 1.3, color.g * 1.2, color.b, 1),
			Color(color.r, color.g, color.b, 0)])
	p.color_ramp = ramp
	layer.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Grows a freshly placed board card in from 60 % with a small overshoot.
static func pop_in(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
