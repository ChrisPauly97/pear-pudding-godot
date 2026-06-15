## CompassRibbon — horizontal 360° bearing ribbon for the HUD.
##
## Add to HUD CanvasLayer, set size/position from the caller, then call setup().
## Marker API: add_marker / remove_marker / set_current_map.
extends Control

const _TICKS: Array = [
	{"label": "N", "dx": 0.0, "dz": -1.0},
	{"label": "E", "dx": 1.0, "dz": 0.0},
	{"label": "S", "dx": 0.0, "dz": 1.0},
	{"label": "W", "dx": -1.0, "dz": 0.0},
]

var _player: CharacterBody3D = null
var _markers: Dictionary = {}  # id -> {color, get_pos, map}
var _current_map: String = "main"


func setup(player: CharacterBody3D) -> void:
	_player = player


func add_marker(id: String, color: Color, get_pos: Callable, map: String = "") -> void:
	_markers[id] = {"color": color, "get_pos": get_pos, "map": map}


func remove_marker(id: String) -> void:
	_markers.erase(id)


func set_current_map(map_name: String) -> void:
	_current_map = map_name


## Maps a world-space bearing atan2(dz, dx) to a ribbon X coordinate.
## bearing -PI/4 (iso screen-right / NE) → ribbon_center.
## Wraps continuously; SW (3PI/4) appears at both left and right edges.
## N/E/S/W land at equal intervals (each ribbon_width/4 apart).
static func bearing_to_ribbon_x(bearing_rad: float, ribbon_center: float, ribbon_width: float) -> float:
	var offset: float = fposmod(bearing_rad + PI / 4.0 + PI, TAU) - PI
	return ribbon_center + offset / PI * (ribbon_width * 0.5)


## Pure static helper — computes marker ribbon X from world positions.
## Useful for tests without needing a scene-tree instance.
static func compute_marker_ribbon_x(
		player_pos: Vector3, target_pos: Vector3,
		ribbon_center: float, ribbon_width: float, off_map: bool) -> float:
	var dx: float = target_pos.x - player_pos.x
	var dz: float = target_pos.z - player_pos.z
	if dx == 0.0 and dz == 0.0:
		return ribbon_center
	var bearing: float = atan2(dz, dx)
	var rx: float = bearing_to_ribbon_x(bearing, ribbon_center, ribbon_width)
	if off_map:
		return 0.0 if rx < ribbon_center else ribbon_width
	return clampf(rx, 0.0, ribbon_width)


func _draw() -> void:
	var rw: float = size.x
	var rh: float = size.y
	var rc: float = rw * 0.5

	# Background
	draw_rect(Rect2(0.0, 0.0, rw, rh), Color(0.05, 0.05, 0.10, 0.70))

	# N/E/S/W tick marks
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(rh * 0.65)
	for entry in _TICKS:
		var bearing: float = atan2(float(entry["dz"]), float(entry["dx"]))
		var rx: float = bearing_to_ribbon_x(bearing, rc, rw)
		if rx < 0.0 or rx > rw:
			continue
		draw_line(Vector2(rx, 0.0), Vector2(rx, rh * 0.35), Color(1.0, 1.0, 1.0, 0.85), 1.5)
		var label: String = str(entry["label"])
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(rx - tw * 0.5, rh * 0.95), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.90))

	# Center reference line (NE iso-right direction)
	draw_line(Vector2(rc, 0.0), Vector2(rc, rh), Color(1.0, 1.0, 1.0, 0.25), 1.0)

	if _player == null:
		return

	# Marker dots
	for id in _markers:
		var m: Dictionary = _markers[id]
		var get_pos: Callable = m.get("get_pos", Callable())
		if not get_pos.is_valid():
			continue
		var raw = get_pos.call()
		if raw == null:
			continue
		var target: Vector3 = raw as Vector3
		var map_name: String = str(m.get("map", ""))
		var off_map: bool = map_name != "" and map_name != _current_map
		var rx: float = compute_marker_ribbon_x(_player.position, target, rc, rw, off_map)
		var color: Color = m.get("color", Color.WHITE)
		draw_circle(Vector2(rx, rh * 0.60), rh * 0.28, color)


func _process(_delta: float) -> void:
	queue_redraw()
