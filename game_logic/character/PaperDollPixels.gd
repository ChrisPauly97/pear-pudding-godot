## Pixel helpers shared by the PaperDoll hero renderer (GID-137): clipped
## pixel/rect writes, Bresenham lines, the grime dither and the cool-shadow /
## warm-highlight tones. Extended by PaperDollGear → PaperDoll.
extends RefCounted

## X shift applied by `_px`: the body column's left edge inside the frame
## (PaperDoll.render_pose sets it; 0 while drawing into a scratch image).
static var _ox: int = 0

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	var xx: int = x + _ox
	if xx >= 0 and y >= 0 and xx < img.get_width() and y < img.get_height():
		img.set_pixel(xx, y, c)


## Bresenham points from `a` to `b` inclusive.
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx + dy
	var cur: Vector2i = a
	while true:
		pts.append(cur)
		if cur == b:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			cur.x += sx
		if e2 <= dx:
			err += dx
			cur.y += sy
	return pts


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_px(img, xx, yy, c)


## Fixed per-pixel noise in [0, 7): the same pixel always gets the same grime,
## so frames don't shimmer as the hero walks.
static func _grain(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995) % 7


## A worn surface: base colour with a sparse dark grime dither and a few
## scuffed light pixels. `grit` 0 = clean, 1 = filthy.
static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color, grit: float = 0.5) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			var g: int = _grain(xx, yy)
			var col: Color = c
			if g == 0:
				col = _shadow(c, 0.18 * grit + 0.04)
			elif g == 1 and grit > 0.3:
				col = c.darkened(0.08)
			elif g == 6 and grit > 0.6:
				col = c.lightened(0.07)
			_px(img, xx, yy, col)


## Shadow tone: darker and pushed slightly cool, so shading doesn't look muddy.
static func _shadow(c: Color, amount: float = 0.3) -> Color:
	var d: Color = c.darkened(amount)
	return Color(d.r * 0.95, d.g * 0.97, minf(d.b * 1.08 + 0.01, 1.0), c.a)


## Highlight tone: lighter and pushed slightly warm.
static func _light(c: Color, amount: float = 0.15) -> Color:
	var l: Color = c.lightened(amount)
	return Color(minf(l.r * 1.03, 1.0), l.g, l.b * 0.96, c.a)


static func _col(d: Dictionary, key: String) -> Color:
	var c: Color = d.get(key, Color.MAGENTA)
	return c
