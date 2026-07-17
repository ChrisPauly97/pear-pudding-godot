extends CharacterBody3D

const MountRegistry = preload("res://game_logic/MountRegistry.gd")
const TextureGen    = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const TerrainMath   = preload("res://game_logic/TerrainMath.gd")

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 8.0
const GRAVITY: float = -20.0
const ACCEL: float = 40.0
const DECEL: float = 50.0
const _LAND_FALL_SPEED: float = 4.0   # min downward speed (u/s) to count as a "landing"

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
var _dust_mat_mount: ParticleProcessMaterial
var _dust_mat_foot: ParticleProcessMaterial
var _landing_dust: GPUParticles3D
var _is_moving: bool = false
var _was_on_floor: bool = true

var _highlight_timer: float = 0.0
var _highlighted_node: Node3D = null
const _SCAN_INTERVAL: float = 1.0 / 7.0
const _INTERACT_RADIUS: float = 3.0

# Path-following state (tap-to-move)
var _path_waypoints: Array[Vector2i] = []
var _path_wp_index: int = 0
var _has_active_path: bool = false
const _WP_ARRIVE_DIST_SQ: float = 0.3 * 0.3  # arrive when within 0.3 world units

func _ready() -> void:
	collision_layer = 1       # player layer
	collision_mask  = 2 | 4   # collide with terrain (2) + walls (4)
	# Slope handling: generated hills reach ~72° at max height (Mountains
	# max_hill_h 7 blended over HILL_CURVE_R 3.5), so the default 45°
	# floor_max_angle treated steep hill faces as walls and climbing relied on
	# the WorldScene software-floor teleport (which stalls the player). Treat
	# them as walkable floor, snap to the surface on descents/crests instead
	# of micro-falling, and keep slope speed uniform. Wall faces are vertical
	# (90°) and stay unwalkable.
	floor_max_angle = deg_to_rad(75.0)
	floor_snap_length = 0.6
	floor_constant_speed = true
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
	# Waypoint 0 is always the player's current tile (the A* start tile).
	# Skip it so a drag update doesn't steer toward the current tile centre
	# before heading to the real destination.
	_path_wp_index = 1 if waypoints.size() > 1 else 0
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
	_sprite.frame_changed.connect(_on_sprite_frame_changed)

	# Mount sprite: sits below player sprite, only visible while mounted
	_mount_sprite = Sprite3D.new()
	var mount_tex: Texture2D = _SpriteRegistry.mount_texture()
	_mount_sprite.texture = mount_tex if mount_tex != null else TextureGen.mount_horse()
	_mount_sprite.pixel_size = PIXEL_SIZE
	_mount_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mount_sprite.shaded = false
	_mount_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_mount_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mount_sprite.no_depth_test = false
	_mount_sprite.double_sided = true
	_mount_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Feet-at-y=0 from the real texture height (CLAUDE.md Sprite3D rule) — don't
	# assume a fixed pixel height, the real mount_horse.png differs from the old
	# TextureGen fallback's 24px.
	var mount_tex_h: float = float(_mount_sprite.texture.get_height())
	_mount_sprite.position = Vector3(0.0, mount_tex_h * PIXEL_SIZE * 0.5, 0.01)
	_mount_sprite.visible = false
	add_child(_mount_sprite)

	# Dust particles: emit from feet while moving (foot dust on the ground,
	# heavier mount dust while riding — swapped by _update_mount_visuals()).
	_dust_particles = GPUParticles3D.new()
	_dust_particles.amount = 20
	_dust_particles.lifetime = 0.6
	_dust_particles.one_shot = false
	_dust_particles.emitting = false
	_dust_particles.position = Vector3(0.0, 0.05, 0.0)
	_dust_mat_mount = ParticleProcessMaterial.new()
	_dust_mat_mount.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_dust_mat_mount.emission_sphere_radius = 0.4
	_dust_mat_mount.direction = Vector3(0.0, 1.0, 0.0)
	_dust_mat_mount.spread = 60.0
	_dust_mat_mount.initial_velocity_min = 0.5
	_dust_mat_mount.initial_velocity_max = 1.5
	_dust_mat_mount.gravity = Vector3(0.0, -3.0, 0.0)
	_dust_mat_mount.scale_min = 0.04
	_dust_mat_mount.scale_max = 0.10
	_dust_mat_mount.color = Color(0.72, 0.60, 0.42, 0.75)
	_dust_mat_foot = ParticleProcessMaterial.new()
	_dust_mat_foot.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_dust_mat_foot.emission_sphere_radius = 0.3
	_dust_mat_foot.direction = Vector3(0.0, 1.0, 0.0)
	_dust_mat_foot.spread = 50.0
	_dust_mat_foot.initial_velocity_min = 0.3
	_dust_mat_foot.initial_velocity_max = 0.8
	_dust_mat_foot.gravity = Vector3(0.0, -3.0, 0.0)
	_dust_mat_foot.scale_min = 0.03
	_dust_mat_foot.scale_max = 0.06
	_dust_mat_foot.color = Color(0.72, 0.60, 0.42, 0.45)
	_dust_particles.process_material = _dust_mat_foot
	add_child(_dust_particles)

	# One-shot burst for landing feedback (separate from the continuous foot/mount dust).
	_landing_dust = GPUParticles3D.new()
	_landing_dust.amount = 14
	_landing_dust.lifetime = 0.5
	_landing_dust.one_shot = true
	_landing_dust.emitting = false
	_landing_dust.position = Vector3(0.0, 0.05, 0.0)
	var pm_land := ParticleProcessMaterial.new()
	pm_land.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm_land.emission_sphere_radius = 0.5
	pm_land.direction = Vector3(0.0, 1.0, 0.0)
	pm_land.spread = 80.0
	pm_land.initial_velocity_min = 1.0
	pm_land.initial_velocity_max = 2.2
	pm_land.gravity = Vector3(0.0, -4.0, 0.0)
	pm_land.scale_min = 0.05
	pm_land.scale_max = 0.12
	pm_land.color = Color(0.72, 0.60, 0.42, 0.8)
	_landing_dust.process_material = pm_land
	add_child(_landing_dust)

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

	# Ramp velocity toward the target instead of snapping — accelerate while
	# there's steering intent (manual input or an active path), decelerate to
	# a stop otherwise. Full steering authority is kept while pathing (ACCEL
	# applies for the whole path, not just the first tick) so the waypoint
	# arrival check doesn't fight a sluggish decel and orbit the destination.
	var move_speed: float = _get_move_speed()
	var target_vx: float = dir.x * move_speed
	var target_vz: float = dir.z * move_speed
	var accel: float = ACCEL if dir.length_squared() > 0.0 else DECEL
	velocity.x = move_toward(velocity.x, target_vx, accel * delta)
	velocity.z = move_toward(velocity.z, target_vz, accel * delta)

	_was_on_floor = is_on_floor()
	if not _was_on_floor:
		_velocity_y += GRAVITY * delta
	else:
		_velocity_y = 0.0
	var fall_speed: float = _velocity_y

	if Input.is_action_just_pressed("jump") and _was_on_floor:
		_velocity_y = JUMP_VELOCITY
		_squash_sprite(0.94, 1.06, 0.12)

	velocity.y = _velocity_y
	move_and_slide()

	if not _was_on_floor and is_on_floor() and fall_speed <= -_LAND_FALL_SPEED:
		_on_landed()

	# --- Sprite animation (AnimatedSprite3D drives frame timing natively) ---
	# Keyed off steering intent (dir), not residual velocity, so idle doesn't
	# lag behind the actual stop while decel is still ramping down.
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

	# Dust particles: emit while moving on foot or mounted (material/amount
	# swapped by _update_mount_visuals — mounted kicks more dust).
	if _dust_particles != null:
		_dust_particles.emitting = _is_moving and is_on_floor()

	_highlight_timer -= delta
	if _highlight_timer <= 0.0:
		_highlight_timer = _SCAN_INTERVAL
		_scan_interactables()

func _on_landed() -> void:
	if _landing_dust != null:
		_landing_dust.restart()
	AudioManager.play_sfx("land")
	_squash_sprite(1.08, 0.9, 0.15)

## Quick squash/stretch beat on the sprite (landing thump, jump takeoff).
## CAUTION: AnimatedSprite3D is a Node3D — scale is Vector3, never Vector2.
func _squash_sprite(sx: float, sy: float, duration: float) -> void:
	if _sprite == null:
		return
	var tw: Tween = _sprite.create_tween()
	tw.tween_property(_sprite, "scale", Vector3(sx, sy, 1.0), duration * 0.4)
	tw.tween_property(_sprite, "scale", Vector3.ONE, duration * 0.6)

## Footsteps locked to the walk animation's contact frames (0 and 2 of the
## 4-frame cycle) instead of a fixed timer, so feet and sound stay in sync.
func _on_sprite_frame_changed() -> void:
	if SaveManager.is_mounted:
		return
	if _sprite.animation != &"walk":
		return
	if _sprite.frame == 0 or _sprite.frame == 2:
		AudioManager.play_sfx("footstep")

func _update_mount_visuals(mounted: bool) -> void:
	if _mount_sprite != null:
		_mount_sprite.visible = mounted
	if _dust_particles != null:
		_dust_particles.process_material = _dust_mat_mount if mounted else _dust_mat_foot
		_dust_particles.amount = 20 if mounted else 10

## Zeroes only the vertical fall — horizontal velocity is preserved so a
## terrain rescue (WorldScene software floor) doesn't stop the player dead
## mid-stride and force a full re-acceleration.
func cancel_fall() -> void:
	_velocity_y = 0.0
	velocity.y = 0.0

func _scan_interactables() -> void:
	var closest: Node3D = null
	var min_sq: float = _INTERACT_RADIUS * _INTERACT_RADIUS
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node3D:
			continue
		var n3d: Node3D = node as Node3D
		var dv: Vector3 = n3d.global_position - global_position
		var dsq: float = dv.x * dv.x + dv.z * dv.z
		if dsq < min_sq:
			min_sq = dsq
			closest = n3d
	if closest != _highlighted_node:
		if _highlighted_node != null and _highlighted_node.has_method("set_highlighted"):
			_highlighted_node.call("set_highlighted", false)
		if closest != null and closest.has_method("set_highlighted"):
			closest.call("set_highlighted", true)
		_highlighted_node = closest

func _on_mount_state_changed(mounted: bool, _mount_id: String) -> void:
	_update_mount_visuals(mounted)
