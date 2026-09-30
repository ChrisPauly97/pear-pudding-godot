## Day/night wiring (BID-055 slice): builds WorldScene's DayNightCycle
## (`_world._dnc`) and dawn/dusk sun rays (`_world._sun_rays`), connects their
## day / night / dawn / storm reactions, and ticks the clock each frame. The two
## nodes stay WorldScene children and fields because other modules share them.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")
const _SunRaysFx = preload("res://scenes/world/SunRaysFx.gd")

var _world: _WorldScene = null
var _night_cue_played: bool = false


func setup() -> void:
	var w := _world
	# DayNightCycle owns time-of-day advancement, sun/moon lighting, and sky color.
	w._dnc = DayNightCycle.new()
	w._dnc.name = "DayNightCycle"
	w.add_child(w._dnc)
	w._dnc.setup(w._sun, w._moon, w._world_env, w._is_infinite, w.day_duration,
		SceneManager.save_manager.time_of_day)
	w._sun_rays = _SunRaysFx.new()
	w._sun_rays.name = "SunRays"
	w.add_child(w._sun_rays)
	w._sun_rays.setup(w._camera, w._sun, w._moon, w._world_env.environment, w._dnc)
	w._dnc.day_passed.connect(_on_day_passed)
	if not w._is_infinite:
		return
	w._dnc.night_started.connect(func() -> void:
		if not _night_cue_played:
			_night_cue_played = true
			AudioManager.play_sfx("nightfall_ambient")
	)
	w._dnc.dawn_arrived.connect(func() -> void:
		w.nocturnal.despawn_all(true)
		_night_cue_played = false
	)
	# Storm lightning (TID-487): thunder after the flash; reduce-flashing read live.
	w._dnc.thunder_rumbled.connect(func(pitch: float) -> void: AudioManager.play_sfx_varied("thunder", pitch, 0.05))
	w._dnc.flashing_allowed = func() -> bool: return not bool(
		SceneManager.save_manager.get_setting("reduce_flashing", false))
	w._dnc.storms_allowed = WeatherManager.storms_enabled


## Advances the clock and feeds the day/night ambience layer (runs before the
## player null-check, so dedicated servers keep time too).
func tick(delta: float) -> void:
	if _world._dnc:
		_world._dnc.tick(delta)
		AudioManager.set_time_of_day(_world._dnc.get_time_of_day())


func _on_day_passed() -> void:
	SceneManager.save_manager.increment_day()
	GameBus.blight_changed.emit()
	# GID-103 (TID-382): advance the shared co-op day counter (BID-039) — only the
	# authority owns SessionState.days_elapsed; clients learn the new value from
	# the next env broadcast.
	if _world._coop_active and NetworkManager.is_host() and SessionStore.is_open():
		var st_day = SessionStore.get_state()
		if st_day != null:
			st_day.days_elapsed += 1
			SessionStore.mark_dirty()
