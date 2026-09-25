## Character presence: per-frame presentation of registered world characters.
##
##   * contact shadows (GID-131 / TID-503) — writes the nearest
##     `ContactShadow.MAX_CASTERS` casters (player first) into the
##     `contact_shadow_*` shader globals that terrain and grass shaders read;
##     casters register with `ContactShadow.register()` in `_ready`.
##   * wall cutaway focus — writes the player's position to the
##     `occlusion_focus` global so terrain between the camera and the player
##     dithers away (moved here from WorldScene._process).
##   * idle life (GID-132 / TID-511) — breathes/bobs/floats every sprite
##     registered with `IdleLife.register()` within `IdleLife.MAX_DISTANCE`.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _ContactShadow = preload("res://game_logic/ContactShadow.gd")
const _IdleLife = preload("res://game_logic/IdleLife.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")

var _world: _WorldScene = null
var _written: Array[Vector4] = []
var _time: float = 0.0
var _animated: int = 0
var _glow: float = 0.0
var _glow_written: float = -1.0


func _ready() -> void:
	RenderingServer.global_shader_parameter_set(_ContactShadow.OPACITY_PARAM,
			_ContactShadow.opacity_for(_world.graphics_knobs()) if _world != null else 0.0)


func _exit_tree() -> void:
	# The globals outlive the scene: clear them so a battle or menu 3D view
	# never shows stale pools.
	for i: int in _ContactShadow.MAX_CASTERS:
		RenderingServer.global_shader_parameter_set(_ContactShadow.PARAM_PREFIX + str(i), _ContactShadow.EMPTY)


## Slots currently written (tests, debugging).
func slots() -> Array[Vector4]:
	return _written


## Sprites posed on the last frame (tests, debugging).
func animated_count() -> int:
	return _animated


func apply_knobs(knobs: Dictionary) -> void:
	RenderingServer.global_shader_parameter_set(_ContactShadow.OPACITY_PARAM, _ContactShadow.opacity_for(knobs))


func _process(delta: float) -> void:
	if _world == null or _world._player == null:
		return
	_time += delta
	var center: Vector3 = _world._player.global_position
	RenderingServer.global_shader_parameter_set("occlusion_focus", _world._player.position)
	_update_idle_life(center)
	_update_hero(delta)
	var casters: Array[Vector4] = []
	for n: Node in get_tree().get_nodes_in_group(_ContactShadow.GROUP):
		var n3 := n as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		var p: Vector3 = n3.global_position
		var r: float = float(n3.get_meta(_ContactShadow.META_RADIUS, _ContactShadow.MIN_RADIUS)) * n3.scale.x
		casters.append(Vector4(p.x, p.y, p.z, r))
	var slots_now: Array[Vector4] = _ContactShadow.pick_slots(casters, center)
	for i: int in slots_now.size():
		if i < _written.size() and _written[i] == slots_now[i]:
			continue
		RenderingServer.global_shader_parameter_set(_ContactShadow.PARAM_PREFIX + str(i), slots_now[i])
	_written = slots_now


## Hero touches (GID-134 / TID-526): walk/breath bob and a warm outline pulse
## while something is in reach.
func _update_hero(delta: float) -> void:
	var pl := _world._player
	var spr: AnimatedSprite3D = pl._sprite
	if spr == null:
		return
	pl.visual_bob = _IdleLife.hero_bob(spr.animation == &"walk" and spr.is_playing(), spr.frame, _time)
	var near: bool = _world._world_hud != null and _world._world_hud.interact_prompt_visible
	_glow = move_toward(_glow, 1.0 if near else 0.0, delta * 4.0)
	var g: float = _glow * (0.7 + 0.3 * sin(_time * 5.0))
	if absf(g - _glow_written) > 0.02 or (g == 0.0 and _glow_written != 0.0):
		_glow_written = g
		_SpriteOutline.set_glow(spr, g)


func _update_idle_life(center: Vector3) -> void:
	_animated = 0
	var max_d2: float = _IdleLife.MAX_DISTANCE * _IdleLife.MAX_DISTANCE
	for n: Node in get_tree().get_nodes_in_group(_IdleLife.GROUP):
		var sp := n as Node3D
		if sp == null or not sp.is_visible_in_tree():
			continue
		if sp.global_position.distance_squared_to(center) > max_d2:
			continue
		var hop_age: float = -1.0
		if sp.has_meta(_IdleLife.META_HOP):
			hop_age = _IdleLife.now() - float(sp.get_meta(_IdleLife.META_HOP))
		var p: Vector2 = _IdleLife.pose(int(sp.get_meta(_IdleLife.META_STYLE, 0)), _time,
				float(sp.get_meta(_IdleLife.META_PHASE, 0.0)), bool(sp.get_meta(_IdleLife.META_FAST, false)), hop_age)
		_IdleLife.apply(sp, sp.get_meta(_IdleLife.META_BASE, sp.position), p)
		_animated += 1
