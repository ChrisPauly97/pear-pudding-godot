# scenes/ui/RealmMapOverlay.gd
# Realm map for the overworld (GID-140), toggled by M / a minimap tap. The
# named-map MapViewOverlay draws a 100×100 tile grid; the overworld is infinite,
# so this draws the stitched story realm (RealmLayout) as a vector map instead:
# towns, the roads between them, waystones, the player and every quest pin.
# North (−Z) is up. Right-click / long-press sets the custom waypoint.
extends CanvasLayer

signal closed

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const _MapMarkers = preload("res://scenes/ui/MapMarkers.gd")
const _RealmMapOverlay = preload("res://scenes/ui/RealmMapOverlay.gd")

const _COL_BG := Color(0.13, 0.19, 0.12)
const _COL_ROAD := Color(0.70, 0.58, 0.38)
const _COL_TOWN := Color(0.46, 0.40, 0.30)
const _COL_TOWN_EDGE := Color(0.85, 0.75, 0.52)
const _COL_WAYSTONE := Color(0.40, 0.90, 1.00)
const _COL_WAYPOINT := Color(0.20, 0.80, 1.00)
## Tiles of wilderness shown around the realm's outline.
const _MARGIN_TILES: float = 32.0
const _LP_THRESHOLD: float = 0.5
const _LP_SLOP_PX: float = 12.0

class _MapLayer extends Control:
	var overlay: _RealmMapOverlay

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if overlay:
			overlay._on_draw(self)

var _player: Node3D
var _map_name: String = "main"
var _quests: Array[Dictionary] = []
var _tracked_id: String = ""
var _panel := Rect2()
var _bounds := Rect2()   # in overworld tiles
var _scale: float = 1.0  # panel px per tile
var _font_size: int = 12
var _layer: _MapLayer
var _lp_active: bool = false
var _lp_pos: Vector2 = Vector2.ZERO
var _lp_elapsed: float = 0.0


func setup(player: Node3D, map_name: String, quests: Array[Dictionary], tracked: Dictionary) -> void:
	_player = player
	_map_name = map_name
	_quests = quests
	_tracked_id = str(tracked.get("id", ""))
	layer = 20

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var side: float = minf(vp.x, vh) * 0.80
	_panel = Rect2((vp - Vector2(side, side)) * 0.5, Vector2(side, side))
	_font_size = int(vh * 0.020)
	_bounds = realm_bounds(_extra_tiles())
	_scale = side / maxf(_bounds.size.x, _bounds.size.y)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.70)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_layer = _MapLayer.new()
	_layer.overlay = self
	_layer.size = vp
	add_child(_layer)

	var title := _UiUtil.make_title_label("The Realm", vh)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(side, vh * 0.045)
	title.position = Vector2(_panel.position.x, _panel.position.y + vh * 0.008)
	add_child(title)

	var obj_text: String = str(tracked.get("label", ""))
	if obj_text != "":
		var obj := _UiUtil.make_label("Tracking: " + obj_text, _font_size, Color(1.0, 0.85, 0.2),
			HORIZONTAL_ALIGNMENT_CENTER, self)
		obj.size = Vector2(side, vh * 0.03)
		obj.position = Vector2(_panel.position.x, _panel.end.y + vh * 0.008)

	var hint_text: String = ("Tap outside to close · hold to set a waypoint" if OS.has_feature("android")
		else "[M] or [Esc] to close · right-click to set a waypoint")
	var hint := _UiUtil.make_label(hint_text, int(vh * 0.017), Color(0.75, 0.75, 0.75),
		HORIZONTAL_ALIGNMENT_CENTER, self)
	hint.size = Vector2(side, vh * 0.03)
	hint.position = Vector2(_panel.position.x, _panel.end.y + vh * 0.04)

	var close_btn := _UiUtil.make_button("X", Vector2(vh * 0.055, vh * 0.055), int(vh * 0.028), _close, self)
	close_btn.position = Vector2(_panel.end.x - vh * 0.065, _panel.position.y + vh * 0.01)


## Tile rect covering every town, road and story site, padded, grown to include
## `extra` tiles (the player, quest targets) and made square.
static func realm_bounds(extra: Array[Vector2] = []) -> Rect2:
	var r := Rect2()
	var first: bool = true
	for town: String in _RealmLayout.town_names():
		var wr: Rect2i = _RealmLayout.world_rect(town)
		var tr := Rect2(Vector2(wr.position), Vector2(wr.size))
		r = tr if first else r.merge(tr)
		first = false
	for road: Array in _RealmLayout.ROADS:
		for p: Vector2 in road:
			r = r.expand(p)
	for p: Vector2 in extra:
		r = r.expand(p)
	r = r.grow(_MARGIN_TILES)
	var side: float = maxf(r.size.x, r.size.y)
	return Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func _extra_tiles() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if is_instance_valid(_player):
		out.append(_world_to_tile(_player.position))
	for q: Dictionary in _quests:
		var raw: Variant = _QuestLog.world_pos(q, _map_name, _player_pos())
		if raw != null:
			out.append(_world_to_tile(raw as Vector3))
	return out


func _player_pos() -> Vector3:
	return _player.position if is_instance_valid(_player) else Vector3.ZERO


static func _world_to_tile(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) / IsoConst.TILE_SIZE


func _tile_to_panel(t: Vector2) -> Vector2:
	return _panel.position + (t - _bounds.position) * _scale


func _panel_to_tile(p: Vector2) -> Vector2:
	return (p - _panel.position) / _scale + _bounds.position


func _on_draw(c: Control) -> void:
	c.draw_rect(_panel, _COL_BG)
	var font: Font = ThemeDB.fallback_font
	for road: Array in _RealmLayout.ROADS:
		var pts := PackedVector2Array()
		for p: Vector2 in road:
			pts.append(_tile_to_panel(p))
		c.draw_polyline(pts, _COL_ROAD, maxf(2.0, _scale * 2.0), true)
	for town: String in _RealmLayout.town_names():
		var wr: Rect2i = _RealmLayout.world_rect(town)
		var rect := Rect2(_tile_to_panel(Vector2(wr.position)), Vector2(wr.size) * _scale)
		c.draw_rect(rect, _COL_TOWN)
		c.draw_rect(rect, _COL_TOWN_EDGE, false, 2.0)
		var name_text: String = town.replace("_", " ").capitalize()
		c.draw_string(font, Vector2(rect.position.x, rect.get_center().y + _font_size * 0.35), name_text,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, _font_size, Color.WHITE)
	var lit: Array = SceneManager.save_manager.activated_waystones
	for w: Dictionary in _RealmLayout.entities("waystones"):
		var wp: Vector2 = _tile_to_panel(Vector2(float(w.get("x", 0.0)), float(w.get("z", 0.0))) / IsoConst.TILE_SIZE)
		var on: bool = lit.has(str(w.get("id", "")))
		c.draw_circle(wp, 4.0, _COL_WAYSTONE if on else Color(_COL_WAYSTONE, 0.4))
	_draw_waypoint(c)
	_draw_quests(c, font)
	if is_instance_valid(_player):
		var pp: Vector2 = _tile_to_panel(_world_to_tile(_player.position))
		c.draw_circle(pp, 8.0, Color.BLACK)
		c.draw_circle(pp, 6.0, Color.WHITE)


func _draw_waypoint(c: Control) -> void:
	var wp: Dictionary = SceneManager.save_manager.waypoint
	if wp.is_empty() or not _RealmLayout.is_overworld(str(wp.get("map", ""))):
		return
	var tp: Vector2 = _tile_to_panel(Vector2(float(int(wp.get("tx", 0))) + 0.5, float(int(wp.get("tz", 0))) + 0.5))
	_MapMarkers.draw_pin(c, tp, 6.0, _COL_WAYPOINT)


func _draw_quests(c: Control, font: Font) -> void:
	for q: Dictionary in _quests:
		var raw: Variant = _QuestLog.world_pos(q, _map_name, _player_pos())
		if raw == null:
			continue
		var tp: Vector2 = _tile_to_panel(_world_to_tile(raw as Vector3))
		var tracked: bool = str(q.get("id", "")) == _tracked_id
		var r: float = 10.0 if tracked else 6.0
		var col: Color = _QuestLog.kind_color(str(q.get("kind", "")))
		_MapMarkers.draw_outlined_diamond(c, tp, r, col)
		if tracked:
			c.draw_string_outline(font, tp + Vector2(r + 4.0, _font_size * 0.35), str(q.get("label", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 4, Color.BLACK)
			c.draw_string(font, tp + Vector2(r + 4.0, _font_size * 0.35), str(q.get("label", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, col)


func _set_waypoint_at(screen_pos: Vector2) -> void:
	var t: Vector2 = _panel_to_tile(screen_pos)
	SceneManager.save_manager.set_waypoint({"map": _map_name, "tx": int(floor(t.x)), "tz": int(floor(t.y))})


func _close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if _lp_active:
		_lp_elapsed += delta
		if _lp_elapsed >= _LP_THRESHOLD:
			_lp_active = false
			_set_waypoint_at(_lp_pos)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_RIGHT and _panel.has_point(mb.position):
			_set_waypoint_at(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not _panel.has_point(mb.position):
			get_viewport().set_input_as_handled()
			_close()
		return
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed and _panel.has_point(st.position):
			_lp_active = true
			_lp_elapsed = 0.0
			_lp_pos = st.position
		elif st.pressed:
			get_viewport().set_input_as_handled()
			_close()
		else:
			_lp_active = false
		return
	var sd := event as InputEventScreenDrag
	if sd != null and _lp_active and sd.position.distance_to(_lp_pos) > _LP_SLOP_PX:
		_lp_active = false
