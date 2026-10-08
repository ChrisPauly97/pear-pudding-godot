## Maykalene's waterfront on the eastern sea (GID-171 / TID-692): switches the hero to
## swimming in water too deep to wade — the sea and the rivers (GID-172, `Swimming`) —
## builds the river bridges (`RiverBridges`), and dresses the shore — a plank pier, a stone quay edge, boats
## bobbing at their moorings, crates and barrels on the quay. The sea itself is
## terrain water (`Coast` → `WaterMath`). Scenery only (not synced: every peer
## builds the same pieces from `Coast`).
## Created by `WorldScene._ensure_world_modules()` as `coastline`; runs its own
## `_process` (builds once on the overworld, then bobs the boats).
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _Coast = preload("res://game_logic/world/Coast.gd")
const _Rivers = preload("res://game_logic/world/Rivers.gd")
const _Player = preload("res://scenes/world/entities/Player.gd")
const _Swimming = preload("res://game_logic/world/Swimming.gd")
const _SwimMeter = preload("res://scenes/world/SwimMeter.gd")
const _RiverBridges = preload("res://scenes/world/RiverBridges.gd")
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
## Who's aboard: a rower amidships in each rowboat, a captain on each cog's aft castle.
## `dx` world units along screen-right (mirrored with the boat), `rail` the height of the
## gunwale / castle rail above the hull sprite's centre, `h` the figure's full height and
## `show` the share of it (head and shoulders down) that shows above the rail. The rest
## is cropped off the sprite: billboards don't hide one another, so the hull can't.
const CREW: Dictionary = {
	"rowboat": {"dx": 0.0, "rail": 0.29, "h": 1.2, "show": 0.55},
	"cog": {"dx": 2.25, "rail": -1.0, "h": 1.4, "show": 0.62},
}
## A rower's stroke while under way: bob height and strokes per second.
const ROW_BOB: float = 0.05
const ROW_RATE: float = 4.0
const DECK_Y: float = 0.03
const WOOD := Color(0.47, 0.32, 0.19)
const WOOD_DARK := Color(0.30, 0.20, 0.13)
const STONE := Color(0.62, 0.62, 0.60)

var stamina: float = 1.0  # swim stamina 0..1 (GID-172 / TID-697); not saved, refills on land
var _world: _WorldScene = null
var _root: Node3D = null
var _boats: Array[Sprite3D] = []
var _boat_base_y: Array[float] = []
var _crew: Array[Sprite3D] = []
var _time: float = 0.0
var _meter: _SwimMeter = null
var _warned: bool = false   # "head for shore" shown this swim
var _washing: bool = false  # exhausted: the wash-ashore transition is running


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
	# Boats keep the shared clock (TownLife's smooth reading): tied up, out to sea, back.
	var clock: float = -1.0
	if _world._dnc != null:
		clock = _world._dnc.get_smooth_time_of_day() * _world.day_duration
	for i: int in _boats.size():
		var spr: Sprite3D = _boats[i]
		var b: Dictionary = _Coast.BOATS[i]
		var st: Dictionary = _Coast.boat_at(b, clock, _world.day_duration) if clock >= 0.0 else {}
		if not st.is_empty():
			spr.visible = not bool(st["away"])
			var p: Vector2 = st["pos"]
			spr.position.x = p.x * IsoConst.TILE_SIZE
			spr.position.z = p.y * IsoConst.TILE_SIZE
			var dir: Vector2 = st["dir"]
			# Face the way it is going on screen (screen-right is world (+1, 0, -1)); else its berth facing.
			var flip: bool = (dir.x - dir.y < 0.0) if dir != Vector2.ZERO else int(b["flip"]) < 0
			if flip != spr.flip_h:
				spr.flip_h = flip
				_place_crew(_crew[i], str(b["kind"]), flip)
			# Pulling at the oars while under way.
			var stroke: float = absf(sin(_time * ROW_RATE * PI)) * ROW_BOB if dir != Vector2.ZERO else 0.0
			_crew[i].position.y = _crew_y(str(b["kind"])) + stroke
		spr.position.y = _boat_base_y[i] + sin(_time * BOB_SPEED + float(i) * 1.7) * BOB_AMPLITUDE


## Deep water (the sea off the piers, a river off the bridges — GID-172) is swum: the hero
## gets off a mount and the Player switches to its swim state; back in the shallows, walks.
## Swimming drains stamina (`Swimming.step`), a river's current carries the swimmer, and an
## exhausted swimmer washes up on the nearest shore at 1 HP.
func _physics_process(delta: float) -> void:
	if _world == null or _world._player == null:
		return
	var p: _Player = _world._player
	var pos: Vector3 = p.global_position
	var deep: bool = _world._is_infinite and _world.map_name == "main" and _deep(pos)
	if deep and SceneManager.save_manager.is_mounted:
		SceneManager.save_manager.dismiss_mount()  # the horse won't swim; whistle for it on land
	p.set_swimming(deep)
	var flow: Vector2 = _Rivers.flow(pos.x, pos.z) if deep else Vector2.ZERO
	p.current_push = Vector3(flow.x, 0.0, flow.y) * _Swimming.CURRENT_PUSH
	if not SceneManager.is_in_world() or _washing:
		return
	var heading := Vector2(p.velocity.x, p.velocity.z) - flow * _Swimming.CURRENT_PUSH
	stamina = _Swimming.step(stamina, delta, deep, _Swimming.depth_at(pos.x, pos.z), p._is_moving,
			_Swimming.against(heading, flow))
	if not deep:
		_warned = false
	elif stamina < _Swimming.LOW and not _warned:
		_warned = true
		GameBus.hud_message_requested.emit("You're tiring — swim for the shore!")
	if deep and stamina <= 0.0:
		_wash_ashore()
	_show_meter(delta)


func _show_meter(delta: float) -> void:
	if _meter == null and _world._hud != null:
		_meter = _SwimMeter.new()
		_world._hud.add_child(_meter)
	if _meter != null:
		_meter.show_stamina(stamina, _world._player.global_position, _world._camera, delta)


## Exhausted (TID-697): the screen wipes and the hero wakes on the nearest shore at 1 HP.
func _wash_ashore() -> void:
	_washing = true
	TransitionManager.transition(func() -> void:
		var p: _Player = _world._player
		if p != null:
			var t: Vector2i = IsoConst.world_to_tile(p.global_position.x, p.global_position.z)
			var land: Vector2i = _Rivers.nearest_dry(t.x, t.y)
			var lx: float = IsoConst.tile_center(land.x)
			var lz: float = IsoConst.tile_center(land.y)
			p.global_position = Vector3(lx, _world.get_terrain_height(lx, lz) + 0.5, lz)
			p.velocity = Vector3.ZERO
			p.cancel_path()
			p.set_swimming(false)
		var sm := SceneManager.save_manager
		sm.hero_hp_frac = minf(sm.hero_hp_frac, _Swimming.WASHED_UP_FRAC)
		sm.mark_dirty()
		stamina = 1.0
		_washing = false
		GameBus.hud_message_requested.emit("Exhausted, you wash up on the shore."))


static func _deep(pos: Vector3) -> bool:
	var t: Vector2i = IsoConst.world_to_tile(pos.x, pos.z)
	return _Rivers.deep_water(t.x, t.y)  # the sea or a river (GID-172)


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
	for b: Dictionary in _Rivers.bridges():  # where a road crosses a river (GID-172)
		var c: Vector2 = b["centre"]
		var ground: float = _world.get_terrain_height(c.x * IsoConst.TILE_SIZE, c.y * IsoConst.TILE_SIZE)
		_root.add_child(_RiverBridges.make_bridge(b, mat, ground))
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


## A rail along every deck edge that faces open water (not land or more pier), except
## the open ends and gangways (`Coast.rail_open`).
func _build_railings(st: SurfaceTool, r: Rect2i) -> void:
	var ts: float = IsoConst.TILE_SIZE
	for tz: int in range(r.position.y, r.end.y):
		for tx: int in range(r.position.x, r.end.x):
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(tx, tz) + dir
				if r.has_point(n) or _Coast.on_pier(n.x, n.y) or not _Coast.is_sea(n.x, n.y):
					continue
				if _Coast.rail_open(r, Vector2i(tx, tz), dir):
					continue  # open pier ends and gangways, where boats come alongside
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
	var c: Dictionary = CREW.get(kind, {})
	var tex: Texture2D = _SpriteRegistry.townsperson_texture(_boats.size())
	var crew := _billboard(tex, float(c.get("h", 1.2)))
	crew.region_enabled = true
	crew.region_rect = Rect2(0.0, 0.0, float(tex.get_width()),
			roundf(float(tex.get_height()) * float(c.get("show", 0.6))))
	spr.add_child(crew)
	_crew.append(crew)
	_place_crew(crew, kind, spr.flip_h)


## Seat (or stand) a boat's crew with the crop's bottom edge on the rail. Children of a
## billboard aren't billboarded, so this is world space: screen-right is (1, 0, -1).
static func _place_crew(crew: Sprite3D, kind: String, flipped: bool) -> void:
	var c: Dictionary = CREW.get(kind, {})
	var dx: float = float(c.get("dx", 0.0)) * (-1.0 if flipped else 1.0)
	crew.position = Vector3(1.0, 0.0, -1.0).normalized() * dx + Vector3(0.0, _crew_y(kind), 0.0)
	crew.flip_h = flipped


## Centre height of the cropped crew sprite: its bottom edge on the rail.
static func _crew_y(kind: String) -> float:
	var c: Dictionary = CREW.get(kind, {})
	return float(c.get("rail", 0.0)) + float(c.get("h", 1.2)) * float(c.get("show", 0.6)) * 0.5


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
