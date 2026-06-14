extends CharacterBody3D

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 8.0
const GRAVITY: float = -20.0

# Individual walk frame textures (pixel art versions)
const _WalkTex1: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_1_pixel.png")
const _WalkTex2: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_2_pixel.png")
const _WalkTex3: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_3_pixel.png")
const _WalkTex4: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_4_pixel.png")
const WALK_FRAMES: int = 4

const ANIM_FPS: float = 6.0        # walking animation speed
const PIXEL_SIZE: float = 0.05     # larger per-pixel size to match 32px sprite scale

var _velocity_y: float = 0.0
var _is_jumping: bool = false
var _sprite: Sprite3D
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _is_moving: bool = false
var _walk_frames: Array[Texture2D]
var _footstep_timer: float = 0.0

# Path-following state (tap-to-move)
var _path_waypoints: Array[Vector2i] = []
var _path_wp_index: int = 0
var _has_active_path: bool = false
const _WP_ARRIVE_DIST_SQ: float = 0.3 * 0.3  # arrive when within 0.3 world units

func _ready() -> void:
	_walk_frames = [_WalkTex1, _WalkTex2, _WalkTex3, _WalkTex4]
	collision_layer = 1       # player layer
	collision_mask  = 2 | 4   # collide with terrain (2) + walls (4)
	_build_sprite()
	GameBus.enemy_engaged.connect(func(_d: Dictionary) -> void: cancel_path())

# Called by WorldScene after a tap-to-move path is found.
func set_destination_path(waypoints: Array[Vector2i]) -> void:
	if waypoints.is_empty():
		return
	_path_waypoints = waypoints
	_path_wp_index = 0
	_has_active_path = true

# Cancels the active tap-to-move path (called on manual input or interrupts).
func cancel_path() -> void:
	_has_active_path = false
	_path_waypoints.clear()
	_path_wp_index = 0

func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = _walk_frames[0]
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.no_depth_test = false
	_sprite.double_sided = true
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Position sprite so bottom edge sits at y=0 (feet on the ground)
	var frame_h: float = _WalkTex1.get_height() * PIXEL_SIZE
	_sprite.position = Vector3(0.0, frame_h * 0.5, 0.0)

	add_child(_sprite)

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO

	if Input.is_action_pressed("move_up"):
		dir.x -= 1; dir.z -= 1
	if Input.is_action_pressed("move_down"):
		dir.x += 1; dir.z += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1; dir.z += 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1; dir.z -= 1

	if dir.length_squared() > 0.0:
		# Manual input always wins — cancel any active path.
		dir = dir.normalized()
		cancel_path()
	elif _has_active_path:
		# Steer toward the current waypoint centre.
		var wp: Vector2i = _path_waypoints[_path_wp_index]
		var wp_world := Vector3(
			(float(wp.x) + 0.5) * IsoConst.TILE_SIZE,
			position.y,
			(float(wp.y) + 0.5) * IsoConst.TILE_SIZE)
		var delta_v: Vector3 = wp_world - position
		delta_v.y = 0.0
		var dist_sq: float = delta_v.x * delta_v.x + delta_v.z * delta_v.z
		if dist_sq <= _WP_ARRIVE_DIST_SQ:
			_path_wp_index += 1
			if _path_wp_index >= _path_waypoints.size():
				cancel_path()
		else:
			dir = delta_v.normalized()

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

	# --- Footstep audio ---
	_footstep_timer -= delta
	if dir.length_squared() > 0.01 and _footstep_timer <= 0.0:
		AudioManager.play_sfx("footstep")
		_footstep_timer = 0.4

	# --- Sprite animation ---
	_is_moving = dir.length_squared() > 0.0

	if _is_moving:
		# Flip based on screen-space direction (camera looks from +X,+Y,+Z)
		var screen_x: float = dir.x - dir.z
		if abs(screen_x) > 0.1:
			_sprite.flip_h = screen_x < 0.0

		_anim_timer += delta
		var frame_dur: float = 1.0 / ANIM_FPS
		if _anim_timer >= frame_dur:
			_anim_timer -= frame_dur
			_anim_frame = (_anim_frame + 1) % WALK_FRAMES
			_sprite.texture = _walk_frames[_anim_frame]
	else:
		_anim_timer = 0.0
		if _anim_frame != 0:
			_anim_frame = 0
			_sprite.texture = _walk_frames[0]
