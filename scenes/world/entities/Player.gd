extends CharacterBody3D

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 8.0
const GRAVITY: float = -20.0

# Individual walk frame textures (already imported by Godot editor)
const _WalkTex1: Texture2D = preload("res://assets/textures/wizard_walk_1.png")
const _WalkTex2: Texture2D = preload("res://assets/textures/wizard_walk_2.png")
const _WalkTex3: Texture2D = preload("res://assets/textures/wizard_walk_3.png")
const _WalkTex4: Texture2D = preload("res://assets/textures/wizard_walk_4.png")
const WALK_FRAMES: int = 4

const ANIM_FPS: float = 6.0        # walking animation speed
const PIXEL_SIZE: float = 0.004    # world units per pixel — controls sprite scale

var _velocity_y: float = 0.0
var _is_jumping: bool = false
var _sprite: Sprite3D
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _is_moving: bool = false
var _walk_frames: Array[Texture2D]

func _ready() -> void:
	_walk_frames = [_WalkTex1, _WalkTex2, _WalkTex3, _WalkTex4]
	collision_layer = 1       # player layer
	collision_mask  = 2 | 4   # collide with terrain (2) + walls (4)
	_build_sprite()

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
