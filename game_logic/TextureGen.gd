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
