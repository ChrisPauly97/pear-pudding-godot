## Unit tests for the master pixel palette (game_logic/PixelPalette.gd).
##
## The sprite generators read tools/pixel_palette.py and the runtime reads
## PixelPalette.gd; if they drift, generated props and the paper-doll hero stop
## sharing colours with the pack sprites and nothing else notices.
extends "res://tests/framework/test_case.gd"

const _PixelPalette = preload("res://game_logic/PixelPalette.gd")
const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")


func _python_palette() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var f := FileAccess.open("res://tools/pixel_palette.py", FileAccess.READ)
	if f == null:
		return out
	var text: String = f.get_as_text()
	# PACK and EXTRA are the lists before PALETTE = PACK + EXTRA.
	var body: String = text.substr(0, text.find("PALETTE = PACK + EXTRA"))
	var re := RegEx.new()
	re.compile("\\((\\d+), (\\d+), (\\d+)\\)")
	for m: RegExMatch in re.search_all(body):
		out.append(Vector3i(int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3))))
	return out


func test_runtime_palette_matches_generator_palette() -> void:
	var py: Array[Vector3i] = _python_palette()
	assert_eq(py.size(), _PixelPalette.RGB.size(), "same number of colours")
	for i: int in mini(py.size(), _PixelPalette.RGB.size()):
		assert_eq(_PixelPalette.RGB[i], py[i], "colour %d matches" % i)


func test_nearest_is_identity_on_palette_colours() -> void:
	for i: int in _PixelPalette.RGB.size():
		var c: Color = _PixelPalette.color(i)
		assert_eq(_PixelPalette.nearest(c), c)


func test_hero_frames_only_use_palette_colours() -> void:
	var allowed: Dictionary = {}
	for v: Vector3i in _PixelPalette.RGB:
		allowed[v] = true
	var gear := {"armor": "warded_cloak", "shoulders": "spiked_spaulders", "weapon": "dusk_blade",
			"offhand": "iron_shield", "trinket": "lucky_coin"}
	for anim: String in ["idle", "walk", "swing"]:
		var img: Image = _PaperDoll.render_frame(gear, {}, anim, 1)
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a8 > 0:
					assert_true(allowed.has(Vector3i(c.r8, c.g8, c.b8)),
							"%s pixel %d,%d is off-palette" % [anim, x, y])
