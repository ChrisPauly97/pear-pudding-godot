## RealmMapArt — painted images for the realm map (RealmMapOverlay).
##
## `terrain_image()` paints the real overworld from the same generators the
## chunks use (biome, hills, streams / ponds, the eastern sea, tree groves,
## stamped roads), hill-shaded from the north-west, so the map shows what the
## player will actually walk through. `town_image()` draws one stitched town as
## an illustrated plan: roofed buildings with shadows, cobbled streets, paths,
## walls, its square's set piece and lamps.
##
## Pure (no autoloads, no scene tree). `Painter` charts it a chunk at a time so
## the realm map can paint on the main thread within a per-frame budget.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WaterMath = preload("res://game_logic/world/WaterMath.gd")
const _TreeScatter = preload("res://game_logic/world/TreeScatter.gd")
const _TownDecor = preload("res://game_logic/world/TownDecor.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")

## Tiles of wilderness shown around the realm's outline.
const MARGIN_TILES: float = 32.0

## Image pixels per overworld tile for the terrain.
const TERRAIN_PX: int = 2
## Tiles a biome border wanders either way of its chunk seam on the map.
const BORDER_JITTER: float = 9.0
## Image pixels per tile for a town plan.
const TOWN_PX: int = 8

## Map-paint ground colour per biome (BiomeDef order), richer than the in-game tint.
const BIOME_GROUND: Array[Color] = [
	Color(0.42, 0.56, 0.27),  # Grasslands
	Color(0.24, 0.42, 0.20),  # Forest
	Color(0.84, 0.72, 0.45),  # Desert
	Color(0.45, 0.32, 0.24),  # Scorched
	Color(0.70, 0.72, 0.74),  # Mountains
]
const BIOME_TREE: Array[Color] = [
	Color(0.18, 0.34, 0.14),
	Color(0.10, 0.24, 0.10),
	Color(0.45, 0.36, 0.22),
	Color(0.22, 0.15, 0.11),
	Color(0.20, 0.32, 0.26),
]
const COL_ROAD := Color(0.72, 0.60, 0.40)
const COL_WATER := Color(0.25, 0.47, 0.66)
const COL_DEEP := Color(0.13, 0.28, 0.47)
const COL_SHORE := Color(0.82, 0.76, 0.55)

const COL_TOWN_GROUND := Color(0.47, 0.55, 0.32)
const COL_STREET := Color(0.66, 0.62, 0.55)
const COL_PATH := Color(0.70, 0.58, 0.40)
const COL_WALL := Color(0.45, 0.42, 0.40)
const COL_OUTLINE := Color(0.16, 0.12, 0.10)
const ROOF_COLORS: Array[Color] = [
	Color(0.62, 0.27, 0.20), Color(0.55, 0.33, 0.22), Color(0.36, 0.38, 0.46),
	Color(0.66, 0.42, 0.24), Color(0.46, 0.24, 0.24),
]
const COL_DECOR := Color(0.80, 0.80, 0.86)
const COL_LAMP := Color(1.0, 0.85, 0.40)


## The overworld inside `bounds` (tiles), TERRAIN_PX pixels per tile.
## Tile rect covering every town and road, padded by MARGIN_TILES, grown to
## include `extra` tiles (the player, quest targets) and made square.
static func realm_bounds(extra: Array[Vector2] = []) -> Rect2:
	var r := Rect2()
	var first: bool = true
	for town: String in _RealmLayout.town_names():
		var wr: Rect2i = _RealmLayout.world_rect(town)
		var tr := Rect2(Vector2(wr.position), Vector2(wr.size))
		r = tr if first else r.merge(tr)
		first = false
	for road: Array in _RealmLayout.ROADS:
		for p: Vector2 in road:
			r = r.expand(p)
	for p: Vector2 in extra:
		r = r.expand(p)
	r = r.grow(MARGIN_TILES)
	var side: float = maxf(r.size.x, r.size.y)
	return Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


## The tile rect the terrain art covers (realm_bounds, whole tiles).
static func terrain_rect() -> Rect2i:
	var b: Rect2 = realm_bounds()
	return Rect2i(Vector2i(b.position.floor()), Vector2i(b.size.ceil()))


static func terrain_image(bounds: Rect2i, world_seed: int) -> Image:
	var p := Painter.new(bounds, world_seed, false)
	while not p.step(1 << 30):
		pass
	return p.terrain


## Paints the terrain (then, with `with_towns`, every town plan) a chunk at a time,
## so the realm map can be charted on the main thread a few ms per frame.
class Painter extends RefCounted:
	const _Art = preload("res://game_logic/world/RealmMapArt.gd")

	var terrain: Image
	var towns: Dictionary = {}  # town → Image
	var _bounds: Rect2i
	var _seed: int
	var _heights := PackedFloat32Array()
	var _edge := FastNoiseLite.new()
	var _chunk_biome: Dictionary = {}
	var _c0: Vector2i
	var _c1: Vector2i
	var _next: Vector2i
	var _town_queue: Array[String] = []

	func _init(bounds: Rect2i, world_seed: int, with_towns: bool = true) -> void:
		_bounds = bounds
		_seed = world_seed
		_heights.resize(bounds.size.x * bounds.size.y)
		terrain = Image.create(bounds.size.x * _Art.TERRAIN_PX, bounds.size.y * _Art.TERRAIN_PX, false,
			Image.FORMAT_RGB8)
		# Biomes are per chunk in-game (blended at the seams); paint them from a jittered
		# sample so the map shows soft, natural borders instead of a chunk staircase.
		_edge.seed = world_seed + 4111
		_edge.frequency = 0.06
		var cs: int = IsoConst.CHUNK_SIZE
		_c0 = Vector2i(floori(float(bounds.position.x) / cs), floori(float(bounds.position.y) / cs))
		_c1 = Vector2i(floori(float(bounds.end.x - 1) / cs), floori(float(bounds.end.y - 1) / cs))
		_next = _c0
		if with_towns:
			_town_queue = _RealmLayout.town_names()

	## Paints until `budget_usec` is spent; true once everything is painted.
	func step(budget_usec: int) -> bool:
		var start: int = Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < budget_usec:
			if _next.y <= _c1.y:
				_paint_chunk(_next.x, _next.y)
				_next.x += 1
				if _next.x > _c1.x:
					_next = Vector2i(_c0.x, _next.y + 1)
			elif not _town_queue.is_empty():
				var town: String = _town_queue.pop_front()
				towns[town] = _Art.town_image(town)
			else:
				return true
		return false

	# Row-major chunk order means a tile's north-west neighbour (hill shading)
	# is always painted already.
	func _paint_chunk(cx: int, cz: int) -> void:
		var cs: int = IsoConst.CHUNK_SIZE
		var w: int = _bounds.size.x
		var chunk: _ChunkData = _InfiniteWorldGen._gen_tile_data(cx, cz, _seed)
		var ts: float = IsoConst.TILE_SIZE
		for lz: int in range(cs):
			var iz: int = cz * cs + lz - _bounds.position.y
			if iz < 0 or iz >= _bounds.size.y:
				continue
			for lx: int in range(cs):
				var ix: int = cx * cs + lx - _bounds.position.x
				if ix < 0 or ix >= w:
					continue
				_heights[iz * w + ix] = float(chunk.get_height(lx, lz))
		for lz: int in range(cs):
			var iz: int = cz * cs + lz - _bounds.position.y
			if iz < 0 or iz >= _bounds.size.y:
				continue
			for lx: int in range(cs):
				var ix: int = cx * cs + lx - _bounds.position.x
				if ix < 0 or ix >= w:
					continue
				var tile: int = chunk.get_tile(lx, lz)
				var wtx: int = _bounds.position.x + ix
				var wtz: int = _bounds.position.y + iz
				var biome: int = chunk.biome_id
				if tile == IsoConst.TILE_GRASS or tile == IsoConst.TILE_HILL:
					biome = _jittered_biome(wtx, wtz)
				var col: Color = _Art._tile_color(tile, _heights, w, ix, iz, biome, wtx, wtz, _seed, ts)
				_Art._fill(terrain, ix * _Art.TERRAIN_PX, iz * _Art.TERRAIN_PX, _Art.TERRAIN_PX, col)

	func _jittered_biome(wtx: int, wtz: int) -> int:
		var cs: float = float(IsoConst.CHUNK_SIZE)
		var jx: float = float(wtx) + _edge.get_noise_2d(float(wtx), float(wtz)) * _Art.BORDER_JITTER
		var jz: float = float(wtz) + _edge.get_noise_2d(float(wtz) + 517.0, float(wtx)) * _Art.BORDER_JITTER
		var cc := Vector2i(floori(jx / cs), floori(jz / cs))
		if not _chunk_biome.has(cc):
			_chunk_biome[cc] = _InfiniteWorldGen.biome_for_chunk(cc.x, cc.y, _seed)
		return int(_chunk_biome[cc])


static func _tile_color(tile: int, heights: PackedFloat32Array, w: int, ix: int, iz: int,
		biome: int, wtx: int, wtz: int, world_seed: int, ts: float) -> Color:
	var wx: float = (float(wtx) + 0.5) * ts
	var wz: float = (float(wtz) + 0.5) * ts
	var sea: float = _WaterMath.sea_at(wx, wz)
	if sea > 0.0:
		return COL_SHORE.lerp(COL_WATER, clampf(sea * 3.0, 0.0, 1.0)).lerp(COL_DEEP, clampf(sea - 0.4, 0.0, 1.0))
	if tile == IsoConst.TILE_PATH:
		return COL_ROAD
	if tile == IsoConst.TILE_WALL or tile == IsoConst.TILE_CRACKED:
		return COL_WALL
	var base: Color = BIOME_GROUND[clampi(biome, 0, BIOME_GROUND.size() - 1)]
	if _WaterMath.biome_has_water(biome):
		var water: float = _WaterMath.intensity(wx, wz, world_seed)
		if water > _WaterMath.WET_LEVEL:
			return COL_WATER.lerp(COL_DEEP, clampf((water - 0.6) * 2.0, 0.0, 1.0))
	# Hills: higher is lighter (snowy on mountains), lit from the north-west.
	var here: float = heights[iz * w + ix]
	var nw: float = heights[maxi(iz - 1, 0) * w + maxi(ix - 1, 0)]
	if here > 0.0:
		base = base.lerp(Color(0.92, 0.92, 0.90) if biome == _BiomeDef.MOUNTAINS else base.lightened(0.25),
				clampf(here / 8.0, 0.0, 0.6))
	var shade: float = clampf((nw - here) * 0.10, -0.20, 0.25)
	base = base.darkened(shade) if shade > 0.0 else base.lightened(-shade)
	# Trees: a dark speck where a grove would grow one.
	var roll: float = float(absi(hash(Vector2i(wtx, wtz))) % 1000) / 1000.0
	if roll < _TreeScatter.chance_at(biome, wtx, wtz, world_seed):
		return BIOME_TREE[clampi(biome, 0, BIOME_TREE.size() - 1)]
	# Fine grain so wide plains don't read as a flat fill.
	return base.darkened((roll - 0.5) * 0.08)


## One stitched town's crop as an illustrated plan, TOWN_PX pixels per tile.
static func town_image(town: String) -> Image:
	var wm: _WorldMap = _RealmLayout.town_map(town)
	var crop: Rect2i = _RealmLayout.crop_of(town)
	var p: int = TOWN_PX
	var img := Image.create(crop.size.x * p, crop.size.y * p, false, Image.FORMAT_RGBA8)
	if wm == null:
		return img
	var streets: Dictionary = _RealmLayout.street_plan(town)["tiles"]
	var off: Vector2i = _RealmLayout.offset_of(town)
	var ts: float = IsoConst.TILE_SIZE
	for z: int in range(crop.size.y):
		for x: int in range(crop.size.x):
			var local := Vector2i(crop.position.x + x, crop.position.y + z)
			var tile: int = wm.get_tile(local.x, local.y)
			var col: Color = COL_TOWN_GROUND
			var roll: float = float(absi(hash(local)) % 1000) / 1000.0
			var wpos := Vector2(float(local.x + off.x) + 0.5, float(local.y + off.y) + 0.5) * ts
			var sea: float = _WaterMath.sea_at(wpos.x, wpos.y)
			if sea > 0.0:
				col = COL_SHORE.lerp(COL_WATER, clampf(sea * 3.0, 0.0, 1.0))
			elif streets.has(local):
				col = COL_STREET.darkened((roll - 0.5) * 0.12)
			elif tile == IsoConst.TILE_PATH:
				col = COL_PATH.darkened((roll - 0.5) * 0.10)
			elif tile == IsoConst.TILE_WALL or tile == IsoConst.TILE_CRACKED:
				col = COL_WALL
			else:
				col = col.darkened((roll - 0.5) * 0.10)
			_fill(img, x * p, z * p, p, col)
	for b: Dictionary in _RealmLayout.building_plan(town)["buildings"]:
		_draw_building(img, b, crop)
	for piece: Dictionary in _TownDecor.pieces(town):
		var c: Vector2i = (piece["tile"] as Vector2i) - crop.position
		_disc(img, Vector2((c.x + 0.5) * p, (c.y + 0.5) * p), p * 0.9, COL_OUTLINE)
		_disc(img, Vector2((c.x + 0.5) * p, (c.y + 0.5) * p), p * 0.7, COL_DECOR)
	for l: Vector2i in _RealmLayout.street_plan(town)["lamps"] as Array:
		var lc: Vector2i = l - crop.position
		_disc(img, Vector2((lc.x + 0.5) * p, (lc.y + 0.5) * p), p * 0.22, COL_LAMP)
	return img


## A building: drop shadow to the south-east, a roof split along its long axis
## into a lit and a shaded half, an outline, and a door notch.
static func _draw_building(img: Image, b: Dictionary, crop: Rect2i) -> void:
	var p: int = TOWN_PX
	var r: Rect2i = b["rect"]
	var px := Rect2i((r.position - crop.position) * p, r.size * p)
	var shadow := Rect2i(px.position + Vector2i(p / 3, p / 3), px.size)
	_rect(img, shadow, Color(0.0, 0.0, 0.0, 0.30))
	var roof: Color = ROOF_COLORS[absi(hash(r.position)) % ROOF_COLORS.size()]
	if str(b.get("kind", "")) == "tower":
		roof = Color(0.40, 0.40, 0.44)
	_rect(img, px, COL_OUTLINE)
	var inner := px.grow(-maxi(1, p / 5))
	if inner.size.x >= inner.size.y:
		var top := Rect2i(inner.position, Vector2i(inner.size.x, inner.size.y / 2))
		_rect(img, inner, roof.darkened(0.22))
		_rect(img, top, roof.lightened(0.08))
	else:
		var left := Rect2i(inner.position, Vector2i(inner.size.x / 2, inner.size.y))
		_rect(img, inner, roof.darkened(0.22))
		_rect(img, left, roof.lightened(0.08))
	for d: Vector2i in b.get("doors", []) as Array:
		var dc: Vector2i = (d - crop.position) * p
		_rect(img, Rect2i(dc + Vector2i(p / 4, p / 4), Vector2i(p / 2, p / 2)), Color(0.30, 0.20, 0.12))


static func _fill(img: Image, x: int, y: int, size: int, col: Color) -> void:
	img.fill_rect(Rect2i(x, y, size, size), col)


## Alpha-blended rect, clipped to the image.
static func _rect(img: Image, r: Rect2i, col: Color) -> void:
	var c: Rect2i = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if col.a >= 1.0:
		img.fill_rect(c, col)
		return
	for y: int in range(c.position.y, c.end.y):
		for x: int in range(c.position.x, c.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _disc(img: Image, at: Vector2, radius: float, col: Color) -> void:
	var r: int = ceili(radius)
	for y: int in range(int(at.y) - r, int(at.y) + r + 1):
		for x: int in range(int(at.x) - r, int(at.x) + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(at) <= radius:
				img.set_pixel(x, y, col)
