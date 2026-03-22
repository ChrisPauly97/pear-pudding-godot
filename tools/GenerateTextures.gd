@tool
extends EditorScript

# Run this once from: Script menu → Run Current Script
# It generates all terrain textures to res://assets/textures/ as PNG files.
# After running, replace TextureGen calls with preload() on those files.

const OUT_DIR := "res://assets/textures/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_make_grass(),      "grass.png")
	_save(_make_hill_top(),   "hill_top.png")
	_save(_make_hill_side(),  "hill_side.png")
	_save(_make_wall_side(true),  "wall_side_left.png")
	_save(_make_wall_side(false), "wall_side_right.png")
	_save(_make_wall_top(),   "wall_top.png")

	print("GenerateTextures: done — files written to ", OUT_DIR)

func _save(img: Image, filename: String) -> void:
	var path := OUT_DIR + filename
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("GenerateTextures: failed to save %s (error %d)" % [path, err])
	else:
		print("  saved ", path)

# ── Noise helper ─────────────────────────────────────────────────────────────

func _noise_to_image(noise: FastNoiseLite, grad: Gradient, size: int) -> Image:
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
	return img

# ── Grass ─────────────────────────────────────────────────────────────────────

func _make_grass() -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = 0
	noise.frequency = 0.15

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color8(110, 100, 75, 255),
		Color8(129, 171, 81, 255),
		Color8(135, 177, 87, 255),
		Color8(141, 183, 93, 255),
	])
	return _noise_to_image(noise, grad, 64)

# ── Hill top ──────────────────────────────────────────────────────────────────

func _make_hill_top() -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 99999
	noise.frequency = 0.12

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color8(95,  80,  50, 255),
		Color8(120, 90,  50, 255),
		Color8(105, 158, 65, 255),
		Color8(111, 164, 71, 255),
	])
	return _noise_to_image(noise, grad, 64)

# ── Hill side ─────────────────────────────────────────────────────────────────

func _make_hill_side() -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 55555
	noise.frequency = 0.09

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color8(68,  52, 28, 255),
		Color8(98,  76, 42, 255),
		Color8(118, 93, 52, 255),
		Color8(130, 105, 62, 255),
	])
	return _noise_to_image(noise, grad, 64)

# ── Wall side ─────────────────────────────────────────────────────────────────

func _make_wall_side(is_left: bool) -> Image:
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
		brick_g = PackedInt32Array([53, 63,  73, 51, 64])
		brick_b = PackedInt32Array([21, 29,  37, 25, 32])
	else:
		brick_r = PackedInt32Array([74, 90, 107, 61, 79])
		brick_g = PackedInt32Array([37, 53,  63, 40, 51])
		brick_b = PackedInt32Array([17, 21,  29, 23, 25])

	var num_cols: int = brick_r.size()
	for y in range(SIZE):
		for x in range(SIZE):
			var off: int = (y * SIZE + x) * 4
			var brick_row: int = (y + 4) / 8
			var brick_col: int = (x + (brick_row % 2) * 8) / 16
			if y % 8 < 1 or x % 16 < 1:
				data[off] = 26; data[off+1] = 26; data[off+2] = 26; data[off+3] = 255
			else:
				var ci: int = (brick_row * 3 + brick_col) % num_cols
				var v: int = rng.randi_range(-10, 10)
				data[off]   = clampi(brick_r[ci] + v, 0, 255)
				data[off+1] = clampi(brick_g[ci] + v, 0, 255)
				data[off+2] = clampi(brick_b[ci] + v, 0, 255)
				data[off+3] = 255

	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return img

# ── Wall top ──────────────────────────────────────────────────────────────────

func _make_wall_top() -> Image:
	const SIZE: int = 64
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var brick_r := PackedInt32Array([139, 160, 205, 210, 139])
	var brick_g := PackedInt32Array([69,  82,  133, 105, 105])
	var brick_b := PackedInt32Array([19,  45,  63,  30,  20])
	var num_cols: int = brick_r.size()

	for y in range(SIZE):
		for x in range(SIZE):
			var off: int = (y * SIZE + x) * 4
			var brick_row: int = (y + 4) / 8
			var brick_col: int = (x + (brick_row % 2) * 8) / 16
			if y % 8 < 1 or x % 16 < 1:
				data[off] = 61; data[off+1] = 61; data[off+2] = 61; data[off+3] = 255
			else:
				var ci: int = (brick_row * 3 + brick_col) % num_cols
				var v: int = rng.randi_range(-10, 10)
				data[off]   = clampi(brick_r[ci] + v, 0, 255)
				data[off+1] = clampi(brick_g[ci] + v, 0, 255)
				data[off+2] = clampi(brick_b[ci] + v, 0, 255)
				data[off+3] = 255

	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return img
