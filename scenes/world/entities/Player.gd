extends CharacterBody3D

const MountRegistry = preload("res://game_logic/MountRegistry.gd")
const TextureGen    = preload("res://game_logic/TextureGen.gd")
const TerrainMath   = preload("res://game_logic/TerrainMath.gd")

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 8.0
const GRAVITY: float = -20.0

# Individual walk frame textures (pixel art versions)
const _WalkTex1: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_1_pixel.png")
const _WalkTex2: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_2_pixel.png")
const _WalkTex3: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_3_pixel.png")
const _WalkTex4: Texture2D = preload("res://assets/textures/pixel_art/wizard_walk_4_pixel.png")

const ANIM_FPS: float = 6.0        # walking animation speed
const PIXEL_SIZE: float = 0.05     # larger per-pixel size to match 32px sprite scale

var _velocity_y: float = 0.0
var _sprite: AnimatedSprite3D
var _mount_sprite: Sprite3D
var _dust_particles: GPUParticles3D
var _is_moving: bool = false
var _footstep_timer: float = 0.0

# Path-following state (tap-to-move)
var _path_waypoints: Array[Vector2i] = []
var _path_wp_index: int = 0
var _has_active_path: bool = false
const _WP_ARRIVE_DIST_SQ: float = 0.3 * 0.3  # arrive when within 0.3 world units

func _ready() -> void:
	collision_layer = 1       # player layer
	collision_mask  = 2 | 4   # collide with terrain (2) + walls (4)
	_build_sprite()
	GameBus.mount_state_changed.connect(_on_mount_state_changed)
	_update_mount_visuals(SaveManager.is_mounted)
	GameBus.enemy_engaged.connect(func(_d: Dictionary) -> void: cancel_path())

func _get_move_speed() -> float:
	var speed: float = SPEED
	if SaveManager.is_mounted and SaveManager.current_map == "main" and SaveManager.active_mount != "":
		var mount: Dictionary = MountRegistry.get_mount(SaveManager.active_mount)
		if not mount.is_empty():
			speed = SPEED * float(mount.get("speed_multiplier", 1.0))
	if SaveManager.current_map == "main" and TerrainMath.is_on_ley_line(
			global_position.x, global_position.z, SaveManager.world_seed):
		speed *= 1.15
	return speed

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
	# Build a SpriteFrames resource with idle (frame 0) and walk (all 4 frames).
	var sf := SpriteFrames.new()

	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", ANIM_FPS)
	sf.add_frame("idle", _WalkTex1)

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", ANIM_FPS)
	sf.add_frame("walk", _WalkTex1)
	sf.add_frame("walk", _WalkTex2)
	sf.add_frame("walk", _WalkTex3)
	sf.add_frame("walk", _WalkTex4)

	# SpriteFrames starts with a default "default" animation — remove it.
	if sf.has_animation("default"):
		sf.remove_animation("default")

	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = sf
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
	_sprite.play("idle")

	# Mount sprite: sits below player sprite, only visible while mounted
	_mount_sprite = Sprite3D.new()
	_mount_sprite.texture = TextureGen.mount_horse()
	_mount_sprite.pixel_size = PIXEL_SIZE
	_mount_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mount_sprite.shaded = false
	_mount_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_mount_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mount_sprite.no_depth_test = false
	_mount_sprite.double_sided = true
	_mount_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 24px tall at PIXEL_SIZE=0.05 → 1.2 world units; half = 0.6; sits just below the player
	_mount_sprite.position = Vector3(0.0, 0.6, 0.01)
	_mount_sprite.visible = false
	add_child(_mount_sprite)

	# Dust particles: emit from feet while mounted and moving
	_dust_particles = GPUParticles3D.new()
	_dust_particles.amount = 20
	_dust_particles.lifetime = 0.6
	_dust_particles.one_shot = false
	_dust_particles.emitting = false
	_dust_particles.position = Vector3(0.0, 0.05, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0.0, -3.0, 0.0)
	pm.scale_min = 0.04
	pm.scale_max = 0.10
	pm.color = Color(0.72, 0.60, 0.42, 0.75)
	_dust_particles.process_material = pm
	add_child(_dust_particles)

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO

	# get_vector supports analog gamepad axes (deadzone-corrected) and digital keys.
	# Isometric remap: inp.x = right-left, inp.y = down-up
	var inp: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if inp.length_squared() > 0.01:
		dir.x = inp.y + inp.x
		dir.z = inp.y - inp.x

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

	var move_speed: float = _get_move_speed()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	if not is_on_floor():
		_velocity_y += GRAVITY * delta
	else:
		_velocity_y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		_velocity_y = JUMP_VELOCITY

	velocity.y = _velocity_y
	move_and_slide()

	# --- Footstep audio ---
	_footstep_timer -= delta
	if dir.length_squared() > 0.01 and _footstep_timer <= 0.0:
		AudioManager.play_sfx("footstep")
		_footstep_timer = 0.4

	# --- Sprite animation (AnimatedSprite3D drives frame timing natively) ---
	_is_moving = dir.length_squared() > 0.0

	if _is_moving:
		# Flip based on screen-space direction (camera looks from +X,+Y,+Z)
		var screen_x: float = dir.x - dir.z
		if abs(screen_x) > 0.1:
			_sprite.flip_h = screen_x < 0.0
		if _sprite.animation != &"walk":
			_sprite.play("walk")
	else:
		if _sprite.animation != &"idle":
			_sprite.play("idle")

	# Dust particles: emit only when mounted and moving
	if _dust_particles != null:
		_dust_particles.emitting = SaveManager.is_mounted and _is_moving

func _update_mount_visuals(mounted: bool) -> void:
	if _mount_sprite != null:
		_mount_sprite.visible = mounted
	if _dust_particles != null and not mounted:
		_dust_particles.emitting = false

func _on_mount_state_changed(mounted: bool, _mount_id: String) -> void:
	_update_mount_visuals(mounted)
