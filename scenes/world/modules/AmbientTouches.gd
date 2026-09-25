## Small ambient touches (GID-129 / TID-493): night fireflies in grassland and
## forest, wind-blown leaves in forest, the player's dust quality, and low
## ground mist at night and dawn (GID-130 / TID-497, knob `ground_mist`).
##
## One firefly and one leaf emitter (AmbientParticles factories) follow the
## player. Every REFRESH_INTERVAL the module re-reads the GraphicsQuality knobs
## (`ambient_particles`, `particle_scale`), the biome, the night factor and the
## blended weather wind (`_dnc.weather_look()`), then fades each emitter with
## `amount_ratio`. `amount` is only rewritten when the tier changes, because
## writing it restarts the system. Low (ambient_particles off) and named maps
## (no biome) show nothing and cost nothing.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")
const _NightLightMath = preload("res://game_logic/NightLightMath.gd")
const _GraphicsQuality = preload("res://game_logic/GraphicsQuality.gd")
const _AmbientParticles = preload("res://game_logic/AmbientParticles.gd")

const REFRESH_INTERVAL: float = 0.5
const FIREFLY_LIFT: float = 1.0
const LEAF_LIFT: float = 7.0
const MIST_LIFT: float = 0.4

var _world: _WorldScene = null

var _fireflies: GPUParticles3D = null
var _leaves: GPUParticles3D = null
var _mist: GPUParticles3D = null
var _refresh_in: float = 0.0
var _knobs_hash: int = 0
var _firefly_level: float = 0.0
var _leaf_level: float = 0.0
var _mist_level: float = 0.0


## Current densities (0..1); exposed for tests and debugging.
func firefly_level() -> float:
	return _firefly_level


func leaf_level() -> float:
	return _leaf_level


func mist_level() -> float:
	return _mist_level


func _process(delta: float) -> void:
	if _world == null or _world._player == null:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_INTERVAL
		refresh()
	_follow()


func _follow() -> void:
	var p: Vector3 = _world._player.global_position
	if _fireflies != null:
		_fireflies.global_position = p + Vector3(0.0, FIREFLY_LIFT, 0.0)
	if _leaves != null:
		_leaves.global_position = p + Vector3(0.0, LEAF_LIFT, 0.0)
	if _mist != null:
		_mist.global_position = p + Vector3(0.0, MIST_LIFT, 0.0)


## Re-reads knobs, biome, night and wind and applies them to the emitters.
func refresh() -> void:
	var knobs: Dictionary = _world.graphics_knobs()
	var h: int = knobs.hash()
	var knobs_changed: bool = h != _knobs_hash
	_knobs_hash = h
	if knobs_changed:
		_world._player.apply_particle_knobs(knobs)
	var on: bool = bool(knobs.get("ambient_particles", false)) and _world._is_infinite
	var biome: int = _world._current_biome if on else -1
	var weather: String = WeatherManager.current_weather
	var night: float = 0.0
	var sun_h: float = 1.0
	if _world._dnc != null:
		sun_h = _DayNightCycle.sun_direction(_world._dnc.get_time_of_day()).y
		night = _NightLightMath.night_factor(sun_h)
	var look: Dictionary = _world._dnc.weather_look() if _world._dnc != null else {}
	var wind_dir: Vector2 = look.get("wind_direction", Vector2(1.0, 0.0))
	var wind_scale: float = float(look.get("wind_scale", 1.0))
	_firefly_level = _AmbientParticles.firefly_level(night, biome, weather)
	_leaf_level = _AmbientParticles.leaf_level(biome, weather, wind_scale)
	if _firefly_level > 0.0 and _fireflies == null:
		_fireflies = _spawn(_AmbientParticles.make_fireflies(), knobs)
	if _leaf_level > 0.0 and _leaves == null:
		_leaves = _spawn(_AmbientParticles.make_leaves(), knobs)
	var mist_biome: int = _world._current_biome if bool(knobs.get("ground_mist", false)) and _world._is_infinite else -1
	_mist_level = _AmbientParticles.mist_level(sun_h, mist_biome, weather)
	if _mist_level > 0.0 and _mist == null:
		_mist = _spawn(_AmbientParticles.make_mist(), knobs)
	_follow()
	_apply(_fireflies, _firefly_level, _AmbientParticles.FIREFLY_AMOUNT, knobs, knobs_changed)
	_apply(_leaves, _leaf_level, _AmbientParticles.LEAF_AMOUNT, knobs, knobs_changed)
	_apply(_mist, _mist_level, _AmbientParticles.MIST_AMOUNT, knobs, knobs_changed)
	if _mist != null and _mist_level > 0.0:
		_AmbientParticles.apply_mist_wind(_mist.process_material as ParticleProcessMaterial, wind_dir, wind_scale)
		_AmbientParticles.set_mist_tint(_AmbientParticles.mist_color(sun_h))
	if _leaves != null and _leaf_level > 0.0:
		_AmbientParticles.apply_wind(_leaves.process_material as ParticleProcessMaterial, wind_dir, wind_scale)


func _spawn(node: GPUParticles3D, knobs: Dictionary) -> GPUParticles3D:
	node.amount = _GraphicsQuality.scaled_amount(node.amount, knobs)
	node.amount_ratio = 0.0
	_world._entity_root.add_child(node)
	return node


func _apply(node: GPUParticles3D, level: float, base: int, knobs: Dictionary, knobs_changed: bool) -> void:
	if node == null:
		return
	if knobs_changed:
		var want: int = _GraphicsQuality.scaled_amount(base, knobs)
		if node.amount != want:
			node.amount = want
	node.amount_ratio = level
	var emit: bool = level > 0.0
	if node.emitting != emit:
		node.emitting = emit
	node.visible = emit
