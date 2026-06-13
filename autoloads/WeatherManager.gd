extends Node

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

# Per-biome weather tables: biome_id -> Array[Dictionary{id, weight}]
const _BIOME_TABLES: Dictionary = {
	0: [  # GRASSLANDS
		{"id": "",           "weight": 60.0},
		{"id": "rain",       "weight": 30.0},
		{"id": "heavy_rain", "weight": 10.0},
	],
	1: [  # FOREST
		{"id": "",           "weight": 60.0},
		{"id": "rain",       "weight": 30.0},
		{"id": "heavy_rain", "weight": 10.0},
	],
	2: [  # DESERT
		{"id": "",           "weight": 70.0},
		{"id": "sandstorm",  "weight": 25.0},
		{"id": "dust_devil", "weight": 5.0},
	],
	3: [  # SCORCHED
		{"id": "",         "weight": 50.0},
		{"id": "ash_fall", "weight": 35.0},
		{"id": "volcanic", "weight": 15.0},
	],
	4: [  # MOUNTAINS
		{"id": "",         "weight": 55.0},
		{"id": "snow",     "weight": 30.0},
		{"id": "blizzard", "weight": 15.0},
	],
}

# Duration range in seconds per weather type [min, max]
const _DURATIONS: Dictionary = {
	"":           [120.0, 300.0],
	"rain":       [ 60.0, 180.0],
	"heavy_rain": [ 60.0, 180.0],
	"sandstorm":  [ 90.0, 240.0],
	"dust_devil": [ 90.0, 240.0],
	"ash_fall":   [ 80.0, 200.0],
	"volcanic":   [ 80.0, 200.0],
	"snow":       [100.0, 220.0],
	"blizzard":   [100.0, 220.0],
}

var current_weather: String = ""
var current_duration: float = 0.0

var _current_biome: int = -1
var _biome_rngs: Dictionary = {}  # biome_id (int) -> RandomNumberGenerator
var _initialized: bool = false
var _save_timer: float = 0.0
const _SAVE_INTERVAL: float = 5.0

# Called by WorldScene._ready() after save data is available.
func on_world_entered() -> void:
	var world_seed: int = SaveManager.world_seed
	for biome_id: int in _BIOME_TABLES:
		var rng := RandomNumberGenerator.new()
		rng.seed = world_seed ^ (biome_id * 0x9e3779b9)
		_biome_rngs[biome_id] = rng

	var saved: Dictionary = SaveManager.weather
	if not saved.is_empty():
		current_weather = str(saved.get("id", ""))
		current_duration = float(saved.get("duration", 0.0))
		_current_biome = int(saved.get("biome_id", -1))

	if current_duration <= 0.0:
		current_duration = 60.0

	_save_timer = 0.0
	_initialized = true

# Called by WorldScene when the player enters a new biome.
func set_biome(biome_id: int) -> void:
	if biome_id == _current_biome:
		return
	_current_biome = biome_id
	# Reset timer so new biome weather rolls immediately on next tick.
	current_duration = 0.0

func _process(delta: float) -> void:
	if not _initialized:
		return
	if SaveManager.current_map != "main":
		return

	current_duration -= delta
	if current_duration <= 0.0:
		_change_weather()

	_save_timer += delta
	if _save_timer >= _SAVE_INTERVAL:
		_save_timer = 0.0
		_sync_to_save()

func _change_weather() -> void:
	if _current_biome < 0:
		current_weather = ""
		current_duration = 120.0
		return
	current_weather = _pick_weather(_current_biome)
	var dur_range: Array = _DURATIONS.get(current_weather, [120.0, 300.0])
	var rng: RandomNumberGenerator = _biome_rngs.get(_current_biome) as RandomNumberGenerator
	if rng != null:
		current_duration = rng.randf_range(float(dur_range[0]), float(dur_range[1]))
	else:
		current_duration = float(dur_range[0])
	GameBus.weather_changed.emit(current_weather, current_duration)
	_sync_to_save()

func _pick_weather(biome_id: int) -> String:
	var table: Array = _BIOME_TABLES.get(biome_id, [])
	if table.is_empty():
		return ""
	var rng: RandomNumberGenerator = _biome_rngs.get(biome_id) as RandomNumberGenerator
	if rng == null:
		return ""
	var total: float = 0.0
	for entry: Dictionary in table:
		total += float(entry["weight"])
	var roll: float = rng.randf_range(0.0, total)
	var cumulative: float = 0.0
	for entry: Dictionary in table:
		cumulative += float(entry["weight"])
		if roll < cumulative:
			return str(entry["id"])
	return ""

func _sync_to_save() -> void:
	SaveManager.weather = {
		"id": current_weather,
		"duration": current_duration,
		"biome_id": _current_biome,
	}
	SaveManager.mark_dirty()
