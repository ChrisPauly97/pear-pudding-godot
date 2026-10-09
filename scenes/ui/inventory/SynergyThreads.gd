## Threads of light between deck cards that combo (GID-180 / TID-740). Sits over
## the deck grid with the same origin, so tile rects are in its own space.
extends Control

const _MagicTypes = preload("res://game_logic/MagicTypes.gd")

const KEYWORD_COLOR := Color(1.0, 0.85, 0.35)

var _pairs: Array[Dictionary] = []
var _tile_for: Callable
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `tile_for(uid) -> Control` resolves a deck tile (null if not shown).
func set_pairs(pairs: Array[Dictionary], tile_for: Callable) -> void:
	_pairs = pairs
	_tile_for = tile_for
	set_process(not _pairs.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not _tile_for.is_valid():
		return
	var pulse: float = 0.55 + 0.3 * sin(_t * 2.4)
	for p: Dictionary in _pairs:
		var a: Control = _tile_for.call(str(p["a"]))
		var b: Control = _tile_for.call(str(p["b"]))
		if a == null or b == null:
			continue
		var col: Color = KEYWORD_COLOR if str(p["kind"]) == "keyword" \
				else _MagicTypes.branch_color(str(p["tag"]))
		var pa: Vector2 = a.position + a.size * 0.5
		var pb: Vector2 = b.position + b.size * 0.5
		var w: float = maxf(2.0, a.size.x * 0.03)
		draw_line(pa, pb, Color(col, 0.18 * pulse), w * 3.0, true)
		draw_line(pa, pb, Color(col, 0.75 * pulse), w, true)
		draw_circle(pa, w * 1.6, Color(col, pulse))
		draw_circle(pb, w * 1.6, Color(col, pulse))
