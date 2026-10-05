## Roofs and trim on the stitched story towns' buildings.
##
## `RealmLayout` raises each building's wall tiles (TownBuildings plan), so the
## chunk renderer already draws and collides with tall walls. This adds
## the rest of the house from `BuildingMesh` — a roof, door lintels, windows —
## once, and fades a roof away while the player
## stands inside (or in the doorway of) its building so the room stays visible.
## Scenery only: nothing here is saved or synced. Owned and ticked by
## RealmRegions (`realm_regions.buildings`), which already tracks the towns.
##
## GID-164 / TID-682: the meshes are built on a WorkerThreadPool task kicked
## by the first tick (it was a ~7 ms main-thread hitch) and land on a later tick;
## roofs share one material per texture and only take private copies while
## fading; each town's static trim (lintels, windows) is merged into one mesh.
extends RefCounted

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _BuildingMesh = preload("res://game_logic/world/BuildingMesh.gd")

## Indexed by BuildingMesh.roof_style().
const ROOF_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/pixel_art/roof_clay_pixel.png"),
	preload("res://assets/textures/pixel_art/roof_slate_pixel.png"),
	preload("res://assets/textures/pixel_art/roof_thatch_pixel.png"),
	preload("res://assets/textures/pixel_art/roof_shingle_pixel.png"),
	preload("res://assets/textures/pixel_art/roof_moss_pixel.png"),
]
const _TexGable: Texture2D = preload("res://assets/textures/pixel_art/gable_pixel.png")
const _TexBrick: Texture2D = preload("res://assets/textures/pixel_art/wall_side_pixel.png")

const FADE_TIME: float = 0.25
## Roofs and trim stop drawing past this camera distance.
const DRAW_DISTANCE: float = 140.0

static var _wood_mat: StandardMaterial3D = null
static var _glass_mat: StandardMaterial3D = null
static var _tex_mats: Dictionary = {}  # Texture2D → shared opaque roof/gable/brick material

var _world: _WorldScene = null
var _root: Node3D = null
## One entry per building: {"rect": Rect2i, "roof": MeshInstance3D, "shared": Array of its
## shared StandardMaterial3D (roof, gable, chimney), "fade": private copies while
## fading ([] otherwise), "tween": Tween or null, "shown": bool}.
var _roofs: Array[Dictionary] = []
var _last_tile := Vector2i(1 << 30, 1 << 30)
var _task_id: int = -1
## Worker output: {"roofs": [[building, ArrayMesh]], "trims": {town: ArrayMesh}}.
var _built: Dictionary = {}

func _init(world: _WorldScene) -> void:
	_world = world

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

## Per-frame (overworld only): kicks the mesh build, commits it once done, then
## is cheap until the player changes tile.
func tick() -> void:
	if _root == null:
		if _task_id < 0:
			_task_id = WorkerThreadPool.add_task(_build_meshes, false, "town buildings")
			return
		if not WorkerThreadPool.is_task_completed(_task_id):
			return
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_commit()
	if _world._player == null:
		return
	var tile := IsoConst.world_to_tile(_world._player.position.x, _world._player.position.z)
	if tile == _last_tile:
		return
	_last_tile = tile
	for r: Dictionary in _roofs:
		var rect: Rect2i = r["rect"]
		_set_roof_shown(r, not rect.grow(1).has_point(tile))

## Worker thread: pure mesh building (BuildingMesh / RealmLayout's warmed plans).
func _build_meshes() -> void:
	var roofs: Array = []
	var tools: Dictionary = {}  # town → [wood SurfaceTool, glass SurfaceTool]
	for b: Dictionary in RealmLayout.buildings_world():
		roofs.append([b, _BuildingMesh.build_roof(b)])
		var trim: ArrayMesh = _BuildingMesh.build_trim(b)
		var town: String = str(b.get("town", ""))
		if not tools.has(town):
			tools[town] = [null, null]
		var pair: Array = tools[town]
		for i: int in mini(trim.get_surface_count(), 2):
			if pair[i] == null:
				pair[i] = SurfaceTool.new()
			(pair[i] as SurfaceTool).append_from(trim, i, Transform3D.IDENTITY)
	var trims: Dictionary = {}
	for town: String in tools:
		var pair: Array = tools[town]
		var merged := ArrayMesh.new()
		for i: int in 2:
			if pair[i] != null:
				(pair[i] as SurfaceTool).commit(merged)
		trims[town] = merged
	_built = {"roofs": roofs, "trims": trims}

## Main thread: nodes for the finished meshes.
func _commit() -> void:
	_root = Node3D.new()
	_root.name = "TownBuildings"
	_world.add_child(_root)
	var roofs: Array = _built.get("roofs", [])
	for entry: Array in roofs:
		var b: Dictionary = entry[0]
		var rect: Rect2i = b["rect"]
		var roof := _mesh_node(entry[1] as ArrayMesh, null)
		var shared: Array[StandardMaterial3D] = []
		for tex: Texture2D in [ROOF_TEXTURES[_BuildingMesh.roof_style(rect)], _TexGable, _TexBrick]:
			shared.append(_tex_mat(tex))
		_apply_mats(roof, shared)
		_root.add_child(roof)
		_roofs.append({"rect": rect, "roof": roof, "shared": shared, "fade": [], "tween": null, "shown": true})
	var trims: Dictionary = _built.get("trims", {})
	for town: Variant in trims:
		var trim := _mesh_node(trims[town] as ArrayMesh, null)
		trim.name = "Trim_%s" % str(town)
		if trim.mesh.get_surface_count() > 0:
			trim.set_surface_override_material(0, _wood())
		if trim.mesh.get_surface_count() > 1:
			trim.set_surface_override_material(1, _glass())
		_root.add_child(trim)
	_built = {}

static func _apply_mats(roof: MeshInstance3D, mats: Array) -> void:
	for i: int in mini(mats.size(), roof.mesh.get_surface_count()):
		roof.set_surface_override_material(i, mats[i] as Material)

func _mesh_node(mesh: ArrayMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.visibility_range_end = DRAW_DISTANCE
	return mi

func _set_roof_shown(r: Dictionary, shown: bool) -> void:
	if bool(r["shown"]) == shown:
		return
	r["shown"] = shown
	var roof: MeshInstance3D = r["roof"]
	var old_tw: Variant = r["tween"]
	if old_tw != null and (old_tw as Tween).is_valid():
		(old_tw as Tween).kill()
	# Private copies only while fading, so the shared opaque materials never
	# turn transparent; a fade-in starts from invisible copies.
	var mats: Array[StandardMaterial3D] = []
	mats.assign(r["fade"])
	if mats.is_empty():
		for m: StandardMaterial3D in r["shared"]:
			var c := m.duplicate() as StandardMaterial3D
			c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if shown:
				c.albedo_color.a = 0.0
			mats.append(c)
		r["fade"] = mats
		_apply_mats(roof, mats)
	roof.visible = true
	var tw := roof.create_tween().set_parallel(true)
	r["tween"] = tw
	for mat: StandardMaterial3D in mats:
		tw.tween_property(mat, "albedo_color:a", 1.0 if shown else 0.0, FADE_TIME)
	tw.chain().tween_callback(func() -> void:
		r["fade"] = []
		r["tween"] = null
		_apply_mats(roof, r["shared"] as Array)
		roof.visible = shown)

## Vertex-coloured, double-sided (roof slopes are seen from either side);
## pixel-art textures sample nearest-neighbour like the terrain.
static func _make_mat(tint: Color, emissive: bool, tex: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	if tex != null:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.albedo_color = tint
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.35)
		mat.emission_energy_multiplier = 0.6
	return mat

static func _tex_mat(tex: Texture2D) -> StandardMaterial3D:
	if not _tex_mats.has(tex):
		_tex_mats[tex] = _make_mat(Color.WHITE, false, tex)
	return _tex_mats[tex] as StandardMaterial3D

static func _wood() -> StandardMaterial3D:
	if _wood_mat == null:
		_wood_mat = _make_mat(Color.WHITE, false)
	return _wood_mat

## Warm lit windows: a soft glow that reads at night and stays subtle by day.
static func _glass() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = _make_mat(Color.WHITE, true)
	return _glass_mat
