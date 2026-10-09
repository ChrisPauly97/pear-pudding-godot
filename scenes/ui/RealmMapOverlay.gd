# scenes/ui/RealmMapOverlay.gd
# Realm map for the overworld (GID-140), toggled by M / a minimap tap, and from an
# interior's map ("World Map"). The named-map MapViewOverlay draws a 100×100 tile
# grid; the overworld is infinite, so this draws the stitched story realm
# (RealmLayout) as a vector map instead: towns, the roads between them,
# waystones, the player, quest areas and every quest pin.
# WoW-style zoom: opens on the player's surroundings; wheel / pinch / +/− zoom,
# drag pans, "World" shows the whole realm. North (−Z) is up. Right-click /
# long-press sets the custom waypoint.
extends CanvasLayer

signal closed
## The Fast Travel button: the minimap tap used to open fast travel here.
signal fast_travel_requested

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _UiTheme = preload("res://scenes/ui/UiTheme.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const _LongPressTracker = preload("res://scenes/ui/LongPressTracker.gd")
const _MapMarkers = preload("res://scenes/ui/MapMarkers.gd")
const _RealmMapOverlay = preload("res://scenes/ui/RealmMapOverlay.gd")

const _Coast = preload("res://game_logic/world/Coast.gd")
const _RealmMapArt = preload("res://game_logic/world/RealmMapArt.gd")
const _RealmMapBaked = preload("res://game_logic/world/RealmMapBaked.gd")
const _COL_BG := Color(0.13, 0.19, 0.12)
const _COL_ROAD := Color(0.70, 0.58, 0.38)
const _COL_SEA := Color(0.16, 0.33, 0.48)
const _COL_TOWN := Color(0.46, 0.40, 0.30)
const _COL_TOWN_EDGE := Color(0.85, 0.75, 0.52)
const _COL_WAYSTONE := Color(0.40, 0.90, 1.00)
const _COL_WAYPOINT := Color(0.20, 0.80, 1.00)
## Zoom 1 = the whole realm (world overview); the map opens at OPEN_ZOOM on the player.
const MAX_ZOOM: float = 8.0
const OPEN_ZOOM: float = 4.0
const _WHEEL_STEP: float = 1.25
## Charting budget per frame while the map is open and the art isn't ready yet.
const _ART_OPEN_BUDGET_USEC: int = 12000

class _MapLayer extends Control:
	var overlay: _RealmMapOverlay

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if overlay:
			draw_set_transform(-position)  # draw in viewport coords, clipped to the panel
			overlay._on_draw(self)

# Painted map art (RealmMapArt), charted once per world seed a few ms per frame
# (QuestTracker steps it from world load) and shared by every realm map after.
static var _art_seed: int = -1
static var _painter: _RealmMapArt.Painter = null
static var _terrain_tex: Texture2D = null
static var _terrain_rect := Rect2i()
static var _town_tex: Dictionary = {}

var _player: Node3D
var _map_name: String = "main"
var _quests: Array[Dictionary] = []
var _tracked_id: String = ""
## Quest givers' "!" / "?" (QuestTracker.npc_map_marks).
var _npc_marks: Array[Dictionary] = []
var _panel := Rect2()
var _bounds := Rect2()   # in overworld tiles
var _scale: float = 1.0  # panel px per tile
var _base_scale: float = 1.0  # _scale at zoom 1
var _zoom: float = 1.0
var _center := Vector2.ZERO  # view centre, in overworld tiles
## Where the hero is in the overworld when the map was opened indoors (tiles), or null.
var _anchor: Variant = null
## Touch index → position, for one-finger pan and two-finger pinch.
var _touches: Dictionary = {}
var _drag_from: Variant = null  # mouse drag-pan start, or null
var _font_size: int = 12
var _layer: _MapLayer
var _long_press := _LongPressTracker.new()


## `map_name` is where the hero stands; indoors (not the overworld) pass
## `anchor`, the overworld spot (world Vector3) they went in at, or null.
func setup(player: Node3D, map_name: String, quests: Array[Dictionary], tracked: Dictionary,
		npc_marks: Array[Dictionary] = [], anchor: Variant = null) -> void:
	var outdoors: bool = _RealmLayout.is_overworld(map_name)
	_player = player if outdoors else null
	_npc_marks = npc_marks if outdoors else []
	_anchor = _world_to_tile(anchor as Vector3) if not outdoors and anchor is Vector3 else null
	_quests = quests
	_tracked_id = str(tracked.get("id", ""))
	layer = 20
	prewarm(SceneManager.save_manager.world_seed)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var side: float = minf(vp.x, vh) * 0.80
	_panel = Rect2((vp - Vector2(side, side)) * 0.5, Vector2(side, side))
	_font_size = int(vh * 0.020)
	_bounds = realm_bounds(_extra_tiles())
	_base_scale = side / maxf(_bounds.size.x, _bounds.size.y)
	var here: Variant = _player_tile()
	if here != null:
		_set_view(OPEN_ZOOM, here as Vector2)
	else:
		_set_view(1.0, _bounds.get_center())

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.70)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_layer = _MapLayer.new()
	_layer.overlay = self
	_layer.position = _panel.position
	_layer.size = _panel.size
	_layer.clip_contents = true
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_layer)

	var title := _UiUtil.make_title_label("The Realm", vh)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(side, vh * 0.045)
	title.position = Vector2(_panel.position.x, _panel.position.y - vh * 0.055)
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

	var travel_btn := _UiUtil.make_button("Fast Travel", Vector2(vh * 0.16, vh * 0.05), int(vh * 0.020),
		_on_fast_travel, self)
	travel_btn.position = Vector2(_panel.position.x + vh * 0.01, _panel.position.y + vh * 0.01)

	# Zoom controls down the panel's right edge (touch parity for wheel / pinch).
	var zb := Vector2(vh * 0.055, vh * 0.055)
	var zx: float = _panel.end.x - vh * 0.065
	var zoom_in := _UiUtil.make_button("+", zb, int(vh * 0.028), func() -> void: _zoom_by(1.6, _panel.get_center()),
		self)
	zoom_in.position = Vector2(zx, _panel.position.y + vh * 0.08)
	var zoom_out := _UiUtil.make_button("−", zb, int(vh * 0.028),
		func() -> void: _zoom_by(1.0 / 1.6, _panel.get_center()), self)
	zoom_out.position = Vector2(zx, _panel.position.y + vh * 0.145)
	var world_btn := _UiUtil.make_button("World", Vector2(vh * 0.10, vh * 0.05), int(vh * 0.018),
		func() -> void: _set_view(1.0, _bounds.get_center()), self)
	world_btn.position = Vector2(_panel.end.x - vh * 0.11, _panel.end.y - vh * 0.06)
	var me_btn := _UiUtil.make_button("Me", Vector2(vh * 0.08, vh * 0.05), int(vh * 0.018), _center_on_player, self)
	me_btn.position = Vector2(_panel.end.x - vh * 0.20, _panel.end.y - vh * 0.06)


## Starts charting the map art for `world_seed` (no-op once started).
static func prewarm(world_seed: int) -> void:
	if _art_seed == world_seed:
		return
	_art_seed = world_seed
	_terrain_tex = null
	_town_tex = {}
	_terrain_rect = _RealmMapArt.terrain_rect()
	# Baked at build time (tools/bake_realm_map.gd) for every start seed: instant.
	var baked: Texture2D = _RealmMapBaked.terrain(world_seed)
	if baked != null and _RealmMapBaked.RECT == _terrain_rect:
		_terrain_tex = baked
		_town_tex = _RealmMapBaked.towns()
		_painter = null
		return
	_painter = _RealmMapArt.Painter.new(_terrain_rect, world_seed)


## Charts for up to `budget_usec`; when done, turns the images into mipmapped
## textures. True once the art is ready.
static func step_art(budget_usec: int) -> bool:
	if _terrain_tex != null:
		return true
	if _painter == null or not _painter.step(budget_usec):
		return false
	_terrain_tex = _mipmapped(_painter.terrain)
	for town: String in _painter.towns:
		_town_tex[town] = _mipmapped(_painter.towns[town] as Image)
	_painter = null
	return true


static func _mipmapped(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Tile rect covering every town, road and story site, padded, grown to include
## `extra` tiles (the player, quest targets) and made square (RealmMapArt).
static func realm_bounds(extra: Array[Vector2] = []) -> Rect2:
	return _RealmMapArt.realm_bounds(extra)


func _extra_tiles() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var here: Variant = _player_tile()
	if here != null:
		out.append(here as Vector2)
	for q: Dictionary in _quests:
		var raw: Variant = _QuestLog.world_pos(q, _map_name, _player_pos())
		if raw != null:
			out.append(_world_to_tile(raw as Vector3))
	return out


func _player_pos() -> Vector3:
	var t: Variant = _player_tile()
	if t == null:
		return Vector3.ZERO
	var v: Vector2 = (t as Vector2) * IsoConst.TILE_SIZE
	return Vector3(v.x, 0.0, v.y)


## The hero's overworld tile: live outdoors, the way-in spot indoors, else null.
func _player_tile() -> Variant:
	if is_instance_valid(_player):
		return _world_to_tile(_player.position)
	return _anchor


static func _world_to_tile(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) / IsoConst.TILE_SIZE


func _tile_to_panel(t: Vector2) -> Vector2:
	return _panel.get_center() + (t - _center) * _scale


## Zoom (1 … MAX_ZOOM) and view centre, kept so the realm never leaves the panel.
func _set_view(zoom: float, center: Vector2) -> void:
	_zoom = clampf(zoom, 1.0, MAX_ZOOM)
	_scale = _base_scale * _zoom
	var half: Vector2 = _panel.size * 0.5 / _scale
	var lo: Vector2 = _bounds.position + half
	var hi: Vector2 = _bounds.end - half
	_center = Vector2(clampf(center.x, lo.x, maxf(lo.x, hi.x)), clampf(center.y, lo.y, maxf(lo.y, hi.y)))
	if _zoom <= 1.0:
		_center = _bounds.get_center()


## Zoom by `factor`, keeping the tile under screen point `at` fixed.
func _zoom_by(factor: float, at: Vector2) -> void:
	var pinned: Vector2 = _panel_to_tile(at)
	var z: float = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	var new_scale: float = _base_scale * z
	_set_view(z, pinned - (at - _panel.get_center()) / new_scale)


func _pan_by(screen_delta: Vector2) -> void:
	_set_view(_zoom, _center - screen_delta / _scale)


func _center_on_player() -> void:
	var here: Variant = _player_tile()
	if here != null:
		_set_view(maxf(_zoom, OPEN_ZOOM), here as Vector2)


## The eastern sea (Coast, GID-171), clipped to the map panel.
func _draw_sea(c: Control) -> void:
	var pts := PackedVector2Array()
	for t: Vector2 in _Coast.SHORE:
		pts.append(_tile_to_panel(t))
	var frame := PackedVector2Array([_panel.position, Vector2(_panel.end.x, _panel.position.y), _panel.end,
		Vector2(_panel.position.x, _panel.end.y)])
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(pts, frame):
		c.draw_colored_polygon(poly, _COL_SEA)


func _panel_to_tile(p: Vector2) -> Vector2:
	return (p - _panel.get_center()) / _scale + _center


func _on_draw(c: Control) -> void:
	c.draw_rect(_panel, _COL_BG)
	var font: Font = ThemeDB.fallback_font
	_draw_sea(c)
	var painted: bool = step_art(_ART_OPEN_BUDGET_USEC)
	if painted:
		# The painted terrain holds the rivers too (RealmMapArt reads WaterMath.sea_at, GID-172).
		c.draw_texture_rect(_terrain_tex, Rect2(_tile_to_panel(Vector2(_terrain_rect.position)),
			Vector2(_terrain_rect.size) * _scale), false)
	else:
		for road: Array in _RealmLayout.ROADS:
			var pts := PackedVector2Array()
			for p: Vector2 in road:
				pts.append(_tile_to_panel(p))
			c.draw_polyline(pts, _COL_ROAD, clampf(_scale * 2.0, 2.0, 6.0), true)
		c.draw_string(font, Vector2(_panel.position.x, _panel.end.y - _font_size * 2.5), "Charting the realm…",
			HORIZONTAL_ALIGNMENT_CENTER, _panel.size.x, _font_size, Color(1, 1, 1, 0.7))
	for town: String in _RealmLayout.town_names():
		var wr: Rect2i = _RealmLayout.world_rect(town)
		var rect := Rect2(_tile_to_panel(Vector2(wr.position)), Vector2(wr.size) * _scale)
		var art: Texture2D = _town_tex.get(town) as Texture2D if painted else null
		if art != null:
			c.draw_texture_rect(art, rect, false)
		else:
			c.draw_rect(rect, _COL_TOWN)
		c.draw_rect(rect, _COL_TOWN_EDGE, false, 2.0)
		_draw_town_banner(c, font, town, rect)
	var lit: Array = SceneManager.save_manager.activated_waystones
	for w: Dictionary in _RealmLayout.entities("waystones"):
		var wp: Vector2 = _tile_to_panel(Vector2(float(w.get("x", 0.0)), float(w.get("z", 0.0))) / IsoConst.TILE_SIZE)
		var on: bool = lit.has(str(w.get("id", "")))
		c.draw_circle(wp, 4.0, _COL_WAYSTONE if on else Color(_COL_WAYSTONE, 0.4))
	_draw_waypoint(c)
	_draw_quests(c, font)
	for m: Dictionary in _npc_marks:
		var mp: Vector2 = _tile_to_panel(_world_to_tile(m["pos"] as Vector3))
		if _panel.has_point(mp):
			_MapMarkers.draw_quest_mark(c, mp, str(m["text"]), m["color"] as Color, _font_size + 8)
	var here: Variant = _player_tile()
	if here != null:
		var pp: Vector2 = _tile_to_panel(here as Vector2)
		c.draw_circle(pp, 8.0, Color.BLACK)
		c.draw_circle(pp, 6.0, Color.WHITE)


## The town's name above its plan in the Cinzel title face, gold on a dark
## outline, growing a little as the map zooms in.
func _draw_town_banner(c: Control, _font: Font, town: String, rect: Rect2) -> void:
	var font: Font = _UiTheme.title_font()
	var text: String = town.replace("_", " ").capitalize()
	var fs: int = int(_font_size * lerpf(1.25, 2.0, (_zoom - 1.0) / (MAX_ZOOM - 1.0)))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(rect.get_center().x - tw * 0.5, rect.position.y - fs * 0.30)
	# Zoomed into a town, its top edge leaves the panel: keep the name on screen
	# while any of the town is (clamped to the visible part of its plan).
	var seen: Rect2 = rect.intersection(_panel)
	if seen.has_area():
		var top: float = _panel.position.y + _font_size * 4.5 + fs  # below the button row
		if rect.position.y < _panel.position.y and at.y < top:
			at.y = minf(top, maxf(seen.end.y - fs * 0.3, _panel.position.y + fs))
			at.x = seen.get_center().x - tw * 0.5
		at.x = clampf(at.x, _panel.position.x + 4.0, maxf(_panel.position.x + 4.0, _panel.end.x - tw - 4.0))
	c.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 4),
		Color(0.10, 0.06, 0.03, 0.95))
	c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.52))


func _draw_waypoint(c: Control) -> void:
	var wp: Dictionary = SceneManager.save_manager.waypoint
	if wp.is_empty() or not _RealmLayout.is_overworld(str(wp.get("map", ""))):
		return
	var tp: Vector2 = _tile_to_panel(Vector2(float(int(wp.get("tx", 0))) + 0.5, float(int(wp.get("tz", 0))) + 0.5))
	_MapMarkers.draw_pin(c, tp, 6.0, _COL_WAYPOINT)


func _draw_quests(c: Control, font: Font) -> void:
	_MapMarkers.draw_quest_zones(c, _quests, "main",
		func(w: Vector3) -> Vector2: return _tile_to_panel(_world_to_tile(w)))
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
	SceneManager.save_manager.set_waypoint({"map": "main", "tx": int(floor(t.x)), "tz": int(floor(t.y))})


func _on_fast_travel() -> void:
	fast_travel_requested.emit()
	_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if _long_press.tick(delta):
		_set_waypoint_at(_long_press.start_pos)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
		return
	var mag := event as InputEventMagnifyGesture
	if mag != null:
		_zoom_by(mag.factor, mag.position)
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		_on_mouse_button(mb)
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drag_from != null:
		_pan_by(mm.position - (_drag_from as Vector2))
		_drag_from = mm.position
		get_viewport().set_input_as_handled()
		return
	var st := event as InputEventScreenTouch
	if st != null:
		_on_touch(st)
		return
	var sd := event as InputEventScreenDrag
	if sd != null and _touches.has(sd.index):
		_on_touch_drag(sd)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	var inside: bool = _panel.has_point(mb.position)
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and inside:
		_zoom_by(_WHEEL_STEP, mb.position)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and inside:
		_zoom_by(1.0 / _WHEEL_STEP, mb.position)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and inside:
		_set_waypoint_at(mb.position)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if not mb.pressed:
			_drag_from = null
			return
		if not inside:
			get_viewport().set_input_as_handled()
			_close()
			return
		_drag_from = mb.position
	else:
		return
	get_viewport().set_input_as_handled()


func _on_touch(st: InputEventScreenTouch) -> void:
	if not st.pressed:
		_touches.erase(st.index)
		_long_press.cancel()
		return
	if not _panel.has_point(st.position):
		get_viewport().set_input_as_handled()
		_close()
		return
	_touches[st.index] = st.position
	if _touches.size() == 1:
		_long_press.press(st.position)
	else:
		_long_press.cancel()


## One finger pans; two fingers pinch-zoom about their midpoint.
func _on_touch_drag(sd: InputEventScreenDrag) -> void:
	var before: Vector2 = _touches[sd.index]
	if _touches.size() >= 2:
		var other: Vector2 = Vector2.ZERO
		for k: Variant in _touches:
			if int(k) != sd.index:
				other = _touches[k]
				break
		var d0: float = before.distance_to(other)
		var d1: float = sd.position.distance_to(other)
		if d0 > 1.0:
			_zoom_by(d1 / d0, (sd.position + other) * 0.5)
	else:
		_long_press.move(sd.position)
		_pan_by(sd.position - before)
	_touches[sd.index] = sd.position
	get_viewport().set_input_as_handled()
