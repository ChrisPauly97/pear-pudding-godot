# scenes/ui/MapViewOverlay.gd
# Full-map view overlay toggled by the M key when in a named map.
# Shows the 100×100 tile grid as a color-coded image with entity dots on top.
extends CanvasLayer

signal closed

# Tile color palette
const _COL_GRASS := Color(0.28, 0.55, 0.22)
const _COL_WALL  := Color(0.30, 0.25, 0.20)
const _COL_HILL  := Color(0.55, 0.42, 0.22)
const _COL_PATH  := Color(0.62, 0.52, 0.35)
const _COL_UNK   := Color(0.10, 0.10, 0.10)

# Entity dot colours
const _DOT_PLAYER   := Color(1.00, 1.00, 1.00)
const _DOT_ENEMY    := Color(0.95, 0.20, 0.20)
const _DOT_CHEST    := Color(1.00, 0.85, 0.10)
const _DOT_DOOR     := Color(0.55, 0.75, 1.00)
const _DOT_NPC      := Color(0.30, 0.95, 0.45)
const _DOT_MERCHANT := Color(0.20, 0.90, 0.90)

var _player: CharacterBody3D
var _npc_nodes: Dictionary
var _npc_data: Dictionary
var _enemy_nodes: Dictionary
var _chest_nodes: Dictionary
var _door_nodes: Dictionary

var _panel_pos: Vector2
var _panel_size: float
var _dot_layer: _DotLayer


# ── Inner dot-drawing layer ───────────────────────────────────────────────────
class _DotLayer extends Control:
	var overlay  # untyped — inner class cannot reference outer by name

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if overlay:
			overlay._on_draw(self)


# ─────────────────────────────────────────────────────────────────────────────

func setup(world_map, map_name: String, player: CharacterBody3D,
		npc_nodes: Dictionary, npc_data: Dictionary,
		enemy_nodes: Dictionary, chest_nodes: Dictionary,
		door_nodes: Dictionary) -> void:
	_player      = player
	_npc_nodes   = npc_nodes
	_npc_data    = npc_data
	_enemy_nodes = enemy_nodes
	_chest_nodes = chest_nodes
	_door_nodes  = door_nodes

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x
	_panel_size = minf(vw, vh) * 0.80
	_panel_pos = Vector2((vw - _panel_size) * 0.5, (vh - _panel_size) * 0.5)

	# ── Dim background ────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.70)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ── Panel ─────────────────────────────────────────────────────────────────
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.10, 1.0)
	panel.size = Vector2(_panel_size, _panel_size)
	panel.position = _panel_pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# ── Tile grid image ───────────────────────────────────────────────────────
	var tex: ImageTexture = _build_map_texture(world_map)
	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.size = Vector2(_panel_size, _panel_size)
	tex_rect.position = _panel_pos
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex_rect)

	# ── Entity dot layer ──────────────────────────────────────────────────────
	_dot_layer = _DotLayer.new()
	_dot_layer.overlay = self
	_dot_layer.size = vp
	_dot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dot_layer)

	# ── Title label ───────────────────────────────────────────────────────────
	var font_size: int = int(vh * 0.025)
	var title := Label.new()
	title.text = map_name.capitalize().replace("_", " ")
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(_panel_size, font_size * 1.6)
	title.position = Vector2(_panel_pos.x, _panel_pos.y - font_size * 1.8)
	add_child(title)

	# ── Close hint ────────────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text = "[M] or [Esc] to close"
	hint.add_theme_font_size_override("font_size", int(vh * 0.020))
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(_panel_size, int(vh * 0.030))
	hint.position = Vector2(_panel_pos.x, _panel_pos.y + _panel_size + int(vh * 0.008))
	add_child(hint)


func _build_map_texture(world_map) -> ImageTexture:
	var img := Image.create(100, 100, false, Image.FORMAT_RGB8)
	for tz in range(100):
		for tx in range(100):
			var tile: int = world_map.get_tile(tx, tz)
			img.set_pixel(tx, tz, _tile_color(tile))
	return ImageTexture.create_from_image(img)


func _tile_color(tile: int) -> Color:
	match tile:
		IsoConst.TILE_GRASS: return _COL_GRASS
		IsoConst.TILE_WALL:  return _COL_WALL
		IsoConst.TILE_HILL:  return _COL_HILL
		IsoConst.TILE_PATH:  return _COL_PATH
		_:                   return _COL_UNK


# Called by _DotLayer._draw()
func _on_draw(canvas: Control) -> void:
	# Entity nodes carry world positions; convert to tile coords then panel pixels.
	_draw_group(canvas, _enemy_nodes, _DOT_ENEMY, 4.0, false)
	_draw_group(canvas, _chest_nodes, _DOT_CHEST, 4.0, false)
	_draw_group(canvas, _door_nodes,  _DOT_DOOR,  4.0, false)
	_draw_npcs(canvas)
	# Player last so it's on top
	if is_instance_valid(_player):
		var tp: Vector2 = _world_to_panel(_player.position.x, _player.position.z)
		canvas.draw_circle(tp, 6.0, _DOT_PLAYER)


func _draw_group(canvas: Control, nodes: Dictionary, color: Color,
		radius: float, _unused: bool) -> void:
	for id in nodes:
		var n: Node3D = nodes[id]
		if not is_instance_valid(n):
			continue
		var tp: Vector2 = _world_to_panel(n.position.x, n.position.z)
		canvas.draw_circle(tp, radius, color)


func _draw_npcs(canvas: Control) -> void:
	for id in _npc_nodes:
		var n: Node3D = _npc_nodes[id]
		if not is_instance_valid(n):
			continue
		var data: Dictionary = _npc_data.get(id, {})
		var is_merchant: bool = str(data.get("npc_type", "")) == "merchant"
		var col: Color = _DOT_MERCHANT if is_merchant else _DOT_NPC
		var tp: Vector2 = _world_to_panel(n.position.x, n.position.z)
		canvas.draw_circle(tp, 4.0, col)


func _world_to_panel(wx: float, wz: float) -> Vector2:
	var tx: float = wx / IsoConst.TILE_SIZE
	var tz: float = wz / IsoConst.TILE_SIZE
	var px: float = _panel_pos.x + (tx / 100.0) * _panel_size
	var pz: float = _panel_pos.y + (tz / 100.0) * _panel_size
	return Vector2(px, pz)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_view") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
