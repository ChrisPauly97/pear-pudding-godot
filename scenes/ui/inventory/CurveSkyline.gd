## Mana curve drawn as a little skyline (GID-180 / TID-740): one building per
## cost bucket, heights ease toward the new curve whenever the deck changes.
extends Control

const _DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")

var tint: Color = Color(0.85, 0.75, 0.45)
var _target: Array[float] = []
var _shown: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(_DeckInsights.CURVE_MAX + 1):
		_target.append(0.0)
		_shown.append(0.0)
	set_process(false)


func set_curve(curve: Array[int]) -> void:
	var top: int = 1
	for n: int in curve:
		top = maxi(top, n)
	for i in range(mini(curve.size(), _target.size())):
		_target[i] = float(curve[i]) / float(top)
	tooltip_text = "Mana curve: " + "  ".join(PackedStringArray(curve.map(
			func(n: int) -> String: return str(n))))
	set_process(true)


func _process(delta: float) -> void:
	var moving: bool = false
	for i in range(_shown.size()):
		_shown[i] = move_toward(_shown[i], _target[i], delta * 3.0)
		moving = moving or not is_equal_approx(_shown[i], _target[i])
	queue_redraw()
	if not moving:
		set_process(false)


func _draw() -> void:
	var n: int = _shown.size()
	var w: float = size.x / float(n)
	var font: Font = get_theme_default_font()
	var fs: int = maxi(8, int(size.y * 0.22))
	var base: float = size.y - float(fs) - 2.0
	for i in range(n):
		var h: float = maxf(2.0, _shown[i] * base)
		var r := Rect2(i * w + w * 0.15, base - h, w * 0.7, h)
		draw_rect(r, tint.darkened(0.15 * float(i % 2)))
		# Lit windows on the taller buildings.
		var rows: int = int(h / (w * 0.35))
		for y in range(rows):
			draw_rect(Rect2(r.position.x + w * 0.2, r.end.y - (y + 1) * w * 0.35 + w * 0.08, w * 0.3, w * 0.15),
					Color(1.0, 0.95, 0.6, 0.55))
		var lbl: String = str(i) if i < n - 1 else "%d+" % i
		draw_string(font, Vector2(i * w, size.y - 2.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, w, fs,
				Color(0.75, 0.75, 0.8))
