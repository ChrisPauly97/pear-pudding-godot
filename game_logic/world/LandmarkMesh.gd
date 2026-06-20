extends RefCounted

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

# Stone-grey base tint lightened slightly by biome wall tint.
static func _stone_color(biome: int) -> Color:
	var wt: Color = BiomeDef.WALL_TINT[biome % BiomeDef.COUNT]
	return Color(
		0.5 + wt.r * 0.3,
		0.48 + wt.g * 0.3,
		0.44 + wt.b * 0.3,
	)

# Build an ArrayMesh for the given variant.
# All geometry is relative to the landmark's local origin (y=0 at ground level).
static func build(variant: String, biome: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col: Color = _stone_color(biome)
	match variant:
		"obelisk_ring":   _build_obelisk_ring(st, col)
		"stone_head":     _build_stone_head(st, col)
		"kneeling_colossus": _build_kneeling_colossus(st, col)
		"shattered_spire": _build_shattered_spire(st, col)
		"broken_arch":    _build_broken_arch(st, col)
		_:                _build_obelisk_ring(st, col)
	st.generate_normals()
	return st.commit()

# Returns an approximate collision box size for the variant (width, height, depth).
static func collision_size(variant: String) -> Vector3:
	match variant:
		"obelisk_ring":      return Vector3(9.0, 8.0, 9.0)
		"stone_head":        return Vector3(6.0, 5.0, 6.0)
		"kneeling_colossus": return Vector3(5.0, 13.0, 5.0)
		"shattered_spire":   return Vector3(4.0, 14.0, 4.0)
		"broken_arch":       return Vector3(10.0, 10.0, 3.0)
	return Vector3(5.0, 10.0, 5.0)

# ── Primitive helpers ────────────────────────────────────────────────────────

# Adds a solid box (6 faces) to the surface tool.
# origin: bottom-center of the box.
static func _add_box(st: SurfaceTool, origin: Vector3, w: float, h: float, d: float, col: Color) -> void:
	var hx: float = w * 0.5
	var hz: float = d * 0.5
	# 8 corners
	var b000 := origin + Vector3(-hx, 0.0, -hz)
	var b100 := origin + Vector3( hx, 0.0, -hz)
	var b010 := origin + Vector3(-hx,   h, -hz)
	var b110 := origin + Vector3( hx,   h, -hz)
	var b001 := origin + Vector3(-hx, 0.0,  hz)
	var b101 := origin + Vector3( hx, 0.0,  hz)
	var b011 := origin + Vector3(-hx,   h,  hz)
	var b111 := origin + Vector3( hx,   h,  hz)
	_add_quad(st, b010, b110, b100, b000, col)  # front (-Z)
	_add_quad(st, b001, b101, b111, b011, col)  # back  (+Z)
	_add_quad(st, b000, b001, b011, b010, col)  # left  (-X)
	_add_quad(st, b110, b111, b101, b100, col)  # right (+X)
	_add_quad(st, b010, b011, b111, b110, col)  # top
	_add_quad(st, b000, b100, b101, b001, col)  # bottom

# Adds a tapered box (pillar wider at base, narrower at top) to the surface tool.
# origin: bottom-center.  w0/d0 = base width/depth, w1/d1 = top width/depth.
static func _add_tapered_box(st: SurfaceTool, origin: Vector3,
		w0: float, d0: float, w1: float, d1: float, h: float, col: Color) -> void:
	var hx0: float = w0 * 0.5;  var hz0: float = d0 * 0.5
	var hx1: float = w1 * 0.5;  var hz1: float = d1 * 0.5
	var b000 := origin + Vector3(-hx0, 0.0, -hz0)
	var b100 := origin + Vector3( hx0, 0.0, -hz0)
	var b010 := origin + Vector3(-hx1,    h, -hz1)
	var b110 := origin + Vector3( hx1,    h, -hz1)
	var b001 := origin + Vector3(-hx0, 0.0,  hz0)
	var b101 := origin + Vector3( hx0, 0.0,  hz0)
	var b011 := origin + Vector3(-hx1,    h,  hz1)
	var b111 := origin + Vector3( hx1,    h,  hz1)
	_add_quad(st, b010, b110, b100, b000, col)
	_add_quad(st, b001, b101, b111, b011, col)
	_add_quad(st, b000, b001, b011, b010, col)
	_add_quad(st, b110, b111, b101, b100, col)
	_add_quad(st, b010, b011, b111, b110, col)
	_add_quad(st, b000, b100, b101, b001, col)

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(c)
	st.set_color(col)
	st.add_vertex(d)

# ── Variant builders ─────────────────────────────────────────────────────────

# 8 tapered pillars in a ring, two toppled (lying on side)
static func _build_obelisk_ring(st: SurfaceTool, col: Color) -> void:
	var count: int = 8
	var radius: float = 4.0
	for i: int in range(count):
		var angle: float = float(i) / float(count) * TAU
		var px: float = cos(angle) * radius
		var pz: float = sin(angle) * radius
		var origin := Vector3(px, 0.0, pz)
		if i < 2:
			# Toppled — lay the pillar on its side along the tangent direction
			var tx: float = -sin(angle)
			var tz: float =  cos(angle)
			var fallen_origin := origin + Vector3(tx * -3.0, 0.05, tz * -3.0)
			# Horizontal box (height becomes Z depth since it's rotated logically)
			_add_box(st, fallen_origin, 0.7, 0.7, 7.0, col)
		else:
			_add_tapered_box(st, origin, 0.9, 0.9, 0.4, 0.4, 7.5, col)
	# Central altar slab
	_add_box(st, Vector3(-1.0, 0.0, -1.0), 2.0, 0.6, 2.0, col)

# Large boxy stone head, half-sunk into the ground
static func _build_stone_head(st: SurfaceTool, col: Color) -> void:
	var dark: Color = Color(col.r * 0.7, col.g * 0.7, col.b * 0.7)
	# Main head block — sits low (y offset -1.5 so bottom half is "underground")
	_add_box(st, Vector3(-2.5, -0.5, -2.5), 5.0, 4.5, 5.0, col)
	# Brow ridge
	_add_box(st, Vector3(-2.5, 4.0, -2.5), 5.0, 0.7, 1.4, col)
	# Left eye socket (dark recess)
	_add_box(st, Vector3(-2.0, 2.5, -2.8), 1.4, 1.0, 0.5, dark)
	# Right eye socket
	_add_box(st, Vector3( 0.6, 2.5, -2.8), 1.4, 1.0, 0.5, dark)
	# Nose
	_add_box(st, Vector3(-0.4, 1.5, -3.0), 0.8, 0.8, 0.6, col)

# Blocky kneeling giant figure, ~13 units tall
static func _build_kneeling_colossus(st: SurfaceTool, col: Color) -> void:
	# Left knee/shin on ground
	_add_box(st, Vector3(-1.6, 0.0, -0.8), 1.4, 3.0, 1.4, col)
	# Right leg extended back
	_add_box(st, Vector3( 0.2, 0.0, -1.0), 1.4, 2.0, 3.0, col)
	# Torso (wide, seated height)
	_add_box(st, Vector3(-1.8, 3.0, -1.0), 3.6, 5.0, 2.4, col)
	# Left arm reaching down (like bracing on the ground)
	_add_box(st, Vector3(-3.0, 0.5,  0.0), 1.2, 3.5, 1.2, col)
	# Right arm raised
	_add_box(st, Vector3( 1.8, 5.0, -0.8), 1.2, 4.5, 1.2, col)
	# Head
	_add_box(st, Vector3(-1.0, 8.0, -1.0), 2.0, 2.5, 2.0, col)

# Broken tapering spire, angled, debris at base
static func _build_shattered_spire(st: SurfaceTool, col: Color) -> void:
	var dark: Color = Color(col.r * 0.75, col.g * 0.75, col.b * 0.75)
	# Main spire column (slightly tilted by using an asymmetric tapered box)
	_add_tapered_box(st, Vector3(-0.7, 0.0, -0.7), 2.2, 2.2, 0.5, 0.5, 12.0, col)
	# Broken top chunk (offset to simulate tilt)
	_add_box(st, Vector3(0.5, 10.0, 0.5), 1.2, 2.0, 1.2, col)
	# Fallen debris slab 1
	_add_box(st, Vector3(-3.0, 0.0, -1.0), 3.5, 0.6, 1.5, dark)
	# Fallen debris slab 2
	_add_box(st, Vector3( 1.0, 0.0,  1.0), 2.5, 0.4, 1.0, dark)
	# Debris chunk
	_add_box(st, Vector3(-1.5, 0.4, 1.5), 1.2, 1.2, 1.2, dark)

# Two pylons with partial arch span — open centre
static func _build_broken_arch(st: SurfaceTool, col: Color) -> void:
	var span: float = 8.0
	var hspan: float = span * 0.5
	# Left pylon
	_add_tapered_box(st, Vector3(-hspan - 0.8, 0.0, -0.8), 1.6, 1.6, 1.1, 1.1, 10.0, col)
	# Right pylon
	_add_tapered_box(st, Vector3( hspan - 0.8, 0.0, -0.8), 1.6, 1.6, 1.1, 1.1, 10.0, col)
	# Left arch stone (remaining half of span)
	_add_box(st, Vector3(-hspan - 0.8, 9.0, -0.8), 3.5, 1.2, 1.6, col)
	# Right arch stone (fallen, resting on ground at angle — flat for simplicity)
	_add_box(st, Vector3(hspan - 1.5, 0.0, 1.5), 3.5, 0.5, 1.6, col)
