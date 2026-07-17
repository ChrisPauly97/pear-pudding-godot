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
## Render-target oversampling factor: the SubViewport renders at display size ×
## this, and the container scales it back down — the linear minification acts
## as anti-aliasing, so terrain edges and props stop shimmering.
const SUPERSAMPLE: int = 2
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _GrassBlades = preload("res://scenes/world/GrassBlades.gd")

var _mini_cam: Camera3D
var _mini_viewport: SubViewport
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
		draw_arc(center, r - 1.5, 0.0, TAU, 64, Color(0.72, 0.60, 0.22, 1.0), 4.0, true)
		# Inner dark bevel for depth
		draw_arc(center, r - 5.5, 0.0, TAU, 64, Color(0.12, 0.10, 0.04, 0.75), 1.5, true)


# ── Circle-clip shader: cuts the rectangular texture into a disc ───────────────
const _CLIP_SHADER_SRC := """
shader_type canvas_item;
void fragment() {
	vec2 c = UV - vec2(0.5, 0.5);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(0.955, 0.985, length(c) * 2.0);
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
	var sz: int = int(vh * 0.20)          # minimap diameter in pixels
	_half  = float(sz) * 0.5
	_scale = float(sz) / (VIEW_RADIUS * 2.0)

	# Safe-area insets keep the minimap clear of cutouts (GID-120 / TID-455).
	var ins: Dictionary = _UiUtil.safe_insets(world.get_viewport())
	var margin: float = vh * 0.01
	var px: float = vw - float(sz) - margin - float(ins.get("right", 0.0))
	var py: float = margin + float(ins.get("top", 0.0))   # top-right corner

	# ── Dark background ────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.03, 0.88)
	bg.size = Vector2(float(sz), float(sz))
	bg.position = Vector2(px, py)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bg)

	# ── SubViewport that shares the main scene's World3D ──────────────────────
	var vp_px: int = sz * SUPERSAMPLE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(vp_px, vp_px)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.own_world_3d = false   # share the live World3D — sees the same geometry
	_mini_viewport = viewport

	_mini_cam = Camera3D.new()
	_mini_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_mini_cam.size = VIEW_RADIUS * 2.0
	# Pitch –90° so the camera looks straight down; +45° yaw aligns minimap-up
	# with isometric screen-up (world NW = (−1,0,−1)).
	_mini_cam.rotation_degrees = Vector3(-90.0, 45.0, 0.0)
	_mini_cam.position = Vector3(0.0, 200.0, 0.0)
	_mini_cam.near = 1.0
	_mini_cam.far = 400.0
	# The shared World3D environment is tuned for the isometric camera — its
	# distance fog reads as a grey haze from 200 units straight up, and its glow
	# post-process is wasted work at minimap scale. Override with a clean
	# environment: no fog, no glow, flat dark background, and a constant bright
	# ambient so the map stays readable at night.
	var mini_env := Environment.new()
	mini_env.background_mode = Environment.BG_COLOR
	mini_env.background_color = Color(0.04, 0.07, 0.03)
	mini_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	mini_env.ambient_light_color = Color(0.75, 0.75, 0.75)
	mini_env.ambient_light_energy = 1.0
	_mini_cam.environment = mini_env
	# Grass blades live on their own render layer — from the top the terrain's
	# baked grass texture is the readable signal; thousands of blade instances
	# are pure noise and GPU cost at map scale.
	_mini_cam.cull_mask = 0xFFFFF & ~_GrassBlades.RENDER_LAYER
	viewport.add_child(_mini_cam)

	# ── SubViewportContainer with circle-clip shader ───────────────────────────
	# Sized to the oversampled render target, scaled back down for display —
	# the linear downsample is what smooths the picture.
	var container := SubViewportContainer.new()
	container.size = Vector2(float(vp_px), float(vp_px))
	container.scale = Vector2.ONE / float(SUPERSAMPLE)
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


const _MINIMAP_UPDATE_EVERY: int = 4   # render every 4th frame (~15 Hz at 60 fps)
var _minimap_frame_counter: int = 0

# Call every frame from WorldScene._process().
func update() -> void:
	if _player == null or _mini_cam == null:
		return
	_mini_cam.position = Vector3(_player.position.x, 200.0, _player.position.z)
	_minimap_frame_counter += 1
	if _minimap_frame_counter >= _MINIMAP_UPDATE_EVERY:
		_minimap_frame_counter = 0
		if _mini_viewport:
			_mini_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _dot_layer:
		_dot_layer.queue_redraw()


# Called by _DotLayer._draw() — runs inside the CanvasItem draw pass.
func _on_draw(canvas: Control) -> void:
	var center := Vector2(_half, _half)
	var origin: Vector3 = _player.position

	# White dot at centre = player
	canvas.draw_circle(center, 5.0, Color(1.0, 1.0, 1.0), true, -1.0, true)

	_draw_enemy_nodes(canvas, origin)
	_draw_group(canvas, _chest_nodes, origin, Color(1.00, 0.85, 0.10), 4.0)
	_draw_group(canvas, _door_nodes,  origin, Color(0.55, 0.75, 1.00), 4.0)
	_draw_group(canvas, _npc_nodes,   origin, Color(0.30, 0.95, 0.45), 4.0)
	_draw_waypoint(canvas, origin)

	# Roaming boss: larger dot in range, edge indicator when outside
	if _enemy_nodes.has("roaming_boss"):
		var boss: Node3D = _enemy_nodes["roaming_boss"] as Node3D
		if boss != null and is_instance_valid(boss):
			_draw_boss_dot(canvas, boss.position, origin, center)


func _draw_waypoint(canvas: Control, origin: Vector3) -> void:
	var wp: Dictionary = SceneManager.save_manager.waypoint
	if wp.is_empty():
		return
	var wp_map: String = str(wp.get("map", ""))
	if wp_map != SceneManager.save_manager.current_map:
		return
	var tx: int = int(wp.get("tx", 0))
	var tz: int = int(wp.get("tz", 0))
	var wx: float = float(tx) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var wz: float = float(tz) * IsoConst.TILE_SIZE + IsoConst.TILE_SIZE * 0.5
	var off: Vector3 = Vector3(wx, 0.0, wz) - origin
	const ROT45: float = 0.7071067811865476
	var rx: float = (off.x - off.z) * ROT45
	var ry: float = (off.x + off.z) * ROT45
	var center := Vector2(_half, _half)
	var dot := Vector2(_half + rx * _scale, _half + ry * _scale)
	# Clamp to minimap circle edge if outside
	var from_center: Vector2 = dot - center
	if from_center.length() > _half * 0.94:
		dot = center + from_center.normalized() * (_half * 0.88)
	canvas.draw_circle(dot, 5.0, Color(0.20, 0.80, 1.00), true, -1.0, true)
	canvas.draw_arc(dot, 7.0, 0.0, TAU, 12, Color(0.20, 0.80, 1.00, 0.70), 1.5, true)


func _draw_group(canvas: Control, nodes: Dictionary, origin: Vector3,
		color: Color, radius: float, skip_id: String = "") -> void:
	var center := Vector2(_half, _half)
	for id in nodes:
		if str(id) == skip_id:
			continue
		var raw = nodes[id]
		if not is_instance_valid(raw):
			continue
		var n: Node3D = raw
		var off: Vector3 = n.position - origin
		# Rotate +45° to match the isometric camera's −45° azimuth:
		# iso screen-right = world NE (+x,0,−z), iso screen-up = world NW (−x,0,−z).
		const ROT45: float = 0.7071067811865476
		var rx: float = (off.x - off.z) * ROT45
		var ry: float = (off.x + off.z) * ROT45
		var dot := Vector2(_half + rx * _scale, _half + ry * _scale)
		# Only draw dots that fall inside the circle
		if (dot - center).length() <= _half * 0.94:
			canvas.draw_circle(dot, radius, color, true, -1.0, true)

func _draw_enemy_nodes(canvas: Control, origin: Vector3) -> void:
	var center := Vector2(_half, _half)
	const ROT45: float = 0.7071067811865476
	const ENEMY_COLOR: Color = Color(0.95, 0.20, 0.20)
	const SPECTRE_COLOR: Color = Color(0.55, 0.75, 1.00)
	for id in _enemy_nodes:
		if str(id) == "roaming_boss":
			continue
		var raw = _enemy_nodes[id]
		if not is_instance_valid(raw):
			continue
		var n: Node3D = raw
		var off: Vector3 = n.position - origin
		var rx: float = (off.x - off.z) * ROT45
		var ry: float = (off.x + off.z) * ROT45
		var dot := Vector2(_half + rx * _scale, _half + ry * _scale)
		if (dot - center).length() <= _half * 0.94:
			var color: Color = SPECTRE_COLOR if n.get_meta("is_nocturnal", false) else ENEMY_COLOR
			canvas.draw_circle(dot, 4.0, color, true, -1.0, true)

func _draw_boss_dot(canvas: Control, boss_pos: Vector3, origin: Vector3,
		center: Vector2) -> void:
	const ROT45: float = 0.7071067811865476
	const BOSS_COLOR: Color = Color(1.0, 0.08, 0.08)
	var off: Vector3 = boss_pos - origin
	var rx: float = (off.x - off.z) * ROT45
	var ry: float = (off.x + off.z) * ROT45
	var dot := Vector2(_half + rx * _scale, _half + ry * _scale)
	var from_center: Vector2 = dot - center
	if from_center.length() <= _half * 0.94:
		canvas.draw_circle(dot, 7.0, BOSS_COLOR, true, -1.0, true)
	else:
		# Edge indicator: clamp to minimap border, slightly faded
		var edge: Vector2 = center + from_center.normalized() * (_half * 0.88)
		canvas.draw_circle(edge, 5.0, Color(BOSS_COLOR.r, BOSS_COLOR.g, BOSS_COLOR.b, 0.65), true, -1.0, true)
