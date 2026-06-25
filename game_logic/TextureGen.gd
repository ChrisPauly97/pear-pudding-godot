class_name TextureGen

# Generates runtime textures synchronously so they are ready the first frame.

static var _cache: Dictionary = {}

## Lookup-or-generate helper — eliminates the repeated cache pattern.
static func _cached(key: String, generator: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = generator.call()
	_cache[key] = tex
	return tex

static func path(seed: int = 77777) -> ImageTexture:
	return _cached("path_%d" % seed, _make_path_tex.bind(seed))

static func mount_horse() -> ImageTexture:
	return _cached("mount_horse", _gen_mount_horse)

# ── Shared helper: noise + gradient → ImageTexture (synchronous) ─────────

static func _noise_to_texture(noise: FastNoiseLite, grad: Gradient, size: int) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(size * size * 4)
	for y in range(size):
		for x in range(size):
			var v: float = (noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var col: Color = grad.sample(v)
			var off: int = (y * size + x) * 4
			data[off]     = int(col.r * 255.0)
			data[off + 1] = int(col.g * 255.0)
			data[off + 2] = int(col.b * 255.0)
			data[off + 3] = 255
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ── Path: brown packed-earth for town road tiles ─────────────────────────

static func _make_path_tex(seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed
	noise.frequency = 0.18

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color8(105, 80,  45, 255),   # dark packed earth
		Color8(130, 100, 58, 255),   # mid earth
		Color8(148, 118, 68, 255),   # light earth / gravel
		Color8(160, 130, 78, 255),   # pale sandy path
	])
	return _noise_to_texture(noise, grad, 64)

# ── Mount horse: simple 48×24 brown silhouette ───────────────────────────

static func _gen_mount_horse() -> ImageTexture:
	const W: int = 48
	const H: int = 24
	const BR: int = 139; const BG: int = 90;  const BB: int = 43   # saddle brown body
	const MR: int = 80;  const MG: int = 45;  const MB: int = 20   # dark mane/tail
	const LR: int = 100; const LG: int = 60;  const LB: int = 25   # darker legs

	var hdata := PackedByteArray()
	hdata.resize(W * H * 4)

	for y in range(H):
		for x in range(W):
			var off: int = (y * W + x) * 4
			var in_body: bool = (y >= 2  and y <= 17 and x >= 4  and x <= 43)
			var in_head: bool = (y >= 2  and y <= 12 and x >= 36 and x <= 47)
			var in_mane: bool = (y >= 2  and y <= 8  and x >= 30 and x <= 37)
			var in_leg1: bool = (y >= 17 and y <= 23 and x >= 6  and x <= 11)
			var in_leg2: bool = (y >= 17 and y <= 23 and x >= 14 and x <= 19)
			var in_leg3: bool = (y >= 17 and y <= 23 and x >= 28 and x <= 33)
			var in_leg4: bool = (y >= 17 and y <= 23 and x >= 36 and x <= 41)
			var in_tail: bool = (y >= 4  and y <= 14 and x >= 0  and x <= 5)
			if in_mane or in_tail:
				hdata[off] = MR; hdata[off+1] = MG; hdata[off+2] = MB; hdata[off+3] = 255
			elif in_leg1 or in_leg2 or in_leg3 or in_leg4:
				hdata[off] = LR; hdata[off+1] = LG; hdata[off+2] = LB; hdata[off+3] = 255
			elif in_head or in_body:
				hdata[off] = BR; hdata[off+1] = BG; hdata[off+2] = BB; hdata[off+3] = 255
			else:
				hdata[off] = 0; hdata[off+1] = 0; hdata[off+2] = 0; hdata[off+3] = 0

	var himg := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, hdata)
	return ImageTexture.create_from_image(himg)

# ── Humanoid characters: 16×32 pixel-art silhouettes ─────────────────────────

static func enemy(is_roaming_boss: bool = false, is_boss: bool = false) -> ImageTexture:
	if is_roaming_boss:
		return _cached("enemy_rb",   _gen_humanoid.bind(100,5,5,   178,13,13,  110,8,8))
	if is_boss:
		return _cached("enemy_boss", _gen_humanoid.bind(150,100,5,  218,166,13, 140,90,5))
	return     _cached("enemy",      _gen_humanoid.bind(120,15,15,  180,30,30,  110,10,10))

static func npc_townsperson() -> ImageTexture:
	return _cached("npc_town",    _gen_humanoid.bind(230,191,153, 51,115,179, 30,70,110))

# ── Environmental props: 16×16 pixel-art silhouettes ─────────────────────────

static func prop(key: String) -> ImageTexture:
	return _cached("prop_" + key, _gen_prop.bind(key))

static func _gen_prop(key: String) -> ImageTexture:
	match key:
		"rock":     return _gen_prop_rock()
		"flower":   return _gen_prop_flower()
		"mushroom": return _gen_prop_mushroom()
		"fern":     return _gen_prop_fern()
		"cactus":   return _gen_prop_cactus()
		"thorn":    return _gen_prop_thorn()
		"ash_pile": return _gen_prop_ash()
		"ember":    return _gen_prop_ember()
		"boulder":  return _gen_prop_boulder()
		"lichen":   return _gen_prop_lichen()
	return _gen_prop_rock()

static func _prop_img(pixels: PackedByteArray) -> ImageTexture:
	var img := Image.create_from_data(16, 16, false, Image.FORMAT_RGBA8, pixels)
	return ImageTexture.create_from_image(img)

static func _prop_px(data: PackedByteArray, x: int, y: int,
		r: int, g: int, b: int, a: int = 255) -> void:
	var off: int = (y * 16 + x) * 4
	data[off] = r; data[off+1] = g; data[off+2] = b; data[off+3] = a

static func _make_prop_data() -> PackedByteArray:
	var d := PackedByteArray(); d.resize(16 * 16 * 4); d.fill(0); return d

static func _gen_prop_rock() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(9, 14):
		for x in range(4, 13):
			if (y - 11) * (y - 11) * 4 + (x - 8) * (x - 8) < 30:
				_prop_px(d, x, y, 155, 150, 145)
	for y in range(10, 13):
		for x in range(5, 12):
			if (y - 11) * (y - 11) * 4 + (x - 8) * (x - 8) < 18:
				_prop_px(d, x, y, 195, 188, 180)
	return _prop_img(d)

static func _gen_prop_flower() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(9, 15):
		_prop_px(d, 8, y, 55, 140, 45)
	for dx in [-2, -1, 0, 1, 2]:
		for dy in [-2, -1, 0, 1, 2]:
			if dx*dx + dy*dy <= 3:
				_prop_px(d, 8+dx, 7+dy, 235, 200, 40)
	_prop_px(d, 8, 7, 240, 240, 230)
	return _prop_img(d)

static func _gen_prop_mushroom() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(10, 15):
		_prop_px(d, 8, y, 220, 210, 200)
	for y in range(7, 11):
		for x in range(4, 13):
			if (y - 10) * (y - 10) * 2 + (x - 8) * (x - 8) < 22:
				_prop_px(d, x, y, 180, 60, 40)
	for x in range(5, 12):
		if (x - 8) * (x - 8) < 12:
			_prop_px(d, x, 10, 235, 230, 220)
	return _prop_img(d)

static func _gen_prop_fern() -> ImageTexture:
	var d := _make_prop_data()
	for i in range(5):
		_prop_px(d, 8, 10 + i, 50, 130, 40)
	for sx in [-1, 1]:
		for i in range(4):
			_prop_px(d, 8 + sx * (i+1), 9 - i / 2, 60, 160, 50)
			_prop_px(d, 8 + sx * (i+1), 10 - i / 2, 45, 140, 35)
	return _prop_img(d)

static func _gen_prop_cactus() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(5, 15):
		_prop_px(d, 8, y, 55, 140, 55)
		_prop_px(d, 7, y, 45, 120, 45)
		_prop_px(d, 9, y, 45, 120, 45)
	for x in range(5, 8):
		_prop_px(d, x, 9, 55, 140, 55)
		_prop_px(d, x, 10, 45, 120, 45)
	for x in range(9, 12):
		_prop_px(d, x, 11, 55, 140, 55)
		_prop_px(d, x, 12, 45, 120, 45)
	return _prop_img(d)

static func _gen_prop_thorn() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(10, 15):
		for x in range(3, 13):
			if (y-12)*(y-12) + (x-8)*(x-8) < 18:
				_prop_px(d, x, y, 90, 65, 35)
	for sx in [-3, -2, -1, 1, 2, 3]:
		_prop_px(d, 8+sx, 10 + sx * sx / 3, 110, 80, 40)
	return _prop_img(d)

static func _gen_prop_ash() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(11, 15):
		for x in range(4, 13):
			if (y-14)*(y-14)*3 + (x-8)*(x-8) < 22:
				_prop_px(d, x, y, 80, 75, 72)
	for y in range(11, 14):
		for x in range(5, 12):
			if (y-14)*(y-14)*3 + (x-8)*(x-8) < 14:
				_prop_px(d, x, y, 110, 105, 100)
	return _prop_img(d)

static func _gen_prop_ember() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(10, 14):
		for x in range(5, 12):
			if (y-12)*(y-12)*3 + (x-8)*(x-8) < 16:
				_prop_px(d, x, y, 160, 50, 10)
	for y in range(11, 13):
		for x in range(6, 11):
			if (y-12)*(y-12)*3 + (x-8)*(x-8) < 8:
				_prop_px(d, x, y, 240, 160, 20)
	return _prop_img(d)

static func _gen_prop_boulder() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(7, 15):
		for x in range(3, 13):
			if (y-11)*(y-11)*2 + (x-8)*(x-8) < 36:
				_prop_px(d, x, y, 110, 108, 115)
	for y in range(8, 13):
		for x in range(4, 12):
			if (y-11)*(y-11)*2 + (x-8)*(x-8) < 22:
				_prop_px(d, x, y, 145, 142, 150)
	_prop_px(d, 6, 9, 175, 172, 180)
	_prop_px(d, 7, 9, 175, 172, 180)
	return _prop_img(d)

static func _gen_prop_lichen() -> ImageTexture:
	var d := _make_prop_data()
	for y in range(11, 15):
		for x in range(3, 14):
			if (y-13)*(y-13)*4 + (x-8)*(x-8) < 28:
				_prop_px(d, x, y, 130, 145, 110)
	for y in range(12, 15):
		for x in range(5, 12):
			if (y-14)*(y-14)*4 + (x-8)*(x-8) < 18:
				_prop_px(d, x, y, 160, 175, 135)
	return _prop_img(d)

# ── Card illustrations: 32×32 pixel-art per archetype ────────────────────────

static func card_illustration(card_id: String, magic_branch: String = "") -> ImageTexture:
	var key: String = "card_illus_" + card_id + "_" + magic_branch
	return _cached(key, _gen_card_illustration.bind(card_id, magic_branch))

static func _gen_card_illustration(card_id: String, magic_branch: String) -> ImageTexture:
	match card_id:
		"ghost":    return _gen_card_ghost()
		"skeleton": return _gen_card_skeleton()
		"zombie":   return _gen_card_zombie()
		"ghoul":    return _gen_card_ghoul()
		_:          return _gen_card_spell_rune(magic_branch)

static func _card_img(data: PackedByteArray) -> ImageTexture:
	var img := Image.create_from_data(32, 32, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(img)

static func _card_px(data: PackedByteArray, x: int, y: int,
		r: int, g: int, b: int, a: int = 255) -> void:
	if x < 0 or x >= 32 or y < 0 or y >= 32:
		return
	var off: int = (y * 32 + x) * 4
	data[off] = r; data[off+1] = g; data[off+2] = b; data[off+3] = a

static func _make_card_data() -> PackedByteArray:
	var d := PackedByteArray(); d.resize(32 * 32 * 4); d.fill(0); return d

static func _gen_card_ghost() -> ImageTexture:
	var d := _make_card_data()
	# Wispy oval body: pale blue-white
	for y in range(6, 24):
		for x in range(8, 24):
			var dx: float = float(x - 16) / 7.0
			var dy: float = float(y - 15) / 9.0
			if dx*dx + dy*dy < 1.0:
				var alpha: int = int((1.0 - (dx*dx + dy*dy)) * 200.0)
				_card_px(d, x, y, 200, 215, 255, alpha)
	# Eyes: dark circles
	_card_px(d, 13, 12, 40, 40, 80)
	_card_px(d, 14, 12, 40, 40, 80)
	_card_px(d, 18, 12, 40, 40, 80)
	_card_px(d, 19, 12, 40, 40, 80)
	# Wispy tail at bottom
	for y in range(22, 28):
		for x in range(11, 22):
			var dx2: float = float(x - 16) / 5.0
			var dy2: float = float(y - 22) / 4.0
			if dx2*dx2 + dy2*dy2 < 1.0 and (x + y) % 2 == 0:
				_card_px(d, x, y, 180, 200, 245, 120)
	return _card_img(d)

static func _gen_card_skeleton() -> ImageTexture:
	var d := _make_card_data()
	# Skull
	for y in range(3, 11):
		for x in range(11, 21):
			if (y-7)*(y-7)*2 + (x-16)*(x-16) < 36:
				_card_px(d, x, y, 235, 230, 215)
	# Eye sockets
	_card_px(d, 13, 6, 20, 20, 20)
	_card_px(d, 14, 6, 20, 20, 20)
	_card_px(d, 18, 6, 20, 20, 20)
	_card_px(d, 19, 6, 20, 20, 20)
	# Ribcage body
	for y in range(11, 22):
		for x in range(13, 19):
			if x == 13 or x == 18 or (y % 3 == 0):
				_card_px(d, x, y, 220, 215, 200)
	# Arm bones
	for y in range(12, 20):
		_card_px(d, 9, y, 215, 210, 195)
		_card_px(d, 22, y, 215, 210, 195)
	# Leg bones
	for y in range(22, 30):
		_card_px(d, 13, y, 215, 210, 195)
		_card_px(d, 18, y, 215, 210, 195)
	return _card_img(d)

static func _gen_card_zombie() -> ImageTexture:
	var d := _make_card_data()
	# Head: greenish flesh
	for y in range(4, 12):
		for x in range(12, 21):
			if (y-8)*(y-8)*2 + (x-16)*(x-16) < 28:
				_card_px(d, x, y, 120, 160, 90)
	# Eyes: bloodshot red
	_card_px(d, 14, 7, 180, 40, 30)
	_card_px(d, 18, 7, 180, 40, 30)
	# Ragged body
	for y in range(12, 24):
		for x in range(11, 22):
			if x == 11 or x == 21 or y == 12:
				_card_px(d, x, y, 80, 110, 55)
			elif (x + y) % 5 != 0:
				_card_px(d, x, y, 100, 138, 72)
	# Arms (outstretched)
	for y in range(14, 18):
		for x in range(7, 11):
			_card_px(d, x, y, 110, 148, 80)
		for x in range(22, 26):
			_card_px(d, x, y, 110, 148, 80)
	# Legs
	for y in range(24, 31):
		_card_px(d, 13, y, 80, 110, 55)
		_card_px(d, 14, y, 80, 110, 55)
		_card_px(d, 18, y, 80, 110, 55)
		_card_px(d, 19, y, 80, 110, 55)
	return _card_img(d)

static func _gen_card_ghoul() -> ImageTexture:
	var d := _make_card_data()
	# Hunched dark body
	for y in range(8, 26):
		for x in range(9, 23):
			var dy: float = float(y - 17) / 9.0
			var dx2: float = float(x - 16) / 7.0
			if dx2*dx2 + dy*dy < 1.0:
				_card_px(d, x, y, 55, 30, 75)
	# Clawed hands
	for i in range(3):
		_card_px(d, 8+i, 18, 80, 45, 100)
		_card_px(d, 24-i, 18, 80, 45, 100)
	# Red eyes: glowing
	_card_px(d, 13, 13, 220, 30, 30)
	_card_px(d, 14, 13, 255, 50, 50)
	_card_px(d, 18, 13, 220, 30, 30)
	_card_px(d, 19, 13, 255, 50, 50)
	# Mouth: fangs
	for x in range(14, 19):
		_card_px(d, x, 17, 30, 12, 45)
	_card_px(d, 14, 18, 230, 225, 220)
	_card_px(d, 17, 18, 230, 225, 220)
	return _card_img(d)

static func _gen_card_spell_rune(magic_branch: String) -> ImageTexture:
	var d := _make_card_data()
	var col: Color
	match magic_branch:
		"dawn":  col = Color(1.0, 0.9, 0.4)
		"dusk":  col = Color(0.55, 0.1, 0.9)
		"ember": col = Color(1.0, 0.35, 0.05)
		"ash":   col = Color(0.55, 0.55, 0.65)
		_:       col = Color(0.5, 0.8, 1.0)
	var r: int = int(col.r * 220); var g: int = int(col.g * 220); var b: int = int(col.b * 220)
	# Outer circle
	for y in range(32):
		for x in range(32):
			var dx3: float = float(x - 16); var dy3: float = float(y - 16)
			var dist: float = sqrt(dx3*dx3 + dy3*dy3)
			if dist >= 12.0 and dist < 14.0:
				_card_px(d, x, y, r, g, b)
	# Inner rune cross
	for i in range(-6, 7):
		_card_px(d, 16+i, 16, r, g, b)
		_card_px(d, 16, 16+i, r, g, b)
	# Diagonal arms
	for i in range(-4, 5):
		_card_px(d, 16+i, 16+i, r, g, b)
		_card_px(d, 16+i, 16-i, r, g, b)
	# Center dot
	for dy3 in range(-2, 3):
		for dx3 in range(-2, 3):
			if dx3*dx3 + dy3*dy3 <= 4:
				_card_px(d, 16+dx3, 16+dy3, r, g, b)
	return _card_img(d)

static func npc_merchant(is_traveling: bool = false) -> ImageTexture:
	if is_traveling:
		return _cached("npc_merch_t", _gen_humanoid.bind(230,191,153, 115,38,166, 75,20,110))
	return     _cached("npc_merch",   _gen_humanoid.bind(230,191,153, 191,158,26, 140,100,10))

static func _gen_humanoid(hr: int, hg: int, hb: int,
		br: int, bg: int, bb: int,
		lr: int, lg: int, lb: int) -> ImageTexture:
	const W: int = 16
	const H: int = 32
	var data := PackedByteArray()
	data.resize(W * H * 4)
	for y in range(H):
		for x in range(W):
			var off: int = (y * W + x) * 4
			var in_head: bool = y >= 1  and y <= 6  and x >= 5 and x <= 10
			var in_body: bool = y >= 7  and y <= 18 and x >= 3 and x <= 12
			var in_larm: bool = y >= 7  and y <= 16 and x >= 0 and x <= 2
			var in_rarm: bool = y >= 7  and y <= 16 and x >= 13 and x <= 15
			var in_lleg: bool = y >= 19 and y <= 31 and x >= 3 and x <= 7
			var in_rleg: bool = y >= 19 and y <= 31 and x >= 8 and x <= 12
			if in_head:
				data[off]=hr; data[off+1]=hg; data[off+2]=hb; data[off+3]=255
			elif in_body:
				data[off]=br; data[off+1]=bg; data[off+2]=bb; data[off+3]=255
			elif in_larm or in_rarm or in_lleg or in_rleg:
				data[off]=lr; data[off+1]=lg; data[off+2]=lb; data[off+3]=255
			else:
				data[off]=0; data[off+1]=0; data[off+2]=0; data[off+3]=0
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(img)
