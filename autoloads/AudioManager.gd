extends Node

const _SfxGen = preload("res://game_logic/SfxGen.gd")
const _AmbienceGen = preload("res://game_logic/AmbienceGen.gd")
const _AmbienceLayers = preload("res://game_logic/AmbienceLayers.gd")
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
const _FootstepSurface = preload("res://game_logic/FootstepSurface.gd")

# Ambient sound paths per biome (index matches IsoConst biome IDs / InfiniteWorldGen biomes).
# Placeholder paths: gracefully skipped if the file doesn't exist.
const AMBIENCE_PATHS: Array[String] = [
	"res://assets/audio/ambience/grasslands.ogg",  # 0 Grasslands
	"res://assets/audio/ambience/forest.ogg",      # 1 Forest
	"res://assets/audio/ambience/desert.ogg",      # 2 Desert
	"res://assets/audio/ambience/scorched.ogg",    # 3 Scorched
	"res://assets/audio/ambience/mountains.ogg",   # 4 Mountains
]
const AMBIENCE_CROSSFADE: float = 2.0
# Layer loudness relative to the SFX volume (GID-129 / TID-490).
const BIOME_LAYER_GAIN: float = 0.4
const WEATHER_LAYER_GAIN: float = 0.5
const TIME_LAYER_GAIN: float = 0.3
const WATER_LAYER_GAIN: float = 0.45  # stream babble near water (TID-644), × proximity
const _SILENT_DB: float = -80.0

# Music ducking fade times (levels live in AmbienceLayers.music_duck).
const DUCK_DOWN_TIME: float = 0.4
const DUCK_UP_TIME: float = 1.0

# Map from SFX name → file path
const SFX_PATHS: Dictionary = {
	"card_draw":    "res://assets/audio/sfx/card_draw.ogg",
	"card_play":    "res://assets/audio/sfx/card_play.ogg",
	"spell_resolve": "res://assets/audio/sfx/spell_resolve.ogg",
	"attack":       "res://assets/audio/sfx/attack.ogg",
	"battle_win":   "res://assets/audio/sfx/battle_win.ogg",
	"battle_lose":  "res://assets/audio/sfx/battle_lose.ogg",
	"enemy_engage": "res://assets/audio/sfx/enemy_engage.ogg",
	"enemy_alert":  "res://assets/audio/sfx/enemy_alert.ogg",
	"chest_open":   "res://assets/audio/sfx/chest_open.ogg",
	"scroll_pickup": "res://assets/audio/sfx/scroll_pickup.ogg",
	"door_enter":   "res://assets/audio/sfx/door_enter.ogg",
	"footstep":       "res://assets/audio/sfx/footstep.ogg",
	# Terrain-aware steps (GID-129 / TID-491); see FootstepSurface.
	"footstep_grass": "res://assets/audio/sfx/footstep_grass.ogg",
	"footstep_sand":  "res://assets/audio/sfx/footstep_sand.ogg",
	"footstep_stone": "res://assets/audio/sfx/footstep_stone.ogg",
	"footstep_snow":  "res://assets/audio/sfx/footstep_snow.ogg",
	"footstep_wood":  "res://assets/audio/sfx/footstep_wood.ogg",
	"footstep_water": "res://assets/audio/sfx/footstep_water.ogg",
	"footstep_hoof":  "res://assets/audio/sfx/footstep_hoof.ogg",
	"nightfall_ambient": "res://assets/audio/sfx/nightfall_ambient.ogg",
	"ui_click":     "res://assets/audio/sfx/ui_click.ogg",
	"land":         "res://assets/audio/sfx/land.ogg",
	"dig_success":  "res://assets/audio/sfx/dig_success.ogg",
	"waystone_travel": "res://assets/audio/sfx/waystone_travel.ogg",
	# Storm lightning (GID-129 / TID-487), played after the flash by WorldScene.
	"thunder":      "res://assets/audio/sfx/thunder.ogg",
}
## Extra takes per key (GID-145 / TID-615): `<key>_2.ogg` … `<key>_N.ogg` beside
## the base file. Keys listed here play a random take (never the same twice in a
## row) through an AudioStreamRandomizer.
const SFX_TAKES: Dictionary = {
	"card_draw": 4, "card_play": 4, "attack": 5, "scroll_pickup": 3, "door_enter": 2,
	"footstep": 5, "footstep_grass": 5, "footstep_sand": 3, "footstep_stone": 5,
	"footstep_snow": 5, "footstep_wood": 5, "footstep_water": 3, "footstep_hoof": 4,
	"ui_click": 3, "land": 3,
}
## Mix trim per key. The files are peak-normalised (TID-614), so frequent or
## background sounds sit below the one-off stingers.
const SFX_GAIN_DB: Dictionary = {
	"footstep": -9.0, "footstep_grass": -9.0, "footstep_sand": -9.0, "footstep_stone": -9.0,
	"footstep_snow": -9.0, "footstep_wood": -9.0, "footstep_water": -9.0, "footstep_hoof": -8.0,
	"ui_click": -8.0, "land": -6.0, "card_draw": -5.0, "card_play": -4.0,
	"scroll_pickup": -3.0, "nightfall_ambient": -4.0, "battle_win": -3.0, "battle_lose": -3.0,
	"thunder": -2.0,
}
const _POOL_SIZE: int = 8

var _players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
## SFX_GAIN_DB for keys backed by a real file; synthesized fallbacks keep their own level.
var _sfx_trim_db: Dictionary = {}
var _sfx_db: float = 0.0   # SFX setting; per-play jitter never writes it back
var _jitter_rng := RandomNumberGenerator.new()

var _narration_player: AudioStreamPlayer
var _narration_suppressed: bool = false

var _music_player: AudioStreamPlayer
var _current_music_path: String = ""
var _music_linear: float = 0.5   # user setting; the player volume is this * _duck
var _duck: float = 1.0
var _duck_target: float = 1.0
var _duck_tween: Tween = null
var _dialogue_active: bool = false


## One ambience loop slot: two players crossfade whenever its key changes.
class AmbLayer:
	var players: Array[AudioStreamPlayer] = []
	var tweens: Array[Tween] = [null, null]  # one volume tween per player
	var active: int = 0
	var key: String = ""       # "" = silent
	var gain: float = 0.0      # linear, before the SFX volume


var _biome_layer := AmbLayer.new()
var _weather_layer := AmbLayer.new()
var _time_layer := AmbLayer.new()
var _water_layer := AmbLayer.new()
var _amb_biome: int = -1          # currently playing biome id (-1 = none / named map)
var _weather_id: String = ""      # last WeatherManager weather id
var _in_named_map: bool = false
var _named_outdoors: bool = false
var _have_time: bool = false      # false until WorldScene reports a time of day
var _is_day: bool = true
var _layers_dirty: bool = false

func _ready() -> void:
	for key: String in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		var stream: AudioStream = _load_sfx_takes(path, int(SFX_TAKES.get(key, 1)))
		if stream != null:
			_sfx_cache[key] = stream
			_sfx_trim_db[key] = float(SFX_GAIN_DB.get(key, 0.0))
	# Any key without a real file asset falls back to a procedurally
	# synthesized sound (game_logic/SfxGen.gd) — see CLAUDE.md "Android:
	# Always preload()" and TID-425: no external audio assets required.
	for key: String in _SfxGen.all_keys():
		if not _sfx_cache.has(key):
			_sfx_cache[key] = _SfxGen.get_sfx(key)
	for key: String in _FootstepSurface.all_keys():
		if not _sfx_cache.has(key):
			_sfx_cache[key] = _FootstepSurface.get_sfx(key)
	_jitter_rng.randomize()
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_narration_player = AudioStreamPlayer.new()
	_narration_player.volume_db = -3.0
	add_child(_narration_player)
	_narration_player.finished.connect(_update_duck)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_apply_music_volume()
	_music_player.finished.connect(_on_music_finished)
	# Ambience layers, each a crossfade pair
	for layer: AmbLayer in _all_layers():
		for _i in 2:
			var ap := AudioStreamPlayer.new()
			ap.volume_db = _SILENT_DB
			add_child(ap)
			layer.players.append(ap)
	GameBus.dialogue_state_changed.connect(_on_dialogue_state_changed)
	GameBus.weather_changed.connect(_on_weather_changed)
	GameBus.weather_settings_changed.connect(func() -> void:
		_weather_id = WeatherManager.shown(WeatherManager.current_weather)
		_layers_dirty = true)
	GameBus.entered_named_map.connect(_on_entered_named_map)

func play_narration(scroll_id: String) -> void:
	if _narration_suppressed:
		return
	var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
	if scroll.is_empty():
		return
	var path: String = scroll.get("audio_path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_narration_player.stop()
	_narration_player.stream = stream
	_narration_player.play()
	_update_duck()

func set_narration_suppressed(suppressed: bool) -> void:
	_narration_suppressed = suppressed
	if suppressed:
		_narration_player.stop()

func _on_dialogue_state_changed(active: bool) -> void:
	_dialogue_active = active
	set_narration_suppressed(active)
	_update_duck()

# ── Music ─────────────────────────────────────────────────────────────────

func play_music(path: String) -> void:
	if path == _current_music_path and _music_player.playing:
		return
	_current_music_path = path
	if path.is_empty():
		_music_player.stop()
		return
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()

func _on_music_finished() -> void:
	if not _current_music_path.is_empty() and _music_player.stream != null:
		_music_player.play()

func set_music_volume(linear: float) -> void:
	_music_linear = maxf(linear, 0.0)
	_apply_music_volume()

## Pulls the music down under NPC dialogue and scroll narration, and back up
## once both are gone. Only the playing volume moves; the setting is untouched.
func _update_duck() -> void:
	var narrating: bool = _narration_player != null and _narration_player.playing
	var target: float = _AmbienceLayers.music_duck(_dialogue_active, narrating)
	if is_equal_approx(target, _duck_target):
		return
	_duck_target = target
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if not is_inside_tree():
		_set_duck(target)
		return
	var dur: float = DUCK_DOWN_TIME if target < _duck else DUCK_UP_TIME
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, target, dur)

func _set_duck(v: float) -> void:
	_duck = v
	_apply_music_volume()

func _apply_music_volume() -> void:
	if _music_player != null:
		_music_player.volume_db = linear_to_db(maxf(_music_linear * _duck, 0.0001))

# ── SFX ───────────────────────────────────────────────────────────────────

func set_sfx_volume(linear: float) -> void:
	_sfx_db = linear_to_db(maxf(linear, 0.0001))
	for p: AudioStreamPlayer in _players:
		p.volume_db = _sfx_db
	# Ambience layers follow the SFX setting.
	for layer: AmbLayer in _all_layers():
		_retarget_layer(layer)

func get_sfx_volume() -> float:
	return db_to_linear(_sfx_db)

func play_sfx(sfx_name: String) -> void:
	_play_pooled(sfx_name, 1.0, _sfx_db)

## play_sfx with a random pitch (± pitch_jitter, around `pitch`) and volume
## (± vol_jitter_db) per call, so repeated sounds like footsteps don't loop
## robotically. Falls back to plain "footstep" if the key has no stream.
func play_sfx_varied(sfx_name: String, pitch: float = 1.0,
		pitch_jitter: float = 0.08, vol_jitter_db: float = 1.5) -> void:
	var p_scale: float = pitch * (1.0 + _jitter_rng.randf_range(-pitch_jitter, pitch_jitter))
	var db: float = _sfx_db + _jitter_rng.randf_range(-vol_jitter_db, vol_jitter_db)
	if not _sfx_cache.has(sfx_name):
		sfx_name = "footstep"
	_play_pooled(sfx_name, p_scale, db)

## The base file plus its `_2` … `_N` takes; several takes come back as one
## AudioStreamRandomizer. Null when the base file is missing (synth fallback).
func _load_sfx_takes(path: String, count: int) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var base := load(path) as AudioStream
	if base == null or count <= 1:
		return base
	var rnd := AudioStreamRandomizer.new()
	rnd.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	rnd.random_pitch = 1.0  # play_sfx_varied already jitters pitch
	rnd.random_volume_offset_db = 0.0
	rnd.add_stream(-1, base)
	for i: int in range(2, count + 1):
		var take_path: String = path.get_basename() + "_%d.ogg" % i
		if ResourceLoader.exists(take_path):
			var take := load(take_path) as AudioStream
			if take != null:
				rnd.add_stream(-1, take)
	return rnd if rnd.streams_count > 1 else base

func _play_pooled(sfx_name: String, pitch_scale: float, volume_db: float) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name, null) as AudioStream
	if stream == null or _players.is_empty():
		return
	volume_db += float(_sfx_trim_db.get(sfx_name, 0.0))
	var target: AudioStreamPlayer = _players[0]
	for p in _players:
		if not p.playing:
			target = p
			break
	target.stream = stream
	target.pitch_scale = maxf(pitch_scale, 0.01)
	target.volume_db = volume_db
	target.play()

func _process(_delta: float) -> void:
	# Loop each layer's active player when it finishes (real .ogg files may
	# not be flagged to loop; the synthesized fallbacks already loop).
	for layer: AmbLayer in _all_layers():
		if layer.key.is_empty():
			continue
		var p: AudioStreamPlayer = layer.players[layer.active]
		if p.stream != null and not p.playing:
			p.play()
	# Weather / time changes wait out a battle: only the music changes there.
	if _layers_dirty and not _in_battle():
		_layers_dirty = false
		_refresh_weather_layer()
		_refresh_time_layer()

# ── Ambience ──────────────────────────────────────────────────────────────

## Switch biome ambience with a crossfade. biome_id=-1 (named map) fades out
## without starting a new loop, and mutes the weather layer.
func set_ambience(biome_id: int) -> void:
	if biome_id == _amb_biome:
		return
	_amb_biome = biome_id
	if biome_id >= 0:
		_in_named_map = false
		# WeatherManager only reports changes; resume whatever is current.
		_weather_id = WeatherManager.shown(WeatherManager.current_weather)
	else:
		_in_named_map = true
		_named_outdoors = false  # entered_named_map (emitted next) may say otherwise
	_layers_dirty = true
	if biome_id < 0 or biome_id >= AMBIENCE_PATHS.size():
		_crossfade_layer(_biome_layer, "", null, 0.0)
		return
	var path: String = AMBIENCE_PATHS[biome_id]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		stream = _SfxGen.get_ambience(biome_id)
	_crossfade_layer(_biome_layer, "biome_%d" % biome_id, stream, BIOME_LAYER_GAIN)

## Fed every frame by WorldScene from DayNightCycle. Cheap: only a change of
## the (hysteresis-filtered) day/night state touches the time layer.
func set_time_of_day(time_of_day: float) -> void:
	var day: bool
	if _have_time:
		day = _AmbienceLayers.next_is_day(time_of_day, _is_day)
	else:
		day = sin((time_of_day - 0.25) * TAU) >= 0.0
	if _have_time and day == _is_day:
		return
	_have_time = true
	_is_day = day
	_layers_dirty = true

func _all_layers() -> Array[AmbLayer]:
	return [_biome_layer, _weather_layer, _time_layer, _water_layer]

## Stream babble near water (GID-152 / TID-644): `amount` 0..1 from
## AmbienceLayers.stream_gain(); 0 fades the layer out.
func set_water_proximity(amount: float) -> void:
	var key: String = "stream" if amount > 0.01 else ""
	_crossfade_layer(_water_layer, key, _layer_stream(key), WATER_LAYER_GAIN * amount)

func _in_battle() -> bool:
	return SceneManager.current_state() == _SceneFlow.State.BATTLE

func _on_weather_changed(weather_id: String, _duration: float) -> void:
	_weather_id = WeatherManager.shown(weather_id)
	_layers_dirty = true

func _on_entered_named_map(map_name: String) -> void:
	_in_named_map = true
	_named_outdoors = _AmbienceLayers.named_map_is_outdoors(map_name)
	_layers_dirty = true

func _refresh_weather_layer() -> void:
	# Weather only runs on the overworld; every named map is weather-free.
	var key: String = "" if _in_named_map else _AmbienceLayers.weather_layer(_weather_id)
	var gain: float = WEATHER_LAYER_GAIN * _AmbienceLayers.weather_gain(_weather_id)
	_crossfade_layer(_weather_layer, key, _layer_stream(key), gain)

func _refresh_time_layer() -> void:
	var biome: int = _amb_biome
	if _in_named_map:
		biome = _AmbienceLayers.NAMED_MAP_TIME_BIOME if _named_outdoors else -1
	var key: String = ""
	if _have_time:
		key = _AmbienceLayers.time_layer(biome, _is_day, _weather_layer.key)
	_crossfade_layer(_time_layer, key, _layer_stream(key), TIME_LAYER_GAIN)

func _layer_stream(key: String) -> AudioStream:
	if key.is_empty():
		return null
	var path: String = _AmbienceLayers.LAYER_PATHS.get(key, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			return stream
	return _AmbienceGen.get_layer(key)

func _layer_db(layer: AmbLayer) -> float:
	return linear_to_db(maxf(get_sfx_volume() * layer.gain, 0.0001))

## Tweens one player of `layer` to `db`, replacing any tween already on it.
func _fade_player(layer: AmbLayer, idx: int, db: float, dur: float, stop_after: bool) -> void:
	var prev: Tween = layer.tweens[idx]
	if prev != null and prev.is_valid():
		prev.kill()
	var p: AudioStreamPlayer = layer.players[idx]
	var tw: Tween = create_tween()
	tw.tween_property(p, "volume_db", db, dur)
	if stop_after:
		tw.tween_callback(p.stop)
	layer.tweens[idx] = tw

## Crossfades `layer` to `key`. Same key only retargets the volume (e.g. snow
## → blizzard wind); "" fades the layer out.
func _crossfade_layer(layer: AmbLayer, key: String, stream: AudioStream, gain: float) -> void:
	layer.gain = gain
	if key == layer.key:
		_retarget_layer(layer)
		return
	layer.key = key
	var old_idx: int = layer.active
	layer.active = 1 - old_idx
	if layer.players[old_idx].playing:
		_fade_player(layer, old_idx, _SILENT_DB, AMBIENCE_CROSSFADE, true)
	var new_p: AudioStreamPlayer = layer.players[layer.active]
	var prev: Tween = layer.tweens[layer.active]
	if prev != null and prev.is_valid():
		prev.kill()
	new_p.stop()
	if key.is_empty() or stream == null:
		new_p.stream = null
		return
	new_p.stream = stream
	new_p.volume_db = _SILENT_DB
	new_p.play()
	_fade_player(layer, layer.active, _layer_db(layer), AMBIENCE_CROSSFADE, false)

func _retarget_layer(layer: AmbLayer) -> void:
	if layer.key.is_empty() or layer.players.is_empty():
		return
	_fade_player(layer, layer.active, _layer_db(layer), 0.5, false)
