## Small ambient touches (GID-129 / TID-493): night fireflies in grassland and
## forest, wind-blown leaves in forest, the player's dust quality, and low
## ground mist at night and dawn (GID-130 / TID-497, knob `ground_mist`), and
## rain splash rings + droplets (GID-133 / TID-514, knob `ambient_particles`).
##
## One firefly and one leaf emitter (AmbientParticles factories) follow the
## player. Every REFRESH_INTERVAL the module re-reads the GraphicsQuality knobs
## (`ambient_particles`, `particle_scale`), the biome, the night factor and the
## blended weather wind (`_dnc.weather_look()`), then fades each emitter with
## `amount_ratio`. `amount` is only rewritten when the tier changes, because
## writing it restarts the system. Low (ambient_particles off) and named maps
## (no biome) show nothing and cost nothing.
extends Node

## Ground wetness above which footsteps splash instead of kicking up dust.
const WET_SPLASH_THRESHOLD: float = 0.3
const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")
const _NightLightMath = preload("res://game_logic/NightLightMath.gd")
const _GraphicsQuality = preload("res://game_logic/GraphicsQuality.gd")
const _AmbientParticles = preload("res://game_logic/AmbientParticles.gd")
const _RainParticles = preload("res://game_logic/RainParticles.gd")
const _WeatherParticles = preload("res://scenes/world/WeatherParticles.gd")
const _WaterMath = preload("res://game_logic/world/WaterMath.gd")
const _ChunkRenderer = preload("res://scenes/world/ChunkRenderer.gd")

const REFRESH_INTERVAL: float = 0.5
const FIREFLY_LIFT: float = 1.0
const LEAF_LIFT: float = 7.0
const MIST_LIFT: float = 0.4
const WEATHER_RIG_LIFT: float = 12.0

var _world: _WorldScene = null

var _fireflies: GPUParticles3D = null
var _leaves: GPUParticles3D = null
var _mist: GPUParticles3D = null
var _rings: GPUParticles3D = null
var _drops: GPUParticles3D = null
var _refresh_in: float = 0.0
var _knobs_hash: int = 0
var _firefly_level: float = 0.0
var _leaf_level: float = 0.0
var _mist_level: float = 0.0
var _splash_level: float = 0.0
var _weather_rig: GPUParticles3D = null
var _ground_wet: bool = false
var _weather_raw: String = ""  # last weather applied, before the Weather Effects filter


## Current densities (0..1); exposed for tests and debugging.
func firefly_level() -> float:
	return _firefly_level


func leaf_level() -> float:
	return _leaf_level


func mist_level() -> float:
	return _mist_level


func splash_level() -> float:
	return _splash_level


func _ready() -> void:
	GameBus.weather_settings_changed.connect(func() -> void: apply_weather(_weather_raw))


func _exit_tree() -> void:
	_free_weather_rig()


## Weather visuals: particle rig, sky/fog look (DayNightCycle, TID-486) and grass
## wind. Settings > Weather Effects off shows clear skies; the weather still runs.
func apply_weather(raw_weather_id: String) -> void:
	_weather_raw = raw_weather_id
	var weather_id: String = WeatherManager.shown(raw_weather_id)
	_free_weather_rig()
	if weather_id != "":
		var particles := _WeatherParticles.make(weather_id) as GPUParticles3D
		if particles != null:
			particles.amount = _GraphicsQuality.scaled_amount(particles.amount, _world.graphics_knobs())
			_world._entity_root.add_child(particles)
			_weather_rig = particles
			_follow()
	if _world._dnc != null:
		_world._dnc.set_weather(weather_id)
	if _world._grass != null:
		_world._grass.set_wind_direction(_WeatherParticles.get_wind_direction(weather_id))


## Wet ground (rain) turns the player's footstep dust into water splashes.
func _apply_ground_wet(wet: bool) -> void:
	if wet == _ground_wet:
		return
	_ground_wet = wet
	var pl := _world._player
	for pm: Variant in [pl._dust_mat_foot, pl._dust_mat_mount, pl._landing_dust.process_material,
			pl._start_dust.process_material]:
		if pm is ParticleProcessMaterial:
			_AmbientParticles.set_wet(pm as ParticleProcessMaterial, wet)


func _free_weather_rig() -> void:
	if is_instance_valid(_weather_rig):
		_weather_rig.queue_free()
	_weather_rig = null


func _process(delta: float) -> void:
	if _world == null or _world._player == null:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_INTERVAL
		refresh()
	_follow()


func _follow() -> void:
	if _world._player == null:
		return
	var p: Vector3 = _world._player.global_position
	if is_instance_valid(_weather_rig):
		_weather_rig.position = _world._player.position + Vector3(0.0, WEATHER_RIG_LIFT, 0.0)
	if _fireflies != null:
		_fireflies.global_position = p + Vector3(0.0, FIREFLY_LIFT, 0.0)
	if _leaves != null:
		_leaves.global_position = p + Vector3(0.0, LEAF_LIFT, 0.0)
	if _mist != null:
		_mist.global_position = p + Vector3(0.0, MIST_LIFT, 0.0)
	var ground: Vector3 = p + Vector3(0.0, _RainParticles.RING_LIFT, 0.0)
	if _rings != null:
		_rings.global_position = ground
	if _drops != null:
		_drops.global_position = ground


## Re-reads knobs, biome, night and wind and applies them to the emitters.
func refresh() -> void:
	var knobs: Dictionary = _world.graphics_knobs()
	var h: int = knobs.hash()
	var knobs_changed: bool = h != _knobs_hash
	_knobs_hash = h
	if knobs_changed:
		_world._player.apply_particle_knobs(knobs)
	var p: Vector3 = _world._player.global_position
	var wading: bool = (_world._is_infinite and _world._csm != null
			and _WaterMath.biome_has_water(_world._current_biome)
			and _ChunkRenderer.water_at_world(_world._csm, p.x, p.z, SceneManager.save_manager.world_seed)
				> _WaterMath.WET_LEVEL)
	_apply_ground_wet(wading or (_world._dnc != null and _world._dnc.wetness() > WET_SPLASH_THRESHOLD))
	var on: bool = bool(knobs.get("ambient_particles", false)) and _world._is_infinite
	var biome: int = _world._current_biome if on else -1
	var weather: String = WeatherManager.shown(WeatherManager.current_weather)
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
	# Rain splashes work on named maps too (towns get rain), unlike biome touches.
	_splash_level = _RainParticles.splash_level(weather, bool(knobs.get("ambient_particles", false)))
	if _splash_level > 0.0 and _rings == null:
		_rings = _spawn(_RainParticles.make_rings(), knobs)
		_drops = _spawn(_RainParticles.make_drops(), knobs)
		_follow()
	_apply(_rings, _splash_level, _RainParticles.RING_AMOUNT, knobs, knobs_changed)
	_apply(_drops, _splash_level, _RainParticles.DROP_AMOUNT, knobs, knobs_changed)
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
