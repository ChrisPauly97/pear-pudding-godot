## The game's master pixel-art palette: the 0x72 character pack's 49 colours
## plus three foliage/earth steps. Mirrors tools/pixel_palette.py (the sprite
## generators' copy); test_pixel_palette keeps the two in sync.
##
## Runtime-drawn sprites (the paper-doll hero) end with `quantize()`, so their
## derived shades and grime land on the same colours as the pack sprites.
extends RefCounted

const RGB: Array[Vector3i] = [
	Vector3i(17, 17, 17), Vector3i(34, 34, 34), Vector3i(72, 59, 58), Vector3i(118, 59, 54),
	Vector3i(143, 64, 41), Vector3i(138, 80, 62), Vector3i(178, 58, 58), Vector3i(119, 92, 85),
	Vector3i(218, 78, 56), Vector3i(214, 72, 72), Vector3i(197, 96, 37), Vector3i(189, 108, 74),
	Vector3i(228, 110, 51), Vector3i(181, 128, 87), Vector3i(238, 142, 46), Vector3i(170, 141, 122),
	Vector3i(195, 141, 112), Vector3i(216, 165, 125), Vector3i(226, 182, 148), Vector3i(211, 191, 169),
	Vector3i(252, 203, 163), Vector3i(253, 247, 237), Vector3i(250, 203, 62), Vector3i(151, 218, 63),
	Vector3i(75, 167, 71), Vector3i(61, 115, 79), Vector3i(73, 167, 144), Vector3i(114, 214, 206),
	Vector3i(20, 27, 42), Vector3i(49, 65, 82), Vector3i(82, 96, 124), Vector3i(65, 112, 137),
	Vector3i(123, 137, 148), Vector3i(86, 152, 204), Vector3i(139, 155, 180), Vector3i(126, 152, 211),
	Vector3i(151, 197, 255), Vector3i(192, 203, 220), Vector3i(42, 42, 58), Vector3i(89, 86, 189),
	Vector3i(96, 52, 135), Vector3i(146, 86, 190), Vector3i(95, 45, 86), Vector3i(63, 38, 49),
	Vector3i(159, 41, 78), Vector3i(220, 74, 123), Vector3i(98, 35, 47), Vector3i(115, 40, 52),
	Vector3i(247, 134, 151),
	# Extra steps the pack lacks (foliage shadow, earth mid, earth shadow).
	Vector3i(38, 72, 56), Vector3i(104, 70, 48), Vector3i(84, 54, 38),
]


## Palette colour `i` as a Color.
static func color(i: int) -> Color:
	var v: Vector3i = RGB[i]
	return Color8(v.x, v.y, v.z)


## Nearest palette colour ("redmean" weighted RGB, close to perceptual).
static func nearest(c: Color) -> Color:
	var r: int = c.r8
	var g: int = c.g8
	var b: int = c.b8
	var best: Vector3i = RGB[0]
	var best_d: float = INF
	for p: Vector3i in RGB:
		var rm: float = (r + p.x) * 0.5
		var d: float = (2.0 + rm / 256.0) * (r - p.x) * (r - p.x) + 4.0 * (g - p.y) * (g - p.y) \
				+ (2.0 + (255.0 - rm) / 256.0) * (b - p.z) * (b - p.z)
		if d < best_d:
			best_d = d
			best = p
	return Color8(best.x, best.y, best.z, c.a8)


## Snaps every visible pixel of `img` to the palette in place (alpha kept).
static func quantize(img: Image) -> void:
	var memo: Dictionary = {}
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var key: int = c.to_rgba32()
			if not memo.has(key):
				memo[key] = nearest(c)
			img.set_pixel(x, y, memo[key] as Color)
