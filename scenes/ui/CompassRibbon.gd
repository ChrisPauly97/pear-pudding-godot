## Compass ribbon HUD — bearing markers relative to the fixed isometric camera.
##
## The camera's baked azimuth (WorldScene.tscn) points its horizontal look
## direction along (−1, 0, −1): world **north-west** under the game's compass
## convention (−Z = North, +X = East — the same one the minimap uses, whose top
## is likewise world NW). NW therefore sits at the ribbon centre, N a quarter
## width to the right of it and W a quarter width to the left, which is exactly
## where the player sees those directions on screen.
##
## The ribbon never rotates (the camera cannot); only the marker positions move
## as the player travels relative to each target.
extends Control

# Marker registry: id -> {color: Color, get_pos: Callable, get_label: Callable,
#                        primary: bool}
# get_pos() must return Vector3 (world pos) or null (hidden).
var _markers: Dictionary = {}
# id -> {x: float, dist: float, label: String}
var _marker_positions: Dictionary = {}
var _player: Node3D = null
var _current_map: String = "main"
var _time: float = 0.0
var _band_h: float = 0.0

## Bearing (atan2 degrees, 0 = +X = East) the camera looks along: its horizontal
## forward, (−1, 0, −1) → −135°. `test_compass_bearing` re-derives this straight
## from the baked Camera3D transform in WorldScene.tscn, so the ribbon and the
## camera cannot drift apart.
const FACING_BEARING_DEG: float = -135.0

## Degrees of bearing spanned by the full ribbon width. A full turn keeps every
## target on the ribbon: a marker at either edge is directly behind the camera.
const SPAN_DEG: float = 360.0

# ---------------------------------------------------------------------------
# Static / pure functions — testable without a scene tree
# ---------------------------------------------------------------------------

## Convert world-space bearing (radians, atan2 convention) to ribbon local X.
## The camera's facing (world NW) maps to the ribbon centre; bearings to its
## right on screen land right of centre, and the mapping wraps rather than
## clamping, so the full ribbon width is used.
static func bearing_to_ribbon_x(bearing_rad: float, ribbon_width: float) -> float:
	var offset_deg: float = wrapf(rad_to_deg(bearing_rad) - FACING_BEARING_DEG, -180.0, 180.0)
	var x: float = ribbon_width * 0.5 + offset_deg / SPAN_DEG * ribbon_width
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
	var ribbon_w: float = vw * 0.44
	# Tall enough that the objective chevron sits clear of the tick captions.
	_band_h = vh * 0.048
	# The band plus one caption line underneath it (objective name + distance).
	var total_h: float = _band_h + vh * 0.040
	custom_minimum_size = Vector2(ribbon_w, total_h)
	size = Vector2(ribbon_w, total_h)
	position = Vector2((vw - ribbon_w) * 0.5, vh * 0.01)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_viewport_size()

# ---------------------------------------------------------------------------
# Marker API
# ---------------------------------------------------------------------------

## Register a marker. `get_pos` is polled every frame and returns a Vector3 world
## position or null to hide the marker.
##
## `primary` markers (the story objective) are drawn as a labelled chevron with a
## live distance readout instead of a plain dot — a 6-pixel dot among the tick
## marks was not readable as "this is where you are going". `get_label`, when
## given, is polled for that caption.
func add_marker(id: String, color: Color, get_pos: Callable,
		get_label: Callable = Callable(), primary: bool = false) -> void:
	_markers[id] = {
		"color": color,
		"get_pos": get_pos,
		"get_label": get_label,
		"primary": primary,
	}

func remove_marker(id: String) -> void:
	_markers.erase(id)
	_marker_positions.erase(id)

func set_current_map(map_name: String) -> void:
	_current_map = map_name

# ---------------------------------------------------------------------------
# Update & draw
# ---------------------------------------------------------------------------

## Cardinal / intercardinal marks, in atan2 degrees (0 = East/+X, −90 = North/−Z).
## Entry: [bearing_deg, label, is_major].
const _CARDINAL_TICKS: Array = [
	[-90.0,  "N",  true],
	[-45.0,  "NE", false],
	[0.0,    "E",  true],
	[45.0,   "SE", false],
	[90.0,   "S",  true],
	[135.0,  "SW", false],
	[180.0,  "W",  true],
	[-135.0, "NW", false],
]

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_time += delta
	var pp: Vector3 = _player.global_position
	_marker_positions.clear()
	for id: String in _markers:
		var entry: Dictionary = _markers[id]
		var raw: Variant = entry["get_pos"].call()
		if raw == null:
			continue
		var target: Vector3 = raw as Vector3
		var bearing: float = compute_bearing(pp.x, pp.z, target.x, target.z)
		var label: String = ""
		var get_label: Callable = entry["get_label"]
		if get_label.is_valid():
			label = str(get_label.call())
		_marker_positions[id] = {
			"x": bearing_to_ribbon_x(bearing, size.x),
			"dist": Vector2(target.x - pp.x, target.z - pp.z).length(),
			"label": label,
		}
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = _band_h
	var vh: float = get_viewport().get_visible_rect().size.y
	var font_size: int = int(vh * 0.018)

	# Background + border
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.08, 0.08, 0.08, 0.82))
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.55, 0.55, 0.55, 0.80), false, 1.0)

	# Centre line — the direction the isometric camera looks along (world NW)
	var cx: float = w * 0.5
	draw_line(Vector2(cx, 0.0), Vector2(cx, h), Color(1.0, 1.0, 1.0, 0.45), 1.0)

	for tick: Array in _CARDINAL_TICKS:
		var deg: float = tick[0]
		var tick_name: String = tick[1]
		var major: bool = tick[2]
		var tx: float = bearing_to_ribbon_x(deg_to_rad(deg), w)
		var alpha: float = 0.90 if major else 0.55
		draw_line(Vector2(tx, 0.0), Vector2(tx, h * (0.40 if major else 0.25)),
			Color(0.85, 0.85, 0.85, alpha), 1.0)
		_draw_centered(tick_name, tx, h * 0.97,
			font_size if major else int(font_size * 0.8),
			Color(0.92, 0.92, 0.92, alpha))

	# Plain markers first, the primary one on top of them.
	for id: String in _marker_positions:
		if not bool(_markers[id]["primary"]):
			_draw_dot_marker(_marker_positions[id], _markers[id]["color"], h)
	for id: String in _marker_positions:
		if bool(_markers[id]["primary"]):
			_draw_primary_marker(_marker_positions[id], _markers[id]["color"], h, font_size)

## A plain waypoint-style dot, outlined so it stays readable over a tick mark.
func _draw_dot_marker(entry: Dictionary, color: Color, h: float) -> void:
	var mx: float = entry["x"]
	var r: float = h * 0.24
	draw_circle(Vector2(mx, h * 0.5), r + 1.5, Color(0.0, 0.0, 0.0, 0.65))
	draw_circle(Vector2(mx, h * 0.5), r, color)

## The story objective: a pulsing chevron on the band plus a caption underneath
## carrying the objective text and the live distance.
func _draw_primary_marker(entry: Dictionary, color: Color, h: float, font_size: int) -> void:
	# Kept in the upper half of the band: the tick captions own the lower half.
	var mx: float = entry["x"]
	var cy: float = h * 0.32
	var s: float = h * 0.26
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.2)

	draw_circle(Vector2(mx, cy), s * (1.5 + 0.35 * pulse), Color(color.r, color.g, color.b, 0.20))
	draw_line(Vector2(mx, 0.0), Vector2(mx, h * 0.62), Color(color.r, color.g, color.b, 0.75), 1.0)

	var pts := PackedVector2Array([
		Vector2(mx - s, cy - s * 0.85),
		Vector2(mx + s, cy - s * 0.85),
		Vector2(mx, cy + s * 1.05),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
		Color(0.0, 0.0, 0.0, 0.85), 1.5)

	var caption: String = _shorten(str(entry["label"]))
	var dist_m: int = int(round(float(entry["dist"])))
	if caption != "":
		caption = "%s — %dm" % [caption, dist_m]
	else:
		caption = "%dm" % dist_m
	# On its own dark pill: the caption sits over open world, and gold-on-grass
	# with only an outline was still a squint at 720p.
	var cap_font: int = int(font_size * 1.15)
	var font: Font = ThemeDB.fallback_font
	var cap_w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_font).x
	var pill_h: float = cap_font * 1.5
	var pill := Rect2((size.x - cap_w) * 0.5 - cap_font * 0.5, h + 2.0,
		cap_w + cap_font, pill_h)
	draw_rect(pill, Color(0.08, 0.08, 0.08, 0.72))
	draw_rect(pill, Color(color.r, color.g, color.b, 0.55), false, 1.0)
	_draw_centered(caption, size.x * 0.5, pill.position.y + pill_h * 0.74, cap_font, color)

## Draws `text` centred on `cx`, kept inside the ribbon when it fits.
func _draw_centered(text: String, cx: float, y: float, font_size: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x: float = cx - tw * 0.5
	if tw < size.x:
		x = clamp(x, 0.0, size.x - tw)
	var pos := Vector2(x, y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3,
		Color(0.0, 0.0, 0.0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

const _CAPTION_MAX_CHARS: int = 34

static func _shorten(text: String) -> String:
	if text.length() <= _CAPTION_MAX_CHARS:
		return text
	return text.substr(0, _CAPTION_MAX_CHARS - 1).strip_edges() + "…"
