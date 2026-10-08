## Auto-attack feel for real-time fights (GID-178 / TID-726): hero tokens wind
## up over the end of their swing timer (lean back, swell, warm glow), and every
## swing lands with an impact — a slash streak and a spray of sparks at the
## target. Presentation only; static helpers used by `RealtimeVisuals` (wind-up,
## per frame) and `BattleRealtime._animate_swing` (impact).
extends RefCounted

## The wind-up runs over the last part of the swing timer.
const WIND_UP_FROM: float = 0.65
const LEAN_DEG: float = 6.0
const SWELL: float = 0.1
const SLASH_TIME: float = 0.22
const SPARKS: int = 7
## Impact colours: your hits (warm gold) and the enemy's (red).
const PLAYER_HIT := Color(1.0, 0.85, 0.45)
const ENEMY_HIT := Color(1.0, 0.35, 0.3)

## Leans `tok` back and swells it as its swing (`frac` 0..1) comes round. The
## player leans left (away from the enemy), enemies lean right. No-op mid-lunge.
static func wind_up(tok: Control, frac: float, is_player: bool) -> void:
	if tok == null or tok.has_meta("lunging"):
		return
	var w: float = clampf((frac - WIND_UP_FROM) / (1.0 - WIND_UP_FROM), 0.0, 1.0)
	w = w * w  # ease in: the last beat is the tell
	tok.pivot_offset = Vector2(tok.size.x * 0.5, tok.size.y)
	tok.scale = Vector2.ONE * (1.0 + SWELL * w)
	tok.rotation = deg_to_rad((-LEAN_DEG if is_player else LEAN_DEG) * w)
	tok.self_modulate = Color.WHITE.lerp(Color(1.25, 1.15, 0.9), w)

## A slash streak and sparks at `pos` (global) on `layer`, after `delay` s (to
## meet the lunge). `vh` sizes it; `player_hit` picks the colour.
static func impact(layer: Node, pos: Vector2, vh: float, player_hit: bool, delay: float = 0.12) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	var tint: Color = PLAYER_HIT if player_hit else ENEMY_HIT
	var reach: float = vh * 0.09
	var slash := Line2D.new()
	slash.width = vh * 0.014
	slash.default_color = tint
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	var dir := Vector2(1.0, -0.8).normalized() if player_hit else Vector2(-1.0, -0.8).normalized()
	slash.add_point(pos - dir * reach * 0.5)
	slash.add_point(pos + dir * reach * 0.5)
	slash.modulate.a = 0.0
	slash.width_curve = _taper()
	layer.add_child(slash)
	var tw: Tween = slash.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(slash, "modulate:a", 1.0, 0.03)
	tw.tween_property(slash, "modulate:a", 0.0, SLASH_TIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(slash.queue_free)
	for i: int in SPARKS:
		_spark(layer, pos, vh, tint, delay, TAU * float(i) / float(SPARKS) + 0.4)

static func _spark(layer: Node, pos: Vector2, vh: float, tint: Color, delay: float, angle: float) -> void:
	var s := ColorRect.new()
	var d: float = vh * 0.008
	s.size = Vector2(d, d)
	s.color = tint.lightened(0.3)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.position = pos - s.size * 0.5
	s.modulate.a = 0.0
	layer.add_child(s)
	var to: Vector2 = s.position + Vector2.from_angle(angle) * vh * 0.06
	var tw: Tween = s.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(s, "modulate:a", 1.0, 0.02)
	tw.set_parallel(true)
	tw.tween_property(s, "position", to, SLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, SLASH_TIME)
	tw.chain().tween_callback(s.queue_free)

## Thin at both ends, full in the middle.
static func _taper() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.2))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1.0, 0.2))
	return c
