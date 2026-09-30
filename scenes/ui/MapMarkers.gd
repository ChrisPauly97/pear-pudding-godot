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
