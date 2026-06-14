class_name TextureGen

# Generates runtime textures synchronously so they are ready the first frame.
# Terrain textures: FastNoiseLite.get_noise_2d() per pixel + gradient → ImageTexture.
# Wall brick patterns: bulk PackedByteArray writes (no per-pixel GDScript calls).

static var _cache: Dictionary = {}

## Lookup-or-generate helper — eliminates the repeated cache pattern.
static func _cached(key: String, generator: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = generator.call()
	_cache[key] = tex
	return tex

static func grass(seed: int = 0) -> ImageTexture:
	return _cached("grass_%d" % seed, _make_grass_tex.bind(seed))

static func hill_top(seed: int = 99999) -> ImageTexture:
	return _cached("hill_%d" % seed, _make_hill_tex.bind(seed))

static func hill_side(seed: int = 55555) -> ImageTexture:
	return _cached("hill_side_%d" % seed, _make_hill_side_tex.bind(seed))

static func path(seed: int = 77777) -> ImageTexture:
	return _cached("path_%d" % seed, _make_path_tex.bind(seed))

static func wall_side(is_left: bool) -> ImageTexture:
	return _cached("wall_side_%s" % str(is_left), _gen_wall_side.bind(is_left))

static func wall_top() -> ImageTexture:
	return _cached("wall_top", _gen_wall_top)

static func mount_horse() -> ImageTexture:
	return _cached("mount_horse", _gen_mount_horse)

# ── Shared helper: noise + gradient → ImageTexture (synchronous) ─────────
# Uses the same PackedByteArray + create_from_data pattern as the wall textures,
# which are confirmed to work. get_noise_2d() is available since Godot 4.0.

static func _noise_to_texture(noise: FastNoiseLite, grad: Gradient, size: int) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(size * size * 4)
	for y in range(size):
		for x in range(size):
			# get_noise_2d returns ~[-1, 1]; remap to [0, 1] for gradient
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

# ── Grass: cellular noise with green ramp ────────────────────────────────

static func _make_grass_tex(seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = seed
	noise.frequency = 0.15

	var grad := Gradient.new()
	# Dark grass -> base grass -> light grass, with occasional dirt speckles
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color8(110, 100, 75, 255),   # dirt speckle (rare, at noise extremes)
		Color8(129, 171, 81, 255),   # dark grass
		Color8(135, 177, 87, 255),   # base grass
		Color8(141, 183, 93, 255),   # light grass
	])
	return _noise_to_texture(noise, grad, 64)

# ── Hill top: simplex noise with brown-green ramp ─────────────────────────

static func _make_hill_tex(seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed
	noise.frequency = 0.12

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color8(95, 80, 50, 255),     # dirt
		Color8(120, 90, 50, 255),    # dark dirt-grass transition
		Color8(105, 158, 65, 255),   # hill grass
		Color8(111, 164, 71, 255),   # bright hill grass
	])
	return _noise_to_texture(noise, grad, 64)

# ── Hill side: earthy brown dirt for steep slopes ────────────────────────

static func _make_hill_side_tex(seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed
	noise.frequency = 0.09

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color8(68,  52, 28, 255),   # dark earth
		Color8(98,  76, 42, 255),   # earth
		Color8(118, 93, 52, 255),   # light earth
		Color8(130, 105, 62, 255),  # pale earth / exposed root
	])
	return _noise_to_texture(noise, grad, 64)

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

# ── Walls: bulk byte-array writes (no per-pixel GDScript calls) ──────────

static func _gen_wall_side(is_left: bool) -> ImageTexture:
	const SIZE: int = 64
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111 if is_left else 22222

	var brick_r: PackedInt32Array
	var brick_g: PackedInt32Array
	var brick_b: PackedInt32Array
	if is_left:
		brick_r = PackedInt32Array([90, 107, 123, 79, 96])
		brick_g = PackedInt32Array([53, 63, 73, 51, 64])
		brick_b = PackedInt32Array([21, 29, 37, 25, 32])
	else:
		brick_r = PackedInt32Array([74, 90, 107, 61, 79])
		brick_g = PackedInt32Array([37, 53, 63, 40, 51])
		brick_b = PackedInt32Array([17, 21, 29, 23, 25])

	var mortar_r: int = 26
	var mortar_g: int = 26
	var mortar_b: int = 26
	var num_cols: int = brick_r.size()

	for y in range(SIZE):
		for x in range(SIZE):
			var off: int = (y * SIZE + x) * 4
			var brick_row: int = (y + 4) / 8
			var brick_col: int = (x + (brick_row % 2) * 8) / 16
			if y % 8 < 1 or x % 16 < 1:
				data[off]     = mortar_r
				data[off + 1] = mortar_g
				data[off + 2] = mortar_b
				data[off + 3] = 255
			else:
				var ci: int = (brick_row * 3 + brick_col) % num_cols
				var v: int = rng.randi_range(-10, 10)
				data[off]     = clampi(brick_r[ci] + v, 0, 255)
				data[off + 1] = clampi(brick_g[ci] + v, 0, 255)
				data[off + 2] = clampi(brick_b[ci] + v, 0, 255)
				data[off + 3] = 255

	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _gen_wall_top() -> ImageTexture:
	const SIZE: int = 64
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var brick_r := PackedInt32Array([139, 160, 205, 210, 139])
	var brick_g := PackedInt32Array([69, 82, 133, 105, 105])
	var brick_b := PackedInt32Array([19, 45, 63, 30, 20])
	var num_cols: int = brick_r.size()

	for y in range(SIZE):
		for x in range(SIZE):
			var off: int = (y * SIZE + x) * 4
			var brick_row: int = (y + 4) / 8
			var brick_col: int = (x + (brick_row % 2) * 8) / 16
			if y % 8 < 1 or x % 16 < 1:
				data[off]     = 61
				data[off + 1] = 61
				data[off + 2] = 61
				data[off + 3] = 255
			else:
				var ci: int = (brick_row * 3 + brick_col) % num_cols
				var v: int = rng.randi_range(-10, 10)
				data[off]     = clampi(brick_r[ci] + v, 0, 255)
				data[off + 1] = clampi(brick_g[ci] + v, 0, 255)
				data[off + 2] = clampi(brick_b[ci] + v, 0, 255)
				data[off + 3] = 255

	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

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
