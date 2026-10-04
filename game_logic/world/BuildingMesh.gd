## BuildingMesh — roof and trim geometry for a TownBuildings footprint.
##
## The walls themselves are the raised wall tiles the chunk renderer already
## draws (and collides with); this adds what turns a ring of wall into a house:
##
##   roof — gabled roof with shingle bands, plastered gable ends and a chimney
##          (houses), or a pyramid cap (towers). One surface, vertex-coloured,
##          so the whole roof fades as one when the player walks inside.
##   trim — lintel beams over doorway gaps, a painted door on closed houses and
##          framed windows along the walls (surface 0 wood, surface 1 glass).
##
## Pure geometry in world units (y = 0 is the town floor). No scene tree.
extends RefCounted

const _TownBuildings = preload("res://game_logic/world/TownBuildings.gd")

## Roof overhang past the walls (world units).
const EAVE: float = 0.4
const MIN_RISE: float = 1.2
const MAX_RISE: float = 4.5
## Ridge rise per unit of half-span, before the clamp.
const PITCH: float = 0.6
## Doorway lintels sit above this height; walls shorter than it get none.
const LINTEL_Y: float = 2.2
const WINDOW_EVERY: int = 3
const WINDOW_Y0: float = 1.2
const WINDOW_SIZE: float = 0.8
const FACE_OFFSET: float = 0.03

## Number of roof textures (clay, slate, thatch, wood shingle, mossy clay).
const ROOF_STYLES: int = 5
## World units one 128 px texture tile covers: the brick wall's density.
const TEX_UNITS: float = 6.4
## Ridge cap: a darker strip of roof along the ridge.
const RIDGE_W: float = 0.35
const RIDGE_H: float = 0.2
const RIDGE_SHADE := Color(0.62, 0.62, 0.62)
const WOOD_COLOR := Color(0.33, 0.22, 0.14)
const GLASS_COLOR := Color(0.95, 0.78, 0.45)

## Roof style (index into the view's roof textures), stable per footprint.
static func roof_style(rect: Rect2i) -> int:
	var h: int = absi(rect.position.x * 73856093 ^ rect.position.y * 19349663)
	return h % ROOF_STYLES

static func wall_top(b: Dictionary) -> float:
	return float(int(b["levels"])) * IsoConst.WALL_FACE_H

## Surface 0: roof (roof texture). Surface 1: gable ends (timber-framed plaster).
## Surface 2: chimney (wall brick). All UV-mapped at TEX_UNITS per texture tile.
static func build_roof(b: Dictionary) -> ArrayMesh:
	var roof := _surface()
	var gable := _surface()
	var stone := _surface()
	var rect: Rect2i = b["rect"]
	if str(b["kind"]) == _TownBuildings.KIND_TOWER:
		_pyramid(roof, rect, wall_top(b))
	else:
		_gable_roof(roof, gable, stone, rect, wall_top(b))
	var mesh: ArrayMesh = roof.commit()
	gable.commit(mesh)
	stone.commit(mesh)
	return mesh

static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

## Surface 0: wood (lintels, door, frames). Surface 1: window glass.
static func build_trim(b: Dictionary) -> ArrayMesh:
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rect: Rect2i = b["rect"]
	var top: float = wall_top(b)
	var doors: Array[Vector2i] = []
	doors.assign(b["doors"])
	if top > LINTEL_Y + 0.2:
		for d: Vector2i in doors:
			var x0: float = float(d.x) * IsoConst.TILE_SIZE
			var z0: float = float(d.y) * IsoConst.TILE_SIZE
			_box(wood, Vector3(x0, LINTEL_Y, z0),
					Vector3(x0 + IsoConst.TILE_SIZE, top, z0 + IsoConst.TILE_SIZE), WOOD_COLOR)
	if str(b["kind"]) == _TownBuildings.KIND_HOUSE:
		if doors.is_empty():
			_painted_door(wood, rect)
		_windows(wood, glass, rect, doors)
	var mesh: ArrayMesh = wood.commit()
	glass.commit(mesh)
	return mesh

# ── Roofs ──────────────────────────────────────────────────────────────────

static func _gable_roof(roof: SurfaceTool, gable: SurfaceTool, stone: SurfaceTool,
		rect: Rect2i, top: float) -> void:
	var ts: float = IsoConst.TILE_SIZE
	var along_x: bool = rect.size.x >= rect.size.y
	# Work in (u = along the ridge, v = across it) and map back to (x, z).
	var u0: float = float(rect.position.x if along_x else rect.position.y) * ts
	var u1: float = float(rect.end.x if along_x else rect.end.y) * ts
	var v0: float = float(rect.position.y if along_x else rect.position.x) * ts
	var v1: float = float(rect.end.y if along_x else rect.end.x) * ts
	var vc: float = (v0 + v1) * 0.5
	var half: float = (v1 - v0) * 0.5
	var rise: float = clampf(half * PITCH, MIN_RISE, MAX_RISE)
	var slope: float = rise / half
	var ridge_y: float = top + rise
	var slant: float = sqrt(1.0 + slope * slope)  # slope length per unit across
	var ea: float = u0 - EAVE
	var eb: float = u1 + EAVE
	# Two slopes, eave → ridge. Texture u runs along the ridge, v down the slope.
	for side: float in [-1.0, 1.0]:
		var v_eave: float = vc + side * (half + EAVE)
		var y_eave: float = top - EAVE * slope
		var tv: float = (half + EAVE) * slant / TEX_UNITS
		_quad_uv(roof, [
			_uv(along_x, ea, y_eave, v_eave), _uv(along_x, eb, y_eave, v_eave),
			_uv(along_x, eb, ridge_y, vc), _uv(along_x, ea, ridge_y, vc),
		], [Vector2(ea, tv * TEX_UNITS), Vector2(eb, tv * TEX_UNITS), Vector2(eb, 0.0), Vector2(ea, 0.0)],
				Color.WHITE)
	# Ridge cap: a shaded strip of the same roofing sitting on the ridge.
	var cap_lo: Vector3 = _uv(along_x, ea, ridge_y - RIDGE_H * 0.5, vc - RIDGE_W * 0.5)
	var cap_hi: Vector3 = _uv(along_x, eb, ridge_y + RIDGE_H, vc + RIDGE_W * 0.5)
	_box_uv(roof, cap_lo.min(cap_hi), cap_lo.max(cap_hi), RIDGE_SHADE)
	# Timber-framed gable ends, flush with the end walls.
	var mid_u: float = (u0 + u1) * 0.5
	for u: float in [u0, u1]:
		_tri_uv(gable, _uv(along_x, u, top, v0), _uv(along_x, u, top, v1), _uv(along_x, u, ridge_y, vc),
				Vector2(v0, -top), Vector2(v1, -top), Vector2(vc, -ridge_y),
				Color.WHITE, _uv(along_x, u - mid_u, 0.0, 0.0))
	# A brick chimney on the far slope, a quarter of the way along, for larger houses.
	if rect.size.x * rect.size.y >= 30:
		var cu: float = lerpf(u0, u1, 0.25)
		var cv: float = vc - half * 0.45
		var w: float = 0.8
		var lo: Vector3 = _uv(along_x, cu - w * 0.5, top, cv - w * 0.5)
		var hi: Vector3 = _uv(along_x, cu + w * 0.5, ridge_y + 0.9, cv + w * 0.5)
		_box_uv(stone, lo.min(hi), lo.max(hi), Color.WHITE)

static func _pyramid(st: SurfaceTool, rect: Rect2i, top: float) -> void:
	var ts: float = IsoConst.TILE_SIZE
	var x0: float = float(rect.position.x) * ts - EAVE
	var x1: float = float(rect.end.x) * ts + EAVE
	var z0: float = float(rect.position.y) * ts - EAVE
	var z1: float = float(rect.end.y) * ts + EAVE
	var apex := Vector3((x0 + x1) * 0.5, top + clampf((x1 - x0) * 0.55, MIN_RISE, MAX_RISE), (z0 + z1) * 0.5)
	var c := [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)]
	for i: int in range(4):
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var edge: float = a.distance_to(b)
		var mid: Vector3 = (a + b) * 0.5
		var height: float = mid.distance_to(apex)  # slant height of this face
		_tri_uv(st, a, b, apex, Vector2(0.0, height), Vector2(edge, height), Vector2(edge * 0.5, 0.0),
				Color.WHITE)

## (u along ridge, y, v across) → world (x, y, z).
static func _uv(along_x: bool, u: float, y: float, v: float) -> Vector3:
	return Vector3(u, y, v) if along_x else Vector3(v, y, u)

# ── Trim ───────────────────────────────────────────────────────────────────

## Closed houses (entered through a door portal, or not at all) get a door
## painted on the wall facing the camera, so they still read as houses.
static func _painted_door(st: SurfaceTool, rect: Rect2i) -> void:
	var ts: float = IsoConst.TILE_SIZE
	var cx: float = (float(rect.position.x) + float(rect.size.x) * 0.5) * ts
	var z: float = float(rect.end.y) * ts + FACE_OFFSET
	_quad(st, [Vector3(cx - 0.55, 0.0, z), Vector3(cx + 0.55, 0.0, z),
			Vector3(cx + 0.55, 1.9, z), Vector3(cx - 0.55, 1.9, z)], WOOD_COLOR, Vector3(0, 0, 1))

static func _windows(wood: SurfaceTool, glass: SurfaceTool, rect: Rect2i, doors: Array[Vector2i]) -> void:
	var ts: float = IsoConst.TILE_SIZE
	var door_col: int = rect.position.x + rect.size.x / 2  # where _painted_door sits
	for t: Vector2i in _TownBuildings.border_tiles(rect):
		var on_x: bool = t.x == rect.position.x or t.x == rect.end.x - 1
		var on_z: bool = t.y == rect.position.y or t.y == rect.end.y - 1
		if on_x and on_z:
			continue  # corner
		var along: int = (t.x - rect.position.x) if on_z else (t.y - rect.position.y)
		if along % WINDOW_EVERY != 1 or _near_door(t, doors):
			continue
		if doors.is_empty() and t.y == rect.end.y - 1 and absi(t.x - door_col) <= 1:
			continue
		# Outward normal and the wall plane of this border tile.
		var n := Vector3.ZERO
		if t.y == rect.position.y:
			n = Vector3(0, 0, -1)
		elif t.y == rect.end.y - 1:
			n = Vector3(0, 0, 1)
		elif t.x == rect.position.x:
			n = Vector3(-1, 0, 0)
		else:
			n = Vector3(1, 0, 0)
		var centre := Vector3(IsoConst.tile_center(t.x), WINDOW_Y0 + WINDOW_SIZE * 0.5, IsoConst.tile_center(t.y))
		centre += n * (ts * 0.5)
		_face_rect(wood, centre + n * FACE_OFFSET, n, WINDOW_SIZE + 0.2, WINDOW_SIZE + 0.2, WOOD_COLOR)
		_face_rect(glass, centre + n * (FACE_OFFSET * 2.0), n, WINDOW_SIZE, WINDOW_SIZE, GLASS_COLOR)

static func _near_door(t: Vector2i, doors: Array[Vector2i]) -> bool:
	for d: Vector2i in doors:
		if absi(d.x - t.x) + absi(d.y - t.y) <= 1:
			return true
	return false

## Vertical rectangle centred on `c`, facing `n` (horizontal).
static func _face_rect(st: SurfaceTool, c: Vector3, n: Vector3, w: float, h: float, col: Color) -> void:
	var side := Vector3(-n.z, 0.0, n.x) * (w * 0.5)
	var up := Vector3(0.0, h * 0.5, 0.0)
	_quad(st, [c - side - up, c + side - up, c + side + up, c - side + up], col, n)

# ── Primitives (flat-shaded; materials render both sides) ───────────────────

## Like _tri/_quad but with texture coordinates given in world units (scaled
## by TEX_UNITS here).
static func _quad_uv(st: SurfaceTool, p: Array, uv: Array, col: Color, out: Vector3 = Vector3.ZERO) -> void:
	_tri_uv(st, p[0], p[1], p[2], uv[0], uv[1], uv[2], col, out)
	_tri_uv(st, p[0], p[2], p[3], uv[0], uv[2], uv[3], col, out)

static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, col: Color, out: Vector3 = Vector3.ZERO) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if (out != Vector3.ZERO and n.dot(out) < 0.0) or (out == Vector3.ZERO and n.y < -0.01):
		n = -n
	for pair: Array in [[a, ua], [b, ub], [c, uc]]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv((pair[1] as Vector2) / TEX_UNITS)
		st.add_vertex(pair[0] as Vector3)

## Box with planar UVs per face (horizontal along the face, v = -y on the sides).
static func _box_uv(st: SurfaceTool, lo: Vector3, hi: Vector3, col: Color) -> void:
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	var top_uv: Array = [Vector2(lo.x, lo.z), Vector2(hi.x, lo.z), Vector2(hi.x, hi.z), Vector2(lo.x, hi.z)]
	_quad_uv(st, [p[4], p[5], p[6], p[7]], top_uv, col)
	var mid: Vector3 = (lo + hi) * 0.5
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
	for f: Array in faces:
		var q: Array = []
		var uv: Array = []
		for i: Variant in f:
			var v: Vector3 = p[int(i)]
			q.append(v)
			uv.append(Vector2(v.x + v.z, -v.y))
		var out: Vector3 = ((q[0] as Vector3) + (q[2] as Vector3)) * 0.5 - mid
		out.y = 0.0
		_quad_uv(st, q, uv, col, out)

## `out` is the side the face should light from; ZERO means "from above".
static func _quad(st: SurfaceTool, p: Array, col: Color, out: Vector3 = Vector3.ZERO) -> void:
	_tri(st, p[0], p[1], p[2], col, out)
	_tri(st, p[0], p[2], p[3], col, out)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color,
		out: Vector3 = Vector3.ZERO) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if (out != Vector3.ZERO and n.dot(out) < 0.0) or (out == Vector3.ZERO and n.y < -0.01):
		n = -n
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(c)

static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, col: Color) -> void:
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	_quad(st, [p[4], p[5], p[6], p[7]], col)  # top
	var mid: Vector3 = (lo + hi) * 0.5
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
	for f: Array in faces:
		var a: Vector3 = p[int(f[0])]
		var b: Vector3 = p[int(f[1])]
		var c: Vector3 = p[int(f[2])]
		var d: Vector3 = p[int(f[3])]
		var out: Vector3 = (a + c) * 0.5 - mid
		out.y = 0.0
		_quad(st, [a, b, c, d], col, out)
