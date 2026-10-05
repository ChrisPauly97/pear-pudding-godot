## Character presence: per-frame presentation of registered world characters.
##
##   * contact shadows (GID-131 / TID-503) — writes the nearest
##     `ContactShadow.MAX_CASTERS` casters (player first) into the
##     `contact_shadow_*` shader globals that terrain and grass shaders read;
##     casters register with `ContactShadow.register()` in `_ready`.
##   * idle life (GID-132 / TID-511) — breathes/bobs/floats every sprite
##     registered with `IdleLife.register()` within `IdleLife.MAX_DISTANCE`.
##
## Both groups are gathered and distance-culled REFRESH_INTERVAL apart, not every
## frame (GID-164 / TID-676): per frame only the cached candidates are touched,
## and their register-time meta (style, phase, base, radius) is read once.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _ContactShadow = preload("res://game_logic/ContactShadow.gd")
const _IdleLife = preload("res://game_logic/IdleLife.gd")
const _HeroAnim = preload("res://game_logic/character/HeroAnim.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")

## Seconds between group gathers / distance culls.
const REFRESH_INTERVAL: float = 0.25
## Casters kept as shadow candidates at a gather (world units from the player):
## well past the on-screen ground (~45 u), plus what anyone moves in one interval.
const SHADOW_PREFILTER: float = 60.0
## Idle-life cull slack so a sprite walking into range starts within one interval.
const IDLE_SLACK: float = 4.0

var _world: _WorldScene = null
var _refresh_left: float = 0.0
var _idle_recs: Array = []    # [Node3D, style: int, phase: float, base: Vector3] — node untyped (may be freed)
var _caster_recs: Array = []  # [Node3D, radius: float]
## Shader-global names, built once instead of PARAM_PREFIX + str(i) per write.
var _param_names: Array[StringName] = []
var _written: Array[Vector4] = []
var _time: float = 0.0
var _animated: int = 0
var _glow: float = 0.0
var _glow_written: float = -1.0


func _ready() -> void:
	for i: int in _ContactShadow.MAX_CASTERS:
		_param_names.append(StringName(_ContactShadow.PARAM_PREFIX + str(i)))
	RenderingServer.global_shader_parameter_set(_ContactShadow.OPACITY_PARAM,
			_ContactShadow.opacity_for(_world.graphics_knobs()) if _world != null else 0.0)


func _exit_tree() -> void:
	# The globals outlive the scene: clear them so a battle or menu 3D view
	# never shows stale pools.
	for i: int in _ContactShadow.MAX_CASTERS:
		RenderingServer.global_shader_parameter_set(_param_names[i] if i < _param_names.size()
				else StringName(_ContactShadow.PARAM_PREFIX + str(i)), _ContactShadow.EMPTY)


## Slots currently written (tests, debugging).
func slots() -> Array[Vector4]:
	return _written


func apply_knobs(knobs: Dictionary) -> void:
	RenderingServer.global_shader_parameter_set(_ContactShadow.OPACITY_PARAM, _ContactShadow.opacity_for(knobs))


func _process(delta: float) -> void:
	if _world == null or _world._player == null:
		return
	_time += delta
	var center: Vector3 = _world._player.global_position
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_gather(center)
	_update_idle_life()
	_update_hero(delta)
	var casters: Array[Vector4] = []
	for rec: Array in _caster_recs:
		var n3: Node3D = _valid_node3d(rec[0])
		if n3 == null or not n3.is_visible_in_tree():
			continue
		var p: Vector3 = n3.global_position
		casters.append(Vector4(p.x, p.y, p.z, float(rec[1]) * n3.scale.x))
	var slots_now: Array[Vector4] = _ContactShadow.pick_slots(casters, center)
	for i: int in slots_now.size():
		if i < _written.size() and _written[i] == slots_now[i]:
			continue
		RenderingServer.global_shader_parameter_set(_param_names[i], slots_now[i])
	_written = slots_now


## Re-reads both groups and keeps the candidates near `center`.
func _gather(center: Vector3) -> void:
	_caster_recs.clear()
	var shadow_d2: float = SHADOW_PREFILTER * SHADOW_PREFILTER
	for n: Node in get_tree().get_nodes_in_group(_ContactShadow.GROUP):
		var n3 := n as Node3D
		if n3 == null or n3.global_position.distance_squared_to(center) > shadow_d2:
			continue
		_caster_recs.append([n3, float(n3.get_meta(_ContactShadow.META_RADIUS, _ContactShadow.MIN_RADIUS))])
	_idle_recs.clear()
	var reach: float = _IdleLife.MAX_DISTANCE + IDLE_SLACK
	var idle_d2: float = reach * reach
	for n: Node in get_tree().get_nodes_in_group(_IdleLife.GROUP):
		var sp := n as Node3D
		if sp == null or sp.global_position.distance_squared_to(center) > idle_d2:
			continue
		_idle_recs.append([sp, int(sp.get_meta(_IdleLife.META_STYLE, 0)),
				float(sp.get_meta(_IdleLife.META_PHASE, 0.0)), sp.get_meta(_IdleLife.META_BASE, sp.position)])


static func _valid_node3d(v: Variant) -> Node3D:
	return v if is_instance_valid(v) else null


## Hero touches (GID-134 / TID-526): walk/breath bob and a warm outline pulse
## while something is in reach.
func _update_hero(delta: float) -> void:
	var pl := _world._player
	var spr: AnimatedSprite3D = pl._sprite
	if spr == null:
		return
	pl.visual_bob = _IdleLife.hero_bob(_HeroAnim.is_walk(spr.animation) and spr.is_playing(), spr.frame, _time)
	var near: bool = _world._world_hud != null and _world._world_hud.interact_prompt_visible
	_glow = move_toward(_glow, 1.0 if near else 0.0, delta * 4.0)
	var g: float = _glow * (0.7 + 0.3 * sin(_time * 5.0))
	if absf(g - _glow_written) > 0.02 or (g == 0.0 and _glow_written != 0.0):
		_glow_written = g
		_SpriteOutline.set_glow(spr, g)


func _update_idle_life() -> void:
	_animated = 0
	var now: float = _IdleLife.now()
	for rec: Array in _idle_recs:
		var sp: Node3D = _valid_node3d(rec[0])
		if sp == null or not sp.is_visible_in_tree():
			continue
		var hop_age: float = -1.0
		if sp.has_meta(_IdleLife.META_HOP):
			hop_age = now - float(sp.get_meta(_IdleLife.META_HOP))
		var p: Vector2 = _IdleLife.pose(int(rec[1]), _time, float(rec[2]),
				bool(sp.get_meta(_IdleLife.META_FAST, false)), hop_age)
		_IdleLife.apply(sp, rec[3], p)
		_animated += 1
