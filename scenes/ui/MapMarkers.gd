## Marker shapes shared by every map view — the HUD minimap, the named-map
## overlay (MapViewOverlay) and the overworld realm map (RealmMapOverlay).
## Positions and sizes stay caller-owned; this only draws.
extends RefCounted

## Pixels the black backing extends past an outlined diamond.
const OUTLINE_PX: float = 2.0
## Half-length of the waypoint pin's crosshair arms.
const PIN_ARM_PX: float = 9.0

static func diamond(at: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(0.0, -r), at + Vector2(r, 0.0), at + Vector2(0.0, r), at + Vector2(-r, 0.0)])

static func draw_diamond(canvas: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	canvas.draw_colored_polygon(diamond(at, r), col)

## A quest diamond on a dark backing so it reads over any terrain colour.
static func draw_outlined_diamond(canvas: CanvasItem, at: Vector2, r: float, col: Color,
		outline: Color = Color.BLACK) -> void:
	draw_diamond(canvas, at, r + OUTLINE_PX, outline)
	draw_diamond(canvas, at, r, col)

## The player-set waypoint: a filled dot with a crosshair through it.
static func draw_pin(canvas: CanvasItem, at: Vector2, radius: float, col: Color) -> void:
	canvas.draw_circle(at, radius, col)
	canvas.draw_line(at + Vector2(0.0, -PIN_ARM_PX), at + Vector2(0.0, PIN_ARM_PX), col, 1.5)
	canvas.draw_line(at + Vector2(-PIN_ARM_PX, 0.0), at + Vector2(PIN_ARM_PX, 0.0), col, 1.5)

## A quest giver's "!" / "?" (QuestTracker marks) as outlined text on a dark disc.
static func draw_quest_mark(canvas: CanvasItem, at: Vector2, text: String, col: Color, size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var half: float = size * 0.62
	canvas.draw_circle(at, half + OUTLINE_PX, Color(0.0, 0.0, 0.0, 0.75))
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := at + Vector2(-w * 0.5, size * 0.36)
	canvas.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	canvas.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## A quest's area (QuestLog.zone_tiles): a translucent disc with a solid rim.
## `clip` (optional polygon) trims it, e.g. to the minimap's round face.
static func draw_zone(canvas: CanvasItem, at: Vector2, r: float, col: Color,
		clip: PackedVector2Array = PackedVector2Array()) -> void:
	var ring := PackedVector2Array()
	for i: int in range(40):
		ring.append(at + Vector2.from_angle(TAU * i / 40.0) * r)
	var polys: Array[PackedVector2Array] = [ring]
	if not clip.is_empty():
		polys = Geometry2D.intersect_polygons(ring, clip)
	for poly: PackedVector2Array in polys:
		canvas.draw_colored_polygon(poly, Color(col, 0.22))
		var edge := poly.duplicate()
		edge.append(poly[0])
		canvas.draw_polyline(edge, Color(col, 0.85), 2.0, true)
