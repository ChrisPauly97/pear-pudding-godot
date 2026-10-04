## Roofs and trim on the stitched story towns' buildings.
##
## `RealmLayout` raises each building's wall tiles (TownBuildings plan), so the
## chunk renderer already draws and collides with tall walls. This adds
## the rest of the house from `BuildingMesh` — a roof, door lintels, windows —
## once, on the first overworld tick, and fades a roof away while the player
## stands inside (or in the doorway of) its building so the room stays visible.
## Scenery only: nothing here is saved or synced. Owned and ticked by
## RealmRegions (`realm_regions.buildings`), which already tracks the towns.
extends RefCounted

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _BuildingMesh = preload("res://game_logic/world/BuildingMesh.gd")

const FADE_TIME: float = 0.25
## Roofs and trim stop drawing past this camera distance.
const DRAW_DISTANCE: float = 140.0

static var _wood_mat: StandardMaterial3D = null
static var _glass_mat: StandardMaterial3D = null

var _world: _WorldScene = null
var _root: Node3D = null
## One entry per building: {"rect": Rect2i, "roof": MeshInstance3D, "mat": StandardMaterial3D}.
var _roofs: Array[Dictionary] = []
var _last_tile := Vector2i(1 << 30, 1 << 30)

func _init(world: _WorldScene) -> void:
	_world = world

## Per-frame (overworld only): builds on first call, then cheap until the
## player changes tile.
func tick() -> void:
	if _root == null:
		_build()
	if _world._player == null:
		return
	var tile := Vector2i(floori(_world._player.position.x / IsoConst.TILE_SIZE),
			floori(_world._player.position.z / IsoConst.TILE_SIZE))
	if tile == _last_tile:
		return
	_last_tile = tile
	for r: Dictionary in _roofs:
		var rect: Rect2i = r["rect"]
		_set_roof_shown(r, not rect.grow(1).has_point(tile))

func _build() -> void:
	_root = Node3D.new()
	_root.name = "TownBuildings"
	_world.add_child(_root)
	for b: Dictionary in RealmLayout.buildings_world():
		var roof_mat := _make_mat(Color.WHITE, false)
		var roof := _mesh_node(_BuildingMesh.build_roof(b), roof_mat)
		_root.add_child(roof)
		var trim := _mesh_node(_BuildingMesh.build_trim(b), null)
		if trim.mesh.get_surface_count() > 0:
			trim.set_surface_override_material(0, _wood())
		if trim.mesh.get_surface_count() > 1:
			trim.set_surface_override_material(1, _glass())
		_root.add_child(trim)
		_roofs.append({"rect": b["rect"], "roof": roof, "mat": roof_mat, "shown": true})

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
	var mat: StandardMaterial3D = r["mat"]
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	roof.visible = true
	var tw := roof.create_tween()
	tw.tween_property(mat, "albedo_color:a", 1.0 if shown else 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		if shown:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		else:
			roof.visible = false)

## Vertex-coloured, double-sided (roof slopes are seen from either side).
static func _make_mat(tint: Color, emissive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = tint
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.35)
		mat.emission_energy_multiplier = 0.6
	return mat

static func _wood() -> StandardMaterial3D:
	if _wood_mat == null:
		_wood_mat = _make_mat(Color.WHITE, false)
	return _wood_mat

## Warm lit windows: a soft glow that reads at night and stays subtle by day.
static func _glass() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = _make_mat(Color.WHITE, true)
	return _glass_mat
