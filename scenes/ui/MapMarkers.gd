## Marker shapes shared by every map view — the HUD minimap, the named-map
## overlay (MapViewOverlay) and the overworld realm map (RealmMapOverlay).
## Positions and sizes stay caller-owned; this only draws.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")
const _QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const _QuestZones = preload("res://game_logic/quests/QuestZones.gd")
const _ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")

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

## A quest giver's "!" / "?" (QuestTracker marks): outlined text on a dark disc,
## ringed and haloed in the mark's colour so it stands out over busy map art.
static func draw_quest_mark(canvas: CanvasItem, at: Vector2, text: String, col: Color, size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var half: float = size * 0.62
	canvas.draw_circle(at, half + OUTLINE_PX * 4.0, Color(col, 0.25))
	canvas.draw_circle(at, half + OUTLINE_PX, Color(0.0, 0.0, 0.0, 0.85))
	canvas.draw_arc(at, half + OUTLINE_PX, 0.0, TAU, 32, col, 2.5, true)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := at + Vector2(-w * 0.5, size * 0.36)
	canvas.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color.BLACK)
	canvas.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## A quest area outline (panel px): a translucent fill with a solid rim.
## `clip` (optional polygon) trims it, e.g. to the minimap's round face.
static func draw_zone(canvas: CanvasItem, outline: PackedVector2Array, col: Color,
		clip: PackedVector2Array = PackedVector2Array()) -> void:
	var polys: Array[PackedVector2Array] = [outline]
	if not clip.is_empty():
		polys = Geometry2D.intersect_polygons(outline, clip)
	for poly: PackedVector2Array in polys:
		if poly.size() < 3:
			continue
		canvas.draw_colored_polygon(poly, Color(col, 0.22))
		var edge := poly.duplicate()
		edge.append(poly[0])
		canvas.draw_polyline(edge, Color(col, 0.85), 2.0, true)

## Every quest's areas (QuestLog.zones) that lie on `map_name`. `to_panel` maps a
## world Vector3 to panel px for the calling view.
static func draw_quest_zones(canvas: CanvasItem, quests: Array[Dictionary], map_name: String,
		to_panel: Callable, clip: PackedVector2Array = PackedVector2Array()) -> void:
	for q: Dictionary in quests:
		var col: Color = _QuestLog.kind_color(str(q.get("kind", "")))
		for z: Dictionary in _QuestLog.zones(q):
			var at: Variant = _ObjectiveTracker.target_world_pos(z, map_name)
			if at == null:
				continue
			var centre: Vector3 = at
			var px := PackedVector2Array()
			for off: Vector2 in _QuestZones.outline(z):
				var w := centre + Vector3(off.x, 0.0, off.y) * IsoConst.TILE_SIZE
				var v: Vector2 = to_panel.call(w)
				px.append(v)
			draw_zone(canvas, px, col, clip)
