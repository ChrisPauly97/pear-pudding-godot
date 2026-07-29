extends Node3D
## Gold beacon planted on the tile of the active story objective.
##
## The compass ribbon says which way to *face*; this says which thing on screen
## the objective actually is — a bobbing arrow pointing down at the tile, a light
## shaft that carries above the props, and a ground ring. It carries no text of
## its own: the compass caption already names the objective, and a second
## world-space label just collides with the NPC name tag underneath it.
##
## It is an ordinary world node at the objective's tile, so it is on screen
## exactly when the objective is (the orthographic camera's box is ~15 units).
## The arrow draws through terrain (`no_depth_test`) so a hut or a hill between
## player and objective hides the target but never the pointer.
##
## WorldScene owns exactly one instance — see `WorldScene._refresh_objective_beacon()`.

const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")

const COLOR: Color = Color(1.0, 0.82, 0.15)
const ARROW_Y: float = 2.9          # arrow hover height above the tile
const BOB_AMPLITUDE: float = 0.22
const BOB_SPEED: float = 2.4
const SPIN_SPEED: float = 1.2
const SHAFT_HEIGHT: float = 5.0
## Standing on the objective, the shaft is in the player's face — fade it out.
const NEAR_DIST: float = 3.0

var _arrow: MeshInstance3D = null
var _shaft: MeshInstance3D = null
var _shaft_mat: StandardMaterial3D = null
var _player: Node3D = null
var _time: float = 0.0

func _ready() -> void:
	# Ground ring on the tile itself — the "X marks the spot".
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.62
	ring_mesh.outer_radius = 0.86
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 20
	var ring_mat: StandardMaterial3D = _WEB.unshaded_material(Color(COLOR.r, COLOR.g, COLOR.b, 0.85))
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = COLOR
	ring_mat.emission_energy_multiplier = 1.6
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = ring_mat
	ring.position = Vector3(0.0, 0.08, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	# Light shaft rising out of the tile: what is actually visible from across
	# the map, since props and terrain hide anything at ground level.
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.30
	shaft_mesh.bottom_radius = 0.34
	shaft_mesh.height = SHAFT_HEIGHT
	shaft_mesh.cap_top = false
	shaft_mesh.cap_bottom = false
	shaft_mesh.radial_segments = 12
	_shaft_mat = _WEB.unshaded_material(Color(COLOR.r, COLOR.g, COLOR.b, 0.16))
	_shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shaft_mat.no_depth_test = false
	_shaft = MeshInstance3D.new()
	_shaft.mesh = shaft_mesh
	_shaft.material_override = _shaft_mat
	_shaft.position = Vector3(0.0, SHAFT_HEIGHT * 0.5, 0.0)
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shaft)

	# Four-sided pyramid pointing straight down at the tile. Four segments (not a
	# smooth cone) so the spin below actually reads as rotation.
	var arrow_mesh := CylinderMesh.new()
	arrow_mesh.top_radius = 0.46
	arrow_mesh.bottom_radius = 0.0
	arrow_mesh.height = 0.9
	arrow_mesh.radial_segments = 4
	arrow_mesh.rings = 1
	var arrow_mat: StandardMaterial3D = _WEB.unshaded_material(COLOR)
	arrow_mat.emission_enabled = true
	arrow_mat.emission = COLOR
	arrow_mat.emission_energy_multiplier = 1.9
	arrow_mat.no_depth_test = true
	_arrow = MeshInstance3D.new()
	_arrow.mesh = arrow_mesh
	_arrow.material_override = arrow_mat
	_arrow.position = Vector3(0.0, ARROW_Y, 0.0)
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Render after the world so the no-depth-test pointer sits on top of props.
	_arrow.sorting_offset = 1.0
	add_child(_arrow)

## `player` is polled for distance-based fading; it may be null on a dedicated
## server or before the local player exists, in which case nothing fades.
func setup(player: Node3D) -> void:
	_player = player

func _process(delta: float) -> void:
	_time += delta
	if _arrow != null:
		_arrow.position.y = ARROW_Y + sin(_time * BOB_SPEED) * BOB_AMPLITUDE
		_arrow.rotation.y = _time * SPIN_SPEED

	if _player == null or not is_instance_valid(_player):
		return
	var d: float = Vector2(_player.global_position.x - global_position.x,
		_player.global_position.z - global_position.z).length()
	if _shaft_mat != null:
		# Fade the shaft out as the player closes in, so arriving at the
		# objective doesn't leave a pillar of light across the whole screen.
		var near: float = clampf(d / NEAR_DIST, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.0)
		_shaft_mat.albedo_color.a = (0.10 + 0.08 * pulse) * near
	if _shaft != null:
		_shaft.visible = d > NEAR_DIST * 0.5
