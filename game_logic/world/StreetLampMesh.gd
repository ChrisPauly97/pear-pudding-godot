## StreetLampMesh — a grimy iron street lamp for the stitched towns' streets.
##
## A soot-stained stone plinth, a rust-flecked iron post, and a caged lantern of
## smoky amber glass under a pyramid cap. Surface 0 is the iron and stone,
## surface 1 the glass (its shader glows at night, darker where soot gathers
## at the top). Vertex colours carry the grime, so one shared mesh serves every
## lamp. Pure geometry in world units (y = 0 is the ground). No scene tree.
extends RefCounted

## Where the light sits: the middle of the lantern glass.
const LIGHT_HEIGHT: float = 3.0

const _IRON := Color(0.17, 0.15, 0.13)
const _RUST := Color(0.33, 0.19, 0.1)
const _STONE := Color(0.3, 0.28, 0.25)
const _SOOT := Color(0.12, 0.11, 0.1)
const _GLASS := Color(0.95, 0.68, 0.32)
const _GLASS_SOOT := Color(0.32, 0.22, 0.12)

static var _mesh: ArrayMesh = null

## The shared lamp mesh, built once.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(iron, Vector3(0, 0.0, 0), Vector3(0.46, 0.18, 0.46), _SOOT, _STONE)
	_box(iron, Vector3(0, 0.18, 0), Vector3(0.36, 0.14, 0.36), _STONE, _SOOT)
	_box(iron, Vector3(0, 0.32, 0), Vector3(0.13, 2.38, 0.13), _RUST, _IRON)
	_box(iron, Vector3(0, 0.95, 0), Vector3(0.19, 0.08, 0.19), _IRON, _RUST)
	_box(iron, Vector3(0, 2.7, 0), Vector3(0.26, 0.08, 0.26), _RUST, _IRON)
	for sx: float in [-0.165, 0.165]:
		for sz: float in [-0.165, 0.165]:
			_box(iron, Vector3(sx, 2.76, sz), Vector3(0.05, 0.5, 0.05), _IRON, _SOOT)
	_box(iron, Vector3(0, 3.24, 0), Vector3(0.46, 0.05, 0.46), _IRON, _SOOT)
	_pyramid(iron, 3.29, 3.58, 0.21, _IRON, _SOOT)
	_box(iron, Vector3(0, 3.56, 0), Vector3(0.06, 0.12, 0.06), _RUST, _SOOT)
	iron.generate_normals()
	_mesh = iron.commit()
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(glass, Vector3(0, 2.78, 0), Vector3(0.3, 0.46, 0.3), _GLASS, _GLASS_SOOT)
	glass.generate_normals()
	glass.commit(_mesh)
	return _mesh

## Axis-aligned box resting on `base` (its bottom-centre), coloured `bottom`
## at its foot fading to `top` at its head.
static func _box(st: SurfaceTool, base: Vector3, size: Vector3, bottom: Color, top: Color) -> void:
	var h := Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	var y0: float = base.y
	var y1: float = base.y + size.y
	var c := [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]
	for i: int in range(4):
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var off := Vector3(base.x, 0.0, base.z)
		_quad(st, off + a + Vector3(0, y0, 0), off + b + Vector3(0, y0, 0),
				off + b + Vector3(0, y1, 0), off + a + Vector3(0, y1, 0), bottom, top)
	var o := Vector3(base.x, 0.0, base.z)
	var p0: Vector3 = c[0]
	var p1: Vector3 = c[1]
	var p2: Vector3 = c[2]
	var p3: Vector3 = c[3]
	_quad(st, o + p0 + Vector3(0, y1, 0), o + p1 + Vector3(0, y1, 0),
			o + p2 + Vector3(0, y1, 0), o + p3 + Vector3(0, y1, 0), top, top)

## Four-sided cap from a square of half-width `half` at `y0` to an apex at `y1`.
static func _pyramid(st: SurfaceTool, y0: float, y1: float, half: float, bottom: Color, top: Color) -> void:
	var c := [Vector3(-half, y0, -half), Vector3(half, y0, -half), Vector3(half, y0, half), Vector3(-half, y0, half)]
	var apex := Vector3(0, y1, 0)
	for i: int in range(4):
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		st.set_color(bottom)
		st.add_vertex(a)
		st.add_vertex(b)
		st.set_color(top)
		st.add_vertex(apex)

## Quad a-b-c-d (clockwise seen from outside — Godot's front face): a/b take
## `lo`, c/d take `hi`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		lo: Color, hi: Color) -> void:
	for v: Array in [[a, lo], [b, lo], [c, hi], [a, lo], [c, hi], [d, hi]]:
		st.set_color(v[1])
		st.add_vertex(v[0])
