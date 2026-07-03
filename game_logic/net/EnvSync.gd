## Pure helpers for co-op environmental state sync — day/night clock + weather
## (GID-103 / TID-382).
##
## The authority (host) is the single source of truth for time_of_day/days_elapsed/
## weather_id; peers apply the decoded broadcast read-only to their local
## DayNightCycle + weather visuals. No scene dependencies — fully unit-testable.
##
## Callers: preload("res://game_logic/net/EnvSync.gd")
extends RefCounted

## Payload layout: [time_of_day: float, days_elapsed: int, weather_id: String]
static func encode(time_of_day: float, days_elapsed: int, weather_id: String) -> Array:
	return [time_of_day, days_elapsed, weather_id]


## Unpack a received payload. Tolerant of a short/garbage array — missing fields
## fall back to safe defaults so a corrupt packet can never crash a receiver.
static func decode(payload: Array) -> Dictionary:
	var time_of_day: float = float(payload[0]) if payload.size() > 0 else 0.4
	var days_elapsed: int = int(payload[1]) if payload.size() > 1 else 0
	var weather_id: String = str(payload[2]) if payload.size() > 2 else ""
	return {"time_of_day": time_of_day, "days_elapsed": days_elapsed, "weather_id": weather_id}


# ---------------------------------------------------------------------------
# Co-op weather roll (host-only) — a small independent table for the co-op
# landing map (madrian — grasslands), mirroring WeatherManager's biome-0 table.
# Kept as its own copy rather than importing WeatherManager (an autoload
# hard-gated to the "main" infinite-world map, GID-042) so the co-op roll stays
# independent, pure, and testable without a live scene tree.
# ---------------------------------------------------------------------------

const _WEATHER_TABLE: Array = [
	{"id": "",           "weight": 60.0},
	{"id": "rain",       "weight": 30.0},
	{"id": "heavy_rain", "weight": 10.0},
]

const _DURATIONS: Dictionary = {
	"":           [120.0, 300.0],
	"rain":       [ 60.0, 180.0],
	"heavy_rain": [ 60.0, 180.0],
}


## Weighted-random weather pick using the caller-owned RNG.
static func roll_weather(rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for entry: Dictionary in _WEATHER_TABLE:
		total += float(entry["weight"])
	var roll: float = rng.randf_range(0.0, total)
	var cumulative: float = 0.0
	for entry: Dictionary in _WEATHER_TABLE:
		cumulative += float(entry["weight"])
		if roll < cumulative:
			return str(entry["id"])
	return ""


## Seconds until the next reroll for the given weather id.
static func roll_duration(rng: RandomNumberGenerator, weather_id: String) -> float:
	var range_arr: Array = _DURATIONS.get(weather_id, [120.0, 300.0])
	return rng.randf_range(float(range_arr[0]), float(range_arr[1]))
