extends RefCounted

## Pure selection rules for AudioManager's layered ambience (GID-129 / TID-490).
##
## Three loops play at once: the biome bed (AudioManager.AMBIENCE_PATHS), a
## weather layer and a time-of-day layer. Everything here is a pure function
## of its arguments so the choices are unit-testable without audio playback.

## Layer key → optional real asset. A missing file falls back to
## AmbienceGen.get_layer(key) (procedural loop), so none of these are required.
const LAYER_PATHS: Dictionary = {
	"rain": "res://assets/audio/ambience/rain.ogg",
	"heavy_rain": "res://assets/audio/ambience/heavy_rain.ogg",
	"wind": "res://assets/audio/ambience/wind.ogg",
	"sandstorm": "res://assets/audio/ambience/sandstorm.ogg",
	"crackle": "res://assets/audio/ambience/crackle.ogg",
	"birds": "res://assets/audio/ambience/birds.ogg",
	"crickets": "res://assets/audio/ambience/crickets.ogg",
	"owls": "res://assets/audio/ambience/owls.ogg",
}

## WeatherManager weather id → [layer key, gain 0..1]. Unknown ids are silent.
const _WEATHER_LAYERS: Dictionary = {
	"rain": ["rain", 0.8],
	"heavy_rain": ["heavy_rain", 1.0],
	"sandstorm": ["sandstorm", 1.0],
	"dust_devil": ["wind", 0.7],
	"ash_fall": ["crackle", 0.6],
	"volcanic": ["crackle", 1.0],
	"snow": ["wind", 0.45],
	"blizzard": ["wind", 1.0],
}

## Biome id (IsoConst order) → [day key, night key]. "" = no layer.
## Scorched has no wildlife; the desert is silent by day, crickets at night.
const _TIME_LAYERS: Array = [
	["birds", "crickets"],  # 0 Grasslands
	["birds", "owls"],      # 1 Forest
	["", "crickets"],       # 2 Desert
	["", ""],               # 3 Scorched
	["birds", "owls"],      # 4 Mountains
]

## Named-map ambience when the map is outdoors (towns): grassland day/night.
const NAMED_MAP_TIME_BIOME: int = 0

## Sun-height band for the day/night switch. sin((t - 0.25) * TAU) is the same
## sun height DayNightCycle uses; the gap between the two thresholds keeps the
## layer from flapping around dusk and dawn.
const DAY_ON_SUN_HEIGHT: float = 0.08
const NIGHT_ON_SUN_HEIGHT: float = -0.08

## Music ducking: multiplier on the music volume while dialogue / narration is up.
const DUCK_DIALOGUE: float = 0.35
const DUCK_NARRATION: float = 0.4

## Named maps that are indoors or underground: no weather, no wildlife.
const _INDOOR_MAPS: Array[String] = [
	"blancogov_temple", "farsyth_mansion", "guildhall", "player_home",
]
const _INDOOR_PREFIXES: Array[String] = ["dungeon_", "spire_floor_"]


static func weather_layer(weather_id: String) -> String:
	var row: Array = _WEATHER_LAYERS.get(weather_id, [])
	return "" if row.is_empty() else str(row[0])


static func weather_gain(weather_id: String) -> float:
	var row: Array = _WEATHER_LAYERS.get(weather_id, [])
	return 0.0 if row.is_empty() else float(row[1])


## Day/night decision with hysteresis: only flips once the sun has cleared
## the band on the far side of the horizon.
static func next_is_day(time_of_day: float, was_day: bool) -> bool:
	var sun_h: float = sin((time_of_day - 0.25) * TAU)
	if was_day:
		return sun_h > NIGHT_ON_SUN_HEIGHT
	return sun_h >= DAY_ON_SUN_HEIGHT


## Wildlife loop for a biome. Birds go quiet while any weather layer plays;
## night creatures keep going (crickets under light rain read as cosy).
static func time_layer(biome_id: int, is_day: bool, weather_key: String) -> String:
	if biome_id < 0 or biome_id >= _TIME_LAYERS.size():
		return ""
	var row: Array = _TIME_LAYERS[biome_id]
	if is_day:
		return str(row[0]) if weather_key.is_empty() else ""
	return str(row[1])


static func named_map_is_outdoors(map_name: String) -> bool:
	if map_name in _INDOOR_MAPS:
		return false
	for prefix: String in _INDOOR_PREFIXES:
		if map_name.begins_with(prefix):
			return false
	return true


## Music volume multiplier: dialogue wins over narration, 1.0 = not ducked.
static func music_duck(dialogue_active: bool, narration_playing: bool) -> float:
	if dialogue_active:
		return DUCK_DIALOGUE
	if narration_playing:
		return DUCK_NARRATION
	return 1.0


static func all_layer_keys() -> Array[String]:
	var out: Array[String] = []
	for k: String in LAYER_PATHS:
		out.append(k)
	return out
