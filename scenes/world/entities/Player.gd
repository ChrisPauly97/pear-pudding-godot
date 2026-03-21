extends CharacterBody3D

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 8.0
const GRAVITY: float = -20.0

var _velocity_y: float = 0.0
var _is_jumping: bool = false
var _model: Node3D

func _ready() -> void:
	collision_layer = 1       # player layer
	collision_mask  = 2 | 4   # collide with terrain (2) + walls (4)
	_model = _build_character_model()
	add_child(_model)

func _build_character_model() -> Node3D:
	var root := Node3D.new()

	# Colours matching the pixel art
	var green_mat := StandardMaterial3D.new()
	green_mat.albedo_color = Color(0.30, 0.65, 0.20)
	green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var dark_green_mat := StandardMaterial3D.new()
	dark_green_mat.albedo_color = Color(0.22, 0.50, 0.15)
	dark_green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var blue_mat := StandardMaterial3D.new()
	blue_mat.albedo_color = Color(0.20, 0.35, 0.85)
	blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var light_blue_mat := StandardMaterial3D.new()
	light_blue_mat.albedo_color = Color(0.30, 0.50, 0.95)
	light_blue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# --- Legs (two separate boxes) ---
	var left_leg := _make_box(Vector3(0.22, 0.5, 0.22), blue_mat)
	left_leg.position = Vector3(-0.15, 0.25, 0.0)
	root.add_child(left_leg)

	var right_leg := _make_box(Vector3(0.22, 0.5, 0.22), blue_mat)
	right_leg.position = Vector3(0.15, 0.25, 0.0)
	root.add_child(right_leg)

	# --- Body (torso) ---
	var body := _make_box(Vector3(0.5, 0.55, 0.3), green_mat)
	body.position = Vector3(0.0, 0.775, 0.0)
	root.add_child(body)

	# --- Arms ---
	var left_arm := _make_box(Vector3(0.18, 0.5, 0.2), dark_green_mat)
	left_arm.position = Vector3(-0.34, 0.775, 0.0)
	root.add_child(left_arm)

	var right_arm := _make_box(Vector3(0.18, 0.5, 0.2), dark_green_mat)
	right_arm.position = Vector3(0.34, 0.775, 0.0)
	root.add_child(right_arm)

	# --- Head (diamond shape = rotated cube) ---
	var head := _make_box(Vector3(0.35, 0.35, 0.35), light_blue_mat)
	head.position = Vector3(0.0, 1.35, 0.0)
	head.rotation_degrees = Vector3(0, 45, 45)
	root.add_child(head)

	return root

func _make_box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO

	# Isometric WASD mapped to screen directions:
	# Camera right = NE (+X,-Z), Camera up = NW (-X,-Z)
	# W = screen up = NW, S = screen down = SE, A = screen left = SW, D = screen right = NE
	if Input.is_action_pressed("move_up"):
		dir.x -= 1; dir.z -= 1
	if Input.is_action_pressed("move_down"):
		dir.x += 1; dir.z += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1; dir.z += 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1; dir.z -= 1

	if dir.length_squared() > 0.0:
		dir = dir.normalized()

	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	if not is_on_floor():
		_velocity_y += GRAVITY * delta
	else:
		_velocity_y = 0.0
		_is_jumping = false

	if Input.is_action_just_pressed("jump") and is_on_floor():
		_velocity_y = JUMP_VELOCITY
		_is_jumping = true

	velocity.y = _velocity_y
	move_and_slide()
