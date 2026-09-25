## Contact shadows (GID-131 / TID-503): each frame, writes the nearest
## `ContactShadow.MAX_CASTERS` registered casters (player first) into the
## `contact_shadow_*` shader globals that terrain and grass shaders read.
## Casters register themselves with `ContactShadow.register()` in `_ready`.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _ContactShadow = preload("res://game_logic/ContactShadow.gd")

var _world: _WorldScene = null
var _written: Array[Vector4] = []


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


func apply_knobs(knobs: Dictionary) -> void:
	RenderingServer.global_shader_parameter_set(_ContactShadow.OPACITY_PARAM, _ContactShadow.opacity_for(knobs))


func _process(_delta: float) -> void:
	if _world == null or _world._player == null:
		return
	var center: Vector3 = _world._player.global_position
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
