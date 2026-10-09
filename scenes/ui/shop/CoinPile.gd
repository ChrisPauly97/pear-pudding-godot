## A growing pile of gold coins on the vendor counter (GID-180 / TID-745).
## `add(n)` drops coins onto the pile; drawn, no textures.
extends Control

const GOLD := Color(1.0, 0.82, 0.25)
const EDGE := Color(0.7, 0.5, 0.1)
const MAX_COINS: int = 36

var _coins: int = 0
var _drop: float = 1.0  # 0 → 1 while the newest coins fall in


func add(n: int) -> void:
	_coins = mini(MAX_COINS, _coins + maxi(1, n))
	_drop = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_drop", 1.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.3)


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.13
	var base := Vector2(size.x * 0.5, size.y - r * 0.6)
	var row: int = 0
	var col: int = 0
	var width: int = 6
	for i in range(_coins):
		if col >= width:
			row += 1
			col = 0
			width = maxi(1, width - 1)
		var x: float = base.x + (float(col) - float(width - 1) * 0.5) * r * 1.3
		var y: float = base.y - row * r * 0.55
		col += 1
		if i == _coins - 1:
			y -= (1.0 - _drop) * size.y * 0.6
		var c := Vector2(x, y)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, r, EDGE)
		draw_circle(Vector2(0, -r * 0.25), r * 0.92, GOLD)
		draw_set_transform(Vector2.ZERO)
