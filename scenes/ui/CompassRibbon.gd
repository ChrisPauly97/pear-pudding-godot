## Compass ribbon HUD — bearing markers relative to the fixed isometric camera.
## The camera faces NE (−45° bearing), so NE always appears at the ribbon centre.
## Markers slide left/right as the player moves relative to each target.
extends Control

# Marker registry: id -> {color: Color, get_pos: Callable}
# get_pos() must return Vector3 (world pos) or null (hidden).
var _markers: Dictionary = {}
var _marker_positions: Dictionary = {}  # id -> float (local ribbon X)
var _player: Node3D = null
var _current_map: String = "main"

# ---------------------------------------------------------------------------
# Static / pure functions — testable without a scene tree
# ---------------------------------------------------------------------------

## Convert world-space bearing (radians, atan2 convention) to ribbon local X.
## NE direction (−45° = −π/4 rad) maps to the ribbon centre (ribbon_width / 2).
static func bearing_to_ribbon_x(bearing_rad: float, ribbon_width: float) -> float:
	var bearing_deg: float = rad_to_deg(bearing_rad)
	var ribbon_center: float = ribbon_width * 0.5
	var x: float = ribbon_center + (bearing_deg + 45.0) / 360.0 * ribbon_width
	return clamp(x, 0.0, ribbon_width)

## Compute world-space bearing in radians from (from_x, from_z) to (to_x, to_z).
static func compute_bearing(from_x: float, from_z: float, to_x: float, to_z: float) -> float:
	return atan2(to_z - from_z, to_x - from_x)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func setup(player: Node3D) -> void:
	_player = player
	_apply_viewport_size()

func _apply_viewport_size() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vw: float = vp.x
	var vh: float = vp.y
	var ribbon_w: float = vw * 0.40
	var ribbon_h: float = vh * 0.04
	custom_minimum_size = Vector2(ribbon_w, ribbon_h)
	size = Vector2(ribbon_w, ribbon_h)
	position = Vector2((vw - ribbon_w) * 0.5, vh * 0.01)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_viewport_size()

# ---------------------------------------------------------------------------
# Marker API
# ---------------------------------------------------------------------------

func add_marker(id: String, color: Color, get_pos: Callable) -> void:
	_markers[id] = {"color": color, "get_pos": get_pos}

func remove_marker(id: String) -> void:
	_markers.erase(id)
	_marker_positions.erase(id)

func set_current_map(map_name: String) -> void:
	_current_map = map_name

# ---------------------------------------------------------------------------
# Update & draw
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	_marker_positions.clear()
	for id: String in _markers:
		var entry: Dictionary = _markers[id]
		var raw: Variant = entry["get_pos"].call()
		if raw == null:
			continue
		var target: Vector3 = raw as Vector3
		var bearing: float = compute_bearing(pp.x, pp.z, target.x, target.z)
		_marker_positions[id] = bearing_to_ribbon_x(bearing, size.x)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var vh: float = get_viewport().get_visible_rect().size.y
	var font_size: int = int(vh * 0.018)

	# Background + border
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.08, 0.08, 0.08, 0.72))
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.55, 0.55, 0.55, 0.80), false, 1.0)

	# Centre line — fixed isometric NE facing
	var cx: float = w * 0.5
	draw_line(Vector2(cx, h * 0.05), Vector2(cx, h * 0.55), Color(1.0, 1.0, 1.0, 0.45), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(cx - 2.0, h * 0.98),
		"^", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.45))

	# Cardinal ticks — W, S, (NE center), E, N
	# Bearings in radians using atan2 convention (0=East, π/2=+Z, −π/2=−Z)
	var ticks: Array = [
		[-PI,        "W"],
		[-PI * 0.5,  "S"],
		[0.0,        "E"],
		[PI * 0.5,   "N"],
	]
	for tick: Array in ticks:
		var tx: float = bearing_to_ribbon_x(tick[0], w)
		draw_line(Vector2(tx, 0.0), Vector2(tx, h * 0.45), Color(0.75, 0.75, 0.75, 0.85), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(tx - 4.0, h * 0.98),
			tick[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.75, 0.75, 0.75, 0.90))

	# Marker dots
	for id: String in _marker_positions:
		var mx: float = _marker_positions[id]
		var color: Color = _markers[id]["color"]
		draw_circle(Vector2(mx, h * 0.5), h * 0.22, color)
