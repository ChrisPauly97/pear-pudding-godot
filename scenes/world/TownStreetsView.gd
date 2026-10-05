## Street lamps along the stitched towns' streets.
##
## The streets themselves are path tiles RealmLayout stamps into the chunks
## (TownStreets plan). This stands a grimy iron lamp (StreetLampMesh) on each
## lamp tile, one MultiMesh per town (frustum-culled by
## its bounds), built on the first overworld tick. Each
## lamp gets a stable yaw and a slight lean so the rows look weathered rather
## than surveyed. The glass glows with the night factor; the light itself is a
## NightLights rig ("street_lamp" style, sources from `lamp_positions()`).
## Scenery only: nothing here is saved or synced. Owned and ticked by
## RealmRegions (`realm_regions.streets`).
extends RefCounted

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _StreetLampMesh = preload("res://game_logic/world/StreetLampMesh.gd")
const _GLASS_SHADER = preload("res://assets/shaders/street_lamp_glass.gdshader")

## Glass emission at full night, and the faint daytime sheen.
const GLOW_NIGHT: float = 2.2
const GLOW_DAY: float = 0.05
## Largest lean off vertical (radians).
const MAX_LEAN: float = 0.05

static var _iron_mat: StandardMaterial3D = null
## Shared by every lamp (the mesh is shared), so one uniform write lights them all.
static var _glass_mat: ShaderMaterial = null

var _world: _WorldScene = null
var _root: Node3D = null
var _glow: float = -1.0

func _init(world: _WorldScene) -> void:
	_world = world

## Ground-level world position of every street lamp (the light rides LIGHT_HEIGHT above).
static func lamp_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t: Vector2i in RealmLayout.street_lamps_world():
		out.append(Vector3(IsoConst.tile_center(t.x), 0.0, IsoConst.tile_center(t.y)))
	return out

## Per-frame (overworld only): builds on first call, then only eases the glow.
func tick() -> void:
	if _root == null:
		_build()
	var night: float = 0.0
	if _world.night_lights != null:
		night = _world.night_lights.night_level()
	var glow: float = lerpf(GLOW_DAY, GLOW_NIGHT, night)
	if absf(glow - _glow) > 0.01:
		_glow = glow
		_glass_mat.set_shader_parameter("glow", glow)

func lamp_count() -> int:
	var n: int = 0
	if _root == null:
		return n
	for c: Node in _root.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi != null:
			n += mmi.multimesh.instance_count
	return n

func _build() -> void:
	_root = Node3D.new()
	_root.name = "TownStreetLamps"
	_world.add_child(_root)
	if _glass_mat == null:
		_glass_mat = ShaderMaterial.new()
		_glass_mat.shader = _GLASS_SHADER
	var lamp: ArrayMesh = _StreetLampMesh.mesh()
	lamp.surface_set_material(0, _iron())
	lamp.surface_set_material(1, _glass_mat)
	var by_town: Dictionary = {}
	for t: Vector2i in RealmLayout.street_lamps_world():
		var town: String = RealmLayout.town_at_tile(t.x, t.y)
		if not by_town.has(town):
			by_town[town] = [] as Array[Vector2i]
		var list: Array[Vector2i] = by_town[town]
		list.append(t)
	for town: Variant in by_town.keys():
		var tiles: Array[Vector2i] = by_town[town]
		_root.add_child(_town_lamps(tiles))

func _town_lamps(tiles: Array[Vector2i]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _StreetLampMesh.mesh()
	mm.instance_count = tiles.size()
	for i: int in tiles.size():
		var t: Vector2i = tiles[i]
		mm.set_instance_transform(i, lamp_transform(t))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

## Stable per-tile yaw and lean, standing on the tile centre.
static func lamp_transform(t: Vector2i) -> Transform3D:
	var h: int = absi(t.x * 73856093 ^ t.y * 19349663)
	var yaw: float = float(h % 360) * PI / 180.0
	var lean: float = (float((h / 360) % 100) / 100.0 - 0.5) * 2.0 * MAX_LEAN
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
	return Transform3D(basis, Vector3(IsoConst.tile_center(t.x), 0.0, IsoConst.tile_center(t.y)))

static func _iron() -> StandardMaterial3D:
	if _iron_mat == null:
		_iron_mat = StandardMaterial3D.new()
		_iron_mat.vertex_color_use_as_albedo = true
		_iron_mat.roughness = 0.85
		_iron_mat.metallic = 0.35
	return _iron_mat
