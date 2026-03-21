class_name TextureGen

# Generates runtime textures using Godot-native resources where possible.
# Grass/hill use NoiseTexture2D with color ramps (C++ pipeline, instant).
# Wall brick patterns use bulk PackedByteArray writes (no per-pixel calls).

static var _cache: Dictionary = {}

static func grass(seed: int = 0) -> NoiseTexture2D:
	var key: String = "grass_%d" % seed
	if _cache.has(key):
		return _cache[key]
	var tex: NoiseTexture2D = _make_grass_noise(seed)
	_cache[key] = tex
	return tex

static func hill_top(seed: int = 99999) -> NoiseTexture2D:
	var key: String = "hill_%d" % seed
	if _cache.has(key):
		return _cache[key]
	var tex: NoiseTexture2D = _make_hill_noise(seed)
	_cache[key] = tex
	return tex

static func hill_side(seed: int = 55555) -> NoiseTexture2D:
	var key: String = "hill_side_%d" % seed
	if _cache.has(key):
		return _cache[key]
	var tex: NoiseTexture2D = _make_hill_side_noise(seed)
	_cache[key] = tex
	return tex

static func wall_side(is_left: bool) -> ImageTexture:
	var key: String = "wall_side_%s" % str(is_left)
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = _gen_wall_side(is_left)
	_cache[key] = tex
	return tex

static func wall_top() -> ImageTexture:
	var key: String = "wall_top"
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = _gen_wall_top()
	_cache[key] = tex
	return tex

# ── Grass: NoiseTexture2D with green color ramp ──────────────────────────

static func _make_grass_noise(seed: int) -> NoiseTexture2D:
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

	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.width = 64
	tex.height = 64
	tex.generate_mipmaps = true
	tex.seamless = true
	return tex

# ── Hill: NoiseTexture2D with brown-green ramp ───────────────────────────

static func _make_hill_noise(seed: int) -> NoiseTexture2D:
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

	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.width = 64
	tex.height = 64
	tex.generate_mipmaps = true
	tex.seamless = true
	return tex

# ── Hill side: earthy brown dirt for steep slopes ────────────────────────

static func _make_hill_side_noise(seed: int) -> NoiseTexture2D:
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

	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.width = 64
	tex.height = 64
	tex.generate_mipmaps = true
	tex.seamless = true
	return tex

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
