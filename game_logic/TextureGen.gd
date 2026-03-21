class_name TextureGen

# Generates runtime ImageTexture objects using Godot's Image API.
# Mirrors the logic in TextureGenerator.java but produces square textures
# for 3D PlaneMesh/BoxMesh surfaces instead of isometric diamond sprites.

# Texture cache — deterministic seeds mean identical output, generate once.
static var _cache: Dictionary = {}

static func _cached(key: String, generator: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = generator.call()
	_cache[key] = tex
	return tex

static func grass(seed: int = 0) -> ImageTexture:
	return _cached("grass_%d" % seed, func() -> ImageTexture: return _gen_grass(seed))

static func hill_top(seed: int = 99999) -> ImageTexture:
	return _cached("hill_%d" % seed, func() -> ImageTexture: return _gen_hill_top(seed))

static func wall_side(is_left: bool) -> ImageTexture:
	var key: String = "wall_side_%s" % str(is_left)
	return _cached(key, func() -> ImageTexture: return _gen_wall_side(is_left))

static func wall_top() -> ImageTexture:
	return _cached("wall_top", func() -> ImageTexture: return _gen_wall_top())

static func _gen_grass(seed: int = 0) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in range(64):
		for x in range(64):
			if rng.randf() < 0.98:
				var v := rng.randi_range(-6, 6)
				img.set_pixel(x, y, Color8(clamp(135 + v, 0, 255), clamp(177 + v, 0, 255), clamp(87 + v, 0, 255), 255))
			else:
				var v := rng.randi_range(-5, 5)
				img.set_pixel(x, y, Color8(clamp(110 + v, 0, 255), clamp(100 + v, 0, 255), clamp(75 + v, 0, 255), 255))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _gen_hill_top(seed: int = 99999) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in range(64):
		for x in range(64):
			# Dirt rim around edges, grass interior
			var dist_from_edge: float = min(min(x, 63 - x), min(y, 63 - y)) / 12.0
			if dist_from_edge < 0.5:
				var t: float = dist_from_edge / 0.5
				var v := rng.randi_range(-6, 6)
				var r := int(lerp(120.0, 105.0, t)) + v
				var g := int(lerp(90.0, 158.0, t)) + v
				var b := int(lerp(50.0, 65.0, t)) + v
				img.set_pixel(x, y, Color8(clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255), 255))
			else:
				if rng.randf() < 0.96:
					var v := rng.randi_range(-7, 7)
					img.set_pixel(x, y, Color8(clamp(105 + v, 0, 255), clamp(158 + v, 0, 255), clamp(65 + v, 0, 255), 255))
				else:
					var v := rng.randi_range(-5, 5)
					img.set_pixel(x, y, Color8(clamp(95 + v, 0, 255), clamp(80 + v, 0, 255), clamp(50 + v, 0, 255), 255))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _gen_wall_side(is_left: bool) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111 if is_left else 22222
	# Brick colors — left face slightly brighter (lit side)
	var brick_cols: Array[Color] = []
	if is_left:
		brick_cols = [Color8(90, 53, 21, 255), Color8(107, 63, 29, 255), Color8(123, 73, 37, 255), Color8(79, 51, 25, 255), Color8(96, 64, 32, 255)]
	else:
		brick_cols = [Color8(74, 37, 17, 255), Color8(90, 53, 21, 255), Color8(107, 63, 29, 255), Color8(61, 40, 23, 255), Color8(79, 51, 25, 255)]
	for y in range(64):
		for x in range(64):
			var brick_row := (y + 4) / 8
			var brick_col := (x + (brick_row % 2) * 8) / 16
			if y % 8 < 1 or x % 16 < 1:
				img.set_pixel(x, y, Color8(26, 26, 26, 255))
			else:
				var c := brick_cols[(brick_row * 3 + brick_col) % brick_cols.size()]
				var v := rng.randi_range(-10, 10)
				img.set_pixel(x, y, Color8(clamp(c.r8 + v, 0, 255), clamp(c.g8 + v, 0, 255), clamp(c.b8 + v, 0, 255), 255))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _gen_wall_top() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var brick_cols: Array[Color] = [
		Color8(139, 69, 19, 255), Color8(160, 82, 45, 255), Color8(205, 133, 63, 255),
		Color8(210, 105, 30, 255), Color8(139, 105, 20, 255)
	]
	for y in range(64):
		for x in range(64):
			var brick_row := (y + 4) / 8
			var brick_col := (x + (brick_row % 2) * 8) / 16
			if y % 8 < 1 or x % 16 < 1:
				img.set_pixel(x, y, Color8(61, 61, 61, 255))
			else:
				var c := brick_cols[(brick_row * 3 + brick_col) % brick_cols.size()]
				var v := rng.randi_range(-10, 10)
				img.set_pixel(x, y, Color8(clamp(c.r8 + v, 0, 255), clamp(c.g8 + v, 0, 255), clamp(c.b8 + v, 0, 255), 255))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
