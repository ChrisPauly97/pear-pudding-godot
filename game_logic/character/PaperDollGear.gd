## Gear drawing for the PaperDoll hero (GID-137): cloak, shoulders, helmets,
## boots, trinkets and held items, including rotating an angled weapon about its grip.
## Extends the pixel helpers; PaperDoll extends this.
extends "res://game_logic/character/PaperDollPixels.gd"

## Scratch canvas for rotating held items (fits a staff at any angle).
const _SCRATCH: int = 44


static func _draw_hand(img: Image, look: Dictionary, hand: Vector2i, back: bool) -> void:
	var skin: Color = _col(look, "skin")
	_rect(img, hand.x, hand.y, 2, 1, _shadow(skin, 0.25) if back else skin)
	_px(img, hand.x + 1, hand.y, _shadow(skin, 0.35 if back else 0.15))  # knuckles


static func _draw_cloak_back(img: Image, armor: Dictionary, bob: int) -> void:
	var main: Color = _shadow(_col(armor, "main"), 0.3)
	_fill(img, 3, 10 + bob, 10, 12, main, 0.9)
	_rect(img, 2, 14 + bob, 1, 9, main)                           # flare at the hem
	# Ragged hem: every other pixel hangs one lower.
	for xx: int in range(2, 12):
		if xx % 2 == 0:
			_px(img, xx, 22 + bob, main)


static func _draw_cloak_front(img: Image, armor: Dictionary, bob: int) -> void:
	var main: Color = _col(armor, "main")
	_fill(img, 3, 9 + bob, 10, 2, main, 0.8)                      # mantle over the shoulders
	_rect(img, 3, 10 + bob, 2, 1, _shadow(main))
	_rect(img, 3, 9 + bob, 10, 1, _light(main, 0.1))
	_px(img, 8, 10 + bob, _col(armor, "trim"))                    # tarnished clasp


## Shoulder gear caps both arms. The back pauldron sits in shade.
static func _draw_shoulders(img: Image, item: Dictionary, bob: int) -> void:
	if item.is_empty():
		return
	var main: Color = _col(item, "main")
	var trim: Color = _col(item, "trim")
	var y: int = 9 + bob
	for back: bool in [true, false]:
		var tone: Color = _shadow(main, 0.3) if back else main
		var x: int = 2 if back else 10
		match str(item.get("style", "")):
			"pauldron":
				# Rounded leather cap, laced at the edge.
				_fill(img, x + 1, y, 3, 1, tone, 0.8)
				_fill(img, x, y + 1, 4, 2, tone, 0.8)
				_rect(img, x, y + 2, 4, 1, _shadow(tone, 0.25))
				_px(img, x + 2, y + 1, trim)
			"plate":
				# Layered iron lames with a bright rolled edge and a rivet.
				_rect(img, x, y, 4, 1, _light(tone, 0.25))
				_fill(img, x, y + 1, 4, 2, tone, 0.9)
				_rect(img, x, y + 2, 4, 1, _shadow(tone, 0.25))
				_fill(img, x, y + 3, 4, 1, _shadow(tone, 0.1), 0.9)
				_px(img, x + 2, y + 1, _light(tone, 0.4))
			"spiked":
				_fill(img, x, y, 4, 3, tone, 0.9)
				_rect(img, x, y + 2, 4, 1, _shadow(tone, 0.3))
				_px(img, x + 1, y - 1, _shadow(trim, 0.2) if back else trim)  # spikes
				_px(img, x + 3, y - 1, _shadow(trim, 0.2) if back else trim)
				_px(img, x + 1, y - 2, _light(trim, 0.2))
			_:
				_rect(img, x, y, 4, 3, tone)


## Helmets sit over the hair (head top is row `3 + bob`, face x 6–10, nose at 11).
static func _draw_helmet(img: Image, item: Dictionary, bob: int) -> void:
	if item.is_empty():
		return
	var main: Color = _col(item, "main")
	var trim: Color = _col(item, "trim")
	var y: int = 3 + bob
	match str(item.get("style", "")):
		"cap":
			# Close-fitting leather skullcap with a stitched band and a chin strap.
			_fill(img, 6, y - 2, 5, 1, main, 0.7)
			_fill(img, 5, y - 1, 6, 1, main, 0.7)
			_rect(img, 5, y, 6, 1, _shadow(main, 0.25))
			_px(img, 8, y - 1, trim)                                   # seam
			_px(img, 7, y - 2, _light(main, 0.12))
			_rect(img, 6, y + 1, 1, 4, _shadow(trim, 0.1))             # strap down the cheek
		"helm":
			# Rounded iron dome, rolled brow band, back neck guard and a nasal bar.
			_rect(img, 6, y - 3, 4, 1, _light(main, 0.2))
			_fill(img, 5, y - 2, 6, 2, main, 0.8)
			_rect(img, 5, y, 7, 1, _shadow(trim, 0.05))                # brow band
			_fill(img, 5, y + 1, 1, 3, _shadow(main, 0.25), 0.8)       # neck guard
			_rect(img, 10, y + 1, 1, 2, main)                          # nasal
			_px(img, 7, y - 2, _light(main, 0.35))                     # dull shine
			_px(img, 9, y - 1, _shadow(main, 0.3))                     # dent
		"cowl":
			# Deep hood: covers the crown and back of the head, shades the brow,
			# and drapes onto the shoulders.
			_fill(img, 6, y - 2, 5, 1, main, 0.8)
			_fill(img, 4, y - 1, 7, 2, main, 0.8)
			_fill(img, 4, y + 1, 2, 5, _shadow(main, 0.15), 0.8)
			_rect(img, 7, y + 1, 4, 1, _shadow(main, 0.45))            # shadow over the eyes
			_rect(img, 11, y - 1, 1, 3, _shadow(trim, 0.1))            # hood lip
			_fill(img, 4, y + 6, 6, 1, _shadow(main, 0.1), 0.8)        # drape at the neck
			_px(img, 5, y - 1, _light(main, 0.1))


## Extra detail over one boot (`boot_y` = boot top row). The far leg sits in shade.
static func _draw_boot_gear(img: Image, item: Dictionary, x: int, boot_y: int, far: bool) -> void:
	var main: Color = _col(item, "main")
	var trim: Color = _col(item, "trim")
	if far:
		main = _shadow(main, 0.2)
		trim = _shadow(trim, 0.2)
	match str(item.get("style", "")):
		"boots":
			# Tall road boots: the shaft climbs two rows up the shin, with a turned cuff.
			_rect(img, x, boot_y - 2, 3, 2, main)
			_rect(img, x, boot_y - 2, 3, 1, _light(main, 0.2))
			_px(img, x + 1, boot_y, trim)                              # buckle
		"greaves":
			# Iron plates strapped over the shin.
			_rect(img, x, boot_y - 3, 3, 3, trim)
			_rect(img, x + 2, boot_y - 3, 1, 3, _light(trim, 0.2))
			_rect(img, x, boot_y - 2, 3, 1, _shadow(trim, 0.3))        # strap
		"spurred":
			_px(img, x - 1, boot_y + 1, trim)                          # spur behind the heel
			_px(img, x + 1, boot_y + 1, trim)                          # buckle


static func _draw_trinket(img: Image, trinket: Dictionary, bob: int) -> void:
	match str(trinket.get("style", "")):
		"necklace":
			_rect(img, 7, 10 + bob, 3, 1, _shadow(_col(trinket, "main"), 0.4))
			_px(img, 8, 11 + bob, _col(trinket, "main"))
		"flask":
			_px(img, 10, 15 + bob, _col(trinket, "trim"))
			_rect(img, 9, 16 + bob, 2, 2, _col(trinket, "main"))
			_px(img, 9, 17 + bob, _shadow(_col(trinket, "main")))
		"coin":
			_px(img, 6, 17 + bob, _col(trinket, "main"))


## A held item gripped at `hand`, angled `deg` clockwise from straight up.
## Angled items are drawn upright into a scratch image and rotated about the
## grip (nearest-neighbour, so they stay pixel art).
static func _draw_held(img: Image, item: Dictionary, hand: Vector2i, look: Dictionary, back: bool,
		deg: float) -> void:
	if item.is_empty():
		return
	var style: String = str(item.get("style", ""))
	if is_zero_approx(deg) or back or style == "buckler" or style == "shield":
		if not _draw_item(img, item, hand, back):
			_draw_hand(img, look, hand, back)
		return
	var scratch := Image.create(_SCRATCH, _SCRATCH, false, Image.FORMAT_RGBA8)
	scratch.fill(Color(0, 0, 0, 0))
	var saved: int = _ox
	_ox = 0
	var grip := Vector2i(_SCRATCH / 2 - 1, _SCRATCH / 2)
	_draw_item(scratch, item, grip, back)
	_ox = saved
	_blit_rotated(img, scratch, grip + Vector2i(1, 0), hand + Vector2i(1, 0), deg)
	_draw_hand(img, look, hand, back)                          # grip over the handle



## Copies `src`'s opaque pixels into `img`, rotated `deg` clockwise about
## `pivot_src` and landing on `pivot_dst` (body-column coordinates).
static func _blit_rotated(img: Image, src: Image, pivot_src: Vector2i, pivot_dst: Vector2i, deg: float) -> void:
	var a: float = deg_to_rad(deg)
	var c: float = cos(a)
	var s: float = sin(a)
	var r: int = _SCRATCH / 2
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var sx: int = pivot_src.x + roundi(dx * c + dy * s)
			var sy: int = pivot_src.y + roundi(-dx * s + dy * c)
			if sx < 0 or sy < 0 or sx >= src.get_width() or sy >= src.get_height():
				continue
			var col: Color = src.get_pixel(sx, sy)
			if col.a > 0.0:
				_px(img, pivot_dst.x + dx, pivot_dst.y + dy, col)


## Draws an item upright at `hand` (no hand). Returns true when it covers the
## hand (shields), so the caller skips drawing the grip.
static func _draw_item(img: Image, item: Dictionary, hand: Vector2i, back: bool) -> bool:
	var main: Color = _col(item, "main")
	var trim: Color = item.get("trim", _shadow(main))
	if back:
		main = _shadow(main, 0.2)
		trim = _shadow(trim, 0.2)
	# Items are held just outside the hand: forward of the front hand, behind the back one.
	var hx: int = hand.x - 1 if back else hand.x + 2
	var hy: int = hand.y
	match str(item.get("style", "")):
		"dagger":
			_rect(img, hx, hy - 4, 1, 4, main)
			_px(img, hx, hy - 4, _light(main, 0.3))              # edge glint
			_rect(img, hx - 1, hy - 1, 3, 1, trim)
			_px(img, hx, hy, trim)
		"sword":
			_rect(img, hx, hy - 9, 1, 8, main)
			_px(img, hx, hy - 9, _light(main, 0.35))
			_px(img, hx, hy - 5, _shadow(main, 0.2))             # nick in the blade
			_rect(img, hx - 1, hy - 1, 3, 1, trim)
			_px(img, hx, hy + 1, trim)
		"axe":
			_rect(img, hx, hy - 8, 1, 10, trim)
			_fill(img, hx + 1, hy - 9, 2, 5, main, 0.9)
			_rect(img, hx + 2, hy - 9, 1, 5, _light(main, 0.25))  # honed edge
			_px(img, hx + 1, hy - 5, _shadow(main, 0.3))
			_px(img, hx - 1, hy - 7, _shadow(main, 0.3))
		"staff":
			_rect(img, hx, hy - 14, 1, 23, main)
			_px(img, hx, hy - 6, _shadow(main, 0.3))              # binding
			_rect(img, hx - 1, hy - 17, 3, 3, _shadow(trim, 0.3))
			_px(img, hx, hy - 16, trim)
			_px(img, hx, hy - 17, _light(trim, 0.3))
		"wand":
			_rect(img, hx, hy - 4, 1, 4, main)
			_px(img, hx, hy - 5, trim)
			_px(img, hx + 1, hy - 6, _shadow(trim, 0.2))
		"crystal":
			_rect(img, hx - 1, hy - 5, 3, 3, _shadow(main, 0.2))
			_px(img, hx, hy - 6, main)
			_px(img, hx, hy - 4, trim)
		"orb":
			_rect(img, hx - 1, hy - 3, 2, 2, main)
			_px(img, hx - 1, hy - 3, trim)
		"buckler", "shield":
			var sx: int = hand.x - 1 if back else hand.x
			var size: int = 4 if str(item.get("style", "")) == "buckler" else 5
			_fill(img, sx, hy - size + 1, size, size, main, 0.9)
			_rect(img, sx, hy - size + 1, size, 1, trim)          # rim
			_rect(img, sx, hy - size + 1, 1, size, _shadow(trim, 0.1))
			_rect(img, sx, hy, size, 1, _shadow(main, 0.35))
			_px(img, sx + size / 2, hy - size / 2, _light(trim, 0.25))  # boss
			return true
	return false
