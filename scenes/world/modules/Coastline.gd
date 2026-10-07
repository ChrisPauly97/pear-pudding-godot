## Maykalene's waterfront on the eastern sea (GID-171 / TID-692): keeps the hero
## out of water too deep to wade (sliding along the shore, Ghost Phase and mounts
## included), and dresses the shore — a plank pier, a stone quay edge, boats
## bobbing at their moorings, crates and barrels on the quay. The sea itself is
## terrain water (`Coast` → `WaterMath`). Scenery only (not synced: every peer
## builds the same pieces from `Coast`).
## Created by `WorldScene._ensure_world_modules()` as `coastline`; runs its own
## `_process` (builds once on the overworld, then bobs the boats).
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _Coast = preload("res://game_logic/world/Coast.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _WorldEntityBase = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _BOAT_TEX: Dictionary = {
	"cog": preload("res://assets/textures/props/boat_cog.png"),
	"rowboat": preload("res://assets/textures/props/boat_rowboat.png"),
}
const _CRATE_TEX := preload("res://assets/textures/props/camp_crate.png")
const _BARREL_TEX := preload("res://assets/textures/props/camp_barrel.png")
const _BEACHED_TEX := preload("res://assets/textures/props/boat_beached.png")
## Shells, starfish and driftwood washed up on the beach: texture, world height.
const _BEACH_CLUTTER: Array = [
	[preload("res://assets/textures/props/beach_shell.png"), 0.35],
	[preload("res://assets/textures/props/beach_starfish.png"), 0.35],
	[preload("res://assets/textures/props/beach_driftwood.png"), 0.45],
]
## Share of beach tiles near town that get a piece of clutter.
const CLUTTER_CHANCE: int = 7  # percent

## World-unit sprite heights per boat kind.
const BOAT_HEIGHT: Dictionary = {"cog": 7.0, "rowboat": 1.3}
## How far a boat's hull sits below the water line, and its bob.
const BOAT_DRAFT: float = 0.35
const BOB_AMPLITUDE: float = 0.07
const BOB_SPEED: float = 1.4
## Quay clutter (overworld tiles; the quay is Maykalene local x 75..79).
const CARGO: Array[Dictionary] = [
	{"tex": "crate", "tile": Vector2(41.3, 75.4)}, {"tex": "barrel", "tile": Vector2(40.6, 76.2)},
	{"tex": "crate", "tile": Vector2(41.5, 89.6)}, {"tex": "barrel", "tile": Vector2(41.4, 96.5)},
	{"tex": "barrel", "tile": Vector2(40.7, 97.1)}, {"tex": "crate", "tile": Vector2(41.2, 106.3)},
]
const CARGO_HEIGHT: float = 1.1
## A move longer than this (world units) in one physics frame is a teleport, not a step.
const TELEPORT_DIST: float = 4.0
const DECK_Y: float = 0.03
const WOOD := Color(0.47, 0.32, 0.19)
const WOOD_DARK := Color(0.30, 0.20, 0.13)
const STONE := Color(0.62, 0.62, 0.60)

var _world: _WorldScene = null
var _root: Node3D = null
var _last_safe: Vector3 = Vector3.INF
var _boats: Array[Sprite3D] = []
var _boat_base_y: Array[float] = []
var _time: float = 0.0


func _ready() -> void:
	process_physics_priority = 100  # after the player has moved this frame


func _process(delta: float) -> void:
	if _world == null:
		return
	if _root == null:
		if _world.map_name == "main" and _world._is_infinite and not NetworkManager.is_dedicated_server():
			_build()
		return
	_time += delta
	for i: int in _boats.size():
		_boats[i].position.y = _boat_base_y[i] + sin(_time * BOB_SPEED + float(i) * 1.7) * BOB_AMPLITUDE


## Deep water stops the hero: keep the axis that stays in the shallows (slide along
## the shore), else step back to the last safe spot.
func _physics_process(_delta: float) -> void:
	if _world == null or not _world._is_infinite or _world._player == null:
		return
	var p: Node3D = _world._player
	var pos: Vector3 = p.global_position
	if not _deep(pos):
		_last_safe = pos
		return
	# Arrived in the sea in one jump (a load, a teleport): wade ashore instead of sliding.
	if _last_safe == Vector3.INF or Vector2(pos.x - _last_safe.x, pos.z - _last_safe.z).length() > TELEPORT_DIST:
		var land: Vector2i = _Coast.to_land(IsoConst.world_to_tile(pos.x, pos.z).x,
				IsoConst.world_to_tile(pos.x, pos.z).y)
		var lx: float = IsoConst.tile_center(land.x)
		var lz: float = IsoConst.tile_center(land.y)
		p.global_position = Vector3(lx, _world.get_terrain_height(lx, lz) + 0.5, lz)
		_last_safe = p.global_position
		return
	var keep_x := Vector3(pos.x, pos.y, _last_safe.z)
	var keep_z := Vector3(_last_safe.x, pos.y, pos.z)
	if not _deep(keep_x):
		p.global_position = keep_x
	elif not _deep(keep_z):
		p.global_position = keep_z
	else:
		p.global_position = Vector3(_last_safe.x, pos.y, _last_safe.z)
	_last_safe = p.global_position


static func _deep(pos: Vector3) -> bool:
	var t: Vector2i = IsoConst.world_to_tile(pos.x, pos.z)
	return _Coast.is_deep(t.x, t.y)


func _build() -> void:
	_root = Node3D.new()
	_root.name = "Coastline"
	_world._entity_root.add_child(_root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_piers(st)
	_build_quay_edge(st)
	var mi := MeshInstance3D.new()
	mi.name = "PierAndQuay"
	mi.mesh = st.commit()
	var mat: StandardMaterial3D = _WorldEntityBase.unshaded_material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	_root.add_child(mi)
	for b: Dictionary in _Coast.BOATS:
		_add_boat(b)
	_build_beach()
	for c: Dictionary in CARGO:
		var tex: Texture2D = _CRATE_TEX if str(c["tex"]) == "crate" else _BARREL_TEX
		var t: Vector2 = c["tile"]
		var spr := _billboard(tex, CARGO_HEIGHT)
		var x: float = t.x * IsoConst.TILE_SIZE
		var z: float = t.y * IsoConst.TILE_SIZE
		spr.position = Vector3(x, _world.get_terrain_height(x, z) + CARGO_HEIGHT * 0.5, z)
		_root.add_child(spr)


## Plank decks just above the ground the hero walks on, with posts into the water.
func _build_piers(st: SurfaceTool) -> void:
	var ts: float = IsoConst.TILE_SIZE
	for r: Rect2i in _Coast.PIERS:
		var x0: float = float(r.position.x) * ts
		var z0: float = float(r.position.y) * ts
		var x1: float = float(r.end.x) * ts
		var z1: float = float(r.end.y) * ts
		var along_x: bool = r.size.x >= r.size.y
		# Planks run across the pier, 0.5 u wide with a dark seam between them.
		var length: float = (x1 - x0) if along_x else (z1 - z0)
		var n: int = int(length / 0.5)
		for i: int in n:
			var a: float = (x0 if along_x else z0) + float(i) * 0.5
			var col: Color = WOOD if i % 2 == 0 else WOOD.darkened(0.08)
			if along_x:
				_box(st, Vector3(a + 0.03, DECK_Y - 0.12, z0), Vector3(a + 0.47, DECK_Y, z1), col)
			else:
				_box(st, Vector3(x0, DECK_Y - 0.12, a + 0.03), Vector3(x1, DECK_Y, a + 0.47), col)
		_build_railings(st, r)
		# Stringers under the seams, and posts every two tiles along both sides.
		_box(st, Vector3(x0, DECK_Y - 0.2, z0), Vector3(x1, DECK_Y - 0.12, z1), WOOD_DARK)
		var step: float = 2.0 * ts
		var p: float = (x0 if along_x else z0) + 0.2
		var stop: float = x1 if along_x else z1
		while p < stop:
			for side: float in ([z0 + 0.05, z1 - 0.3] if along_x else [x0 + 0.05, x1 - 0.3]):
				if along_x:
					_box(st, Vector3(p, -0.9, side), Vector3(p + 0.25, DECK_Y + 0.25, side + 0.25), WOOD_DARK)
				else:
					_box(st, Vector3(side, -0.9, p), Vector3(side + 0.25, DECK_Y + 0.25, p + 0.25), WOOD_DARK)
			p += step


## A rail along every deck edge that faces open water (not land or more pier).
func _build_railings(st: SurfaceTool, r: Rect2i) -> void:
	var ts: float = IsoConst.TILE_SIZE
	for tz: int in range(r.position.y, r.end.y):
		for tx: int in range(r.position.x, r.end.x):
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(tx, tz) + dir
				if r.has_point(n) or _Coast.on_pier(n.x, n.y) or not _Coast.is_sea(n.x, n.y):
					continue
				# The edge's two ends, pulled 0.12 u in from the deck edge.
				var c := Vector2((float(tx) + 0.5) * ts, (float(tz) + 0.5) * ts) + Vector2(dir) * (ts * 0.5 - 0.12)
				var along := Vector2(absf(float(dir.y)), absf(float(dir.x))) * (ts * 0.5)
				var a: Vector2 = c - along
				var b: Vector2 = c + along
				for y: float in [0.42, 0.82]:
					_box(st, Vector3(minf(a.x, b.x) - 0.05, y, minf(a.y, b.y) - 0.05),
						Vector3(maxf(a.x, b.x) + 0.05, y + 0.08, maxf(a.y, b.y) + 0.05), WOOD)
				for k: float in [0.0, 0.5]:
					var p: Vector2 = a.lerp(b, k)
					_box(st, Vector3(p.x - 0.06, DECK_Y, p.y - 0.06), Vector3(p.x + 0.06, 0.9, p.y + 0.06), WOOD_DARK)


## Clutter washed up on the sand near town, and the beached rowboat (deterministic).
func _build_beach() -> void:
	var bb: Rect2 = _Coast.BOUNDS.grow(_Coast.WOBBLE + _Coast.BEACH_WIDTH + _Coast.BEACH_WOBBLE + 1.0)
	for tz: int in range(int(bb.position.y), int(bb.end.y)):
		for tx: int in range(int(bb.position.x), mini(int(bb.end.x), _Coast.BEACH_CLUTTER_MAX_X)):
			var h: int = absi(tx * 73856093 ^ tz * 19349663)
			if h % 100 >= CLUTTER_CHANCE or not _Coast.is_beach(tx, tz):
				continue
			var pick: Array = _BEACH_CLUTTER[(h / 100) % _BEACH_CLUTTER.size()]
			var spr := _billboard(pick[0] as Texture2D, float(pick[1]))
			var x: float = (float(tx) + 0.2 + 0.6 * float((h / 1000) % 100) / 100.0) * IsoConst.TILE_SIZE
			var z: float = (float(tz) + 0.2 + 0.6 * float((h / 100000) % 100) / 100.0) * IsoConst.TILE_SIZE
			spr.flip_h = (h / 7) % 2 == 0
			spr.position = Vector3(x, _world.get_terrain_height(x, z) + float(pick[1]) * 0.5, z)
			_root.add_child(spr)
	var boat := _billboard(_BEACHED_TEX, 1.4)
	var bx: float = _Coast.BEACHED_BOAT.x * IsoConst.TILE_SIZE
	var bz: float = _Coast.BEACHED_BOAT.y * IsoConst.TILE_SIZE
	boat.position = Vector3(bx, _world.get_terrain_height(bx, bz) + 0.6, bz)
	_root.add_child(boat)


## A low dressed-stone kerb where Maykalene's quay meets the water (gaps for the piers).
func _build_quay_edge(st: SurfaceTool) -> void:
	var ts: float = IsoConst.TILE_SIZE
	var x: float = _Coast.SHORE[0].x * ts
	var z_from: int = int(_Coast.SHORE[0].y)
	var z_to: int = int(_Coast.SHORE[_Coast.SHORE.size() - 1].y)
	for tz: int in range(z_from, z_to):
		if _Coast.on_pier(int(_Coast.SHORE[0].x), tz):
			continue
		var col: Color = STONE if tz % 2 == 0 else STONE.darkened(0.1)
		_box(st, Vector3(x - 0.15, -0.5, float(tz) * ts + 0.02), Vector3(x + 0.35, 0.18, float(tz + 1) * ts - 0.02), col)


func _add_boat(b: Dictionary) -> void:
	var kind: String = str(b["kind"])
	var h: float = float(BOAT_HEIGHT.get(kind, 2.0))
	var spr := _billboard(_BOAT_TEX[kind] as Texture2D, h)
	spr.flip_h = int(b["flip"]) < 0
	var t: Vector2 = b["tile"]
	var base_y: float = h * 0.5 - BOAT_DRAFT
	spr.position = Vector3(t.x * IsoConst.TILE_SIZE, base_y, t.y * IsoConst.TILE_SIZE)
	_root.add_child(spr)
	_boats.append(spr)
	_boat_base_y.append(base_y)


func _billboard(tex: Texture2D, height: float) -> Sprite3D:
	var spr := Sprite3D.new()
	_SpriteRegistry.apply_billboard_flags(spr)
	spr.texture = tex
	spr.pixel_size = height / float(tex.get_height())
	return spr


## Axis-aligned box between corners a and b, vertex-coloured (no bottom face).
static func _box(st: SurfaceTool, a: Vector3, b: Vector3, col: Color) -> void:
	var c: Array[Vector3] = [
		Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z),
	]
	var faces: Array = [[4, 5, 6, 7, 1.0], [3, 2, 1, 0, 0.0], [0, 1, 5, 4, 0.8], [2, 3, 7, 6, 0.8],
		[3, 0, 4, 7, 0.65], [1, 2, 6, 5, 0.65]]
	for f: Array in faces:
		if float(f[4]) <= 0.0:
			continue
		var shade: Color = col * float(f[4])
		shade.a = 1.0
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(shade)
			st.add_vertex(c[int(f[idx])])
