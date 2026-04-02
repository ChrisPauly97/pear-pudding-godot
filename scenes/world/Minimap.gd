# scenes/world/Minimap.gd
# WoW-style circular minimap rendered in the HUD top-right corner.
# Uses a SubViewport sharing the main World3D so the top-down camera
# sees the live scene without duplicating geometry.
# Tap/click the minimap to open the full-map view overlay.
extends Node

## Emitted when the player taps or clicks the minimap.
signal tapped

## World units from player centre to the edge of the circular view.
const VIEW_RADIUS: float = 64.0

var _mini_cam: Camera3D
var _dot_layer: _DotLayer
var _player: CharacterBody3D
var _enemy_nodes: Dictionary
var _chest_nodes: Dictionary
var _door_nodes: Dictionary
var _npc_nodes: Dictionary
var _half: float   # half the minimap pixel dimension
var _scale: float  # pixels per world unit


# ── Inner: draws entity dots each frame ───────────────────────────────────────
class _DotLayer extends Control:
	var minimap  # untyped — inner class can't reference the outer class by name

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if minimap and minimap._player:
			minimap._on_draw(self)


# ── Inner: gold ring border drawn once ────────────────────────────────────────
class _RingBorder extends Control:
	var ring_sz: int = 100

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = float(ring_sz) * 0.5
		var center := Vector2(r, r)
		# Outer gold ring
		draw_arc(center, r - 1.5, 0.0, TAU, 64, Color(0.72, 0.60, 0.22, 1.0), 4.0)
		# Inner dark bevel for depth
		draw_arc(center, r - 5.5, 0.0, TAU, 64, Color(0.12, 0.10, 0.04, 0.75), 1.5)


# ── Circle-clip shader: cuts the rectangular texture into a disc ───────────────
const _CLIP_SHADER_SRC := """
shader_type canvas_item;
void fragment() {
	vec2 c = UV - vec2(0.5, 0.5);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= step(length(c) * 2.0, 0.98);
}
"""


# Call once from WorldScene._ready() after the player is spawned.
func setup(world: Node3D, hud: CanvasLayer, player: CharacterBody3D,
		enemies: Dictionary, chests: Dictionary, doors: Dictionary,
		npcs: Dictionary) -> void:
	_player  = player
	_enemy_nodes = enemies
	_chest_nodes = chests
	_door_nodes  = doors
	_npc_nodes   = npcs

	var vp_size: Vector2 = world.get_viewport().get_visible_rect().size
	var vw: float = vp_size.x
	var vh: float = vp_size.y
	var sz: int = int(vh * 0.18)          # minimap diameter in pixels
	_half  = float(sz) * 0.5
	_scale = float(sz) / (VIEW_RADIUS * 2.0)

	var margin: float = vh * 0.01
	# Sit below the inventory button (btn_h ≈ vh*0.07, starts at vh*0.01 → bottom ≈ vh*0.08)
	var px: float = vw - float(sz) - margin
	var py: float = vh * 0.095

	# ── Dark background ────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.03, 0.88)
	bg.size = Vector2(float(sz), float(sz))
	bg.position = Vector2(px, py)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bg)

	# ── SubViewport that shares the main scene's World3D ──────────────────────
	var viewport := SubViewport.new()
	viewport.size = Vector2i(sz, sz)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = false   # share the live World3D — sees the same geometry

	_mini_cam = Camera3D.new()
	_mini_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_mini_cam.size = VIEW_RADIUS * 2.0
	# Pitch –90° so the camera looks straight down; +45° yaw aligns minimap-up
	# with isometric screen-up (world NW = (−1,0,−1)).
	_mini_cam.rotation_degrees = Vector3(-90.0, 45.0, 0.0)
	_mini_cam.position = Vector3(0.0, 200.0, 0.0)
	viewport.add_child(_mini_cam)

	# ── SubViewportContainer with circle-clip shader ───────────────────────────
	var container := SubViewportContainer.new()
	container.size = Vector2(float(sz), float(sz))
	container.position = Vector2(px, py)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(viewport)
	var shader := Shader.new()
	shader.code = _CLIP_SHADER_SRC
	var mat := ShaderMaterial.new()
	mat.shader = shader
	container.material = mat
	hud.add_child(container)

	# ── Entity/player dot overlay ──────────────────────────────────────────────
	_dot_layer = _DotLayer.new()
	_dot_layer.minimap = self
	_dot_layer.size = Vector2(float(sz), float(sz))
	_dot_layer.position = Vector2(px, py)
	hud.add_child(_dot_layer)

	# ── Gold ring border ───────────────────────────────────────────────────────
	var ring := _RingBorder.new()
	ring.ring_sz = sz
	ring.size = Vector2(float(sz), float(sz))
	ring.position = Vector2(px, py)
	hud.add_child(ring)

	# ── Transparent tap target (mobile + mouse) ───────────────────────────────
	# Sits above all other minimap children so it intercepts input first.
	var tap_btn := Button.new()
	tap_btn.flat = true
	tap_btn.size = Vector2(float(sz), float(sz))
	tap_btn.position = Vector2(px, py)
	tap_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tap_btn.pressed.connect(func() -> void: tapped.emit())
	hud.add_child(tap_btn)

	# "N" label removed — after the 45° rotation the top of the minimap is
	# isometric screen-up (world NW), not geographic north.


# Call every frame from WorldScene._process().
func update() -> void:
	if _player == null or _mini_cam == null:
		return
	_mini_cam.position = Vector3(_player.position.x, 200.0, _player.position.z)
	if _dot_layer:
		_dot_layer.queue_redraw()


# Called by _DotLayer._draw() — runs inside the CanvasItem draw pass.
func _on_draw(canvas: Control) -> void:
	var center := Vector2(_half, _half)
	var origin: Vector3 = _player.position

	# White dot at centre = player
	canvas.draw_circle(center, 5.0, Color(1.0, 1.0, 1.0))

	_draw_group(canvas, _enemy_nodes, origin, Color(0.95, 0.20, 0.20), 4.0)  # red
	_draw_group(canvas, _chest_nodes, origin, Color(1.00, 0.85, 0.10), 4.0)  # gold
	_draw_group(canvas, _door_nodes,  origin, Color(0.55, 0.75, 1.00), 4.0)  # blue
	_draw_group(canvas, _npc_nodes,   origin, Color(0.30, 0.95, 0.45), 4.0)  # green


func _draw_group(canvas: Control, nodes: Dictionary, origin: Vector3,
		color: Color, radius: float) -> void:
	var center := Vector2(_half, _half)
	for id in nodes:
		var n: Node3D = nodes[id]
		if not is_instance_valid(n):
			continue
		var off: Vector3 = n.position - origin
		# Rotate +45° to match the isometric camera's −45° azimuth:
		# iso screen-right = world NE (+x,0,−z), iso screen-up = world NW (−x,0,−z).
		const ROT45: float = 0.7071067811865476
		var rx: float = (off.x - off.z) * ROT45
		var ry: float = (off.x + off.z) * ROT45
		var dot := Vector2(_half + rx * _scale, _half + ry * _scale)
		# Only draw dots that fall inside the circle
		if (dot - center).length() <= _half * 0.94:
			canvas.draw_circle(dot, radius, color)
