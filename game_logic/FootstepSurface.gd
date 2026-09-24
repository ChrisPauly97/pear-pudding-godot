extends RefCounted

## Terrain-aware footsteps (GID-129 / TID-491).
##
## Picks the surface under the player from the tile id (IsoConst), biome,
## map and weather — IsoConst has no water or sand tile, so biome and weather
## carry that — and maps it to an SFX key. Also synthesizes the fallback
## sounds for those keys (same approach as SfxGen) so no asset is required.

const _SfxGen = preload("res://game_logic/SfxGen.gd")

const MIX_RATE: int = _SfxGen.MIX_RATE

const SURFACES: Array[String] = ["grass", "sand", "stone", "snow", "wood", "water"]
const HOOF_KEY: String = "footstep_hoof"
## Mounted on soft ground: the surface step, pitched down to read as heavier.
const MOUNTED_SOFT_PITCH: float = 0.75

## Overworld ground per biome (IsoConst biome order): [flat, hill].
const _BIOME_GROUND: Array = [
	["grass", "grass"],  # 0 Grasslands
	["grass", "grass"],  # 1 Forest
	["sand", "sand"],    # 2 Desert
	["stone", "stone"],  # 3 Scorched — charred rock
	["snow", "stone"],   # 4 Mountains — snowfields, granite slopes
]
const _WOOD_FLOOR_MAPS: Array[String] = ["player_home", "farsyth_mansion", "guildhall"]
const _STONE_FLOOR_MAPS: Array[String] = ["blancogov_temple"]
const _STONE_FLOOR_PREFIXES: Array[String] = ["dungeon_", "spire_floor_"]
const _HARD_SURFACES: Array[String] = ["stone", "wood"]

static var _cache: Dictionary = {}


## Surface under a step. `map_name` "main" is the infinite overworld;
## `weather_id` is WeatherManager's id (only meaningful on "main").
static func surface_for(tile: int, biome_id: int, map_name: String, weather_id: String) -> String:
	if map_name != "main":
		return _named_map_surface(tile, map_name)
	var paved: bool = tile == IsoConst.TILE_PATH or tile == IsoConst.TILE_WALL or tile == IsoConst.TILE_CRACKED
	var surface: String = "grass"
	if biome_id >= 0 and biome_id < _BIOME_GROUND.size():
		var row: Array = _BIOME_GROUND[biome_id]
		surface = str(row[1]) if tile == IsoConst.TILE_HILL else str(row[0])
	if paved and surface != "sand":
		surface = "stone"
	# Puddles: heavy rain soaks everything but sand; light rain only pools on paths.
	if surface != "sand" and (weather_id == "heavy_rain" or (weather_id == "rain" and paved)):
		surface = "water"
	return surface


static func _named_map_surface(tile: int, map_name: String) -> String:
	if map_name in _WOOD_FLOOR_MAPS:
		return "wood"
	if map_name in _STONE_FLOOR_MAPS:
		return "stone"
	for prefix: String in _STONE_FLOOR_PREFIXES:
		if map_name.begins_with(prefix):
			return "stone"
	if tile == IsoConst.TILE_PATH or tile == IsoConst.TILE_WALL or tile == IsoConst.TILE_CRACKED:
		return "stone"
	return "grass"


## SFX key + base pitch for one step. Mounted: hooves clop on hard ground,
## soft ground plays the surface step pitched down.
static func sfx_for(surface: String, mounted: bool) -> Dictionary:
	var key: String = "footstep_" + (surface if surface in SURFACES else "grass")
	if not mounted:
		return {"key": key, "pitch": 1.0}
	if surface in _HARD_SURFACES:
		return {"key": HOOF_KEY, "pitch": 1.0}
	return {"key": key, "pitch": MOUNTED_SOFT_PITCH}


static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for s: String in SURFACES:
		out.append("footstep_" + s)
	out.append(HOOF_KEY)
	return out


# ── Synthesized fallbacks ─────────────────────────────────────────────────

static func get_sfx(key: String) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStreamWAV = _SfxGen._to_wav(_build(key))
	_cache[key] = stream
	return stream


static func _build(key: String) -> PackedFloat32Array:
	match key:
		"footstep_sand":
			return _gen_sand()
		"footstep_stone":
			return _gen_stone()
		"footstep_snow":
			return _gen_snow()
		"footstep_wood":
			return _gen_wood()
		"footstep_water":
			return _gen_water()
		"footstep_hoof":
			return _gen_hoof()
		_:
			return _gen_grass()


## Soft brush: dull low-passed noise plus a faint swish.
static func _gen_grass() -> PackedFloat32Array:
	var body: PackedFloat32Array = _SfxGen._lowpass(_SfxGen._noise(0.09, 0.5, 2101), 0.22)
	_SfxGen._apply_env_ad(body, 0.004, 45.0)
	var swish: PackedFloat32Array = _SfxGen._highpass(_SfxGen._noise(0.07, 0.12, 2102), 0.6)
	_SfxGen._apply_env_ad(swish, 0.01, 40.0)
	return _SfxGen._mix(body, swish)


## Gritty crunch: high-passed grains over a small thump.
static func _gen_sand() -> PackedFloat32Array:
	var grit: PackedFloat32Array = _SfxGen._highpass(_SfxGen._noise(0.1, 0.4, 2201), 0.45)
	_SfxGen._apply_env_ad(grit, 0.006, 32.0)
	var thump: PackedFloat32Array = _SfxGen._lowpass(_SfxGen._noise(0.06, 0.35, 2202), 0.1)
	_SfxGen._apply_env_ad(thump, 0.002, 50.0)
	return _SfxGen._mix(grit, thump)


## Hard tap: bright click plus a short low knock.
static func _gen_stone() -> PackedFloat32Array:
	var click: PackedFloat32Array = _SfxGen._highpass(_SfxGen._noise(0.04, 0.45, 2301), 0.3)
	_SfxGen._apply_env_ad(click, 0.0005, 110.0)
	var knock: PackedFloat32Array = _SfxGen._sine(170.0, 0.06, 0.3)
	_SfxGen._apply_env_ad(knock, 0.001, 70.0)
	return _SfxGen._mix(click, knock)


## Squeaky crunch: noise gated into grains, slower decay.
static func _gen_snow() -> PackedFloat32Array:
	var s: PackedFloat32Array = _SfxGen._lowpass(_SfxGen._noise(0.14, 0.55, 2401), 0.45)
	var r: RandomNumberGenerator = _SfxGen._rng(2402)
	var grain: int = int(0.006 * MIX_RATE)
	for i in s.size():
		if (i / grain) % 3 == 0 and r.randf() < 0.9:
			s[i] *= 0.25
	_SfxGen._apply_env_ad(s, 0.015, 22.0)
	return s


## Hollow knock: two resonant partials plus a small click.
static func _gen_wood() -> PackedFloat32Array:
	var lo: PackedFloat32Array = _SfxGen._sine(140.0, 0.1, 0.3)
	var hi: PackedFloat32Array = _SfxGen._sine(290.0, 0.1, 0.16)
	var body: PackedFloat32Array = _SfxGen._mix(lo, hi)
	_SfxGen._apply_env_ad(body, 0.001, 38.0)
	var click: PackedFloat32Array = _SfxGen._noise(0.02, 0.25, 2501)
	_SfxGen._apply_env_ad(click, 0.0005, 150.0)
	return _SfxGen._mix(body, click)


## Splash: bright noise swell with a falling bubble tone.
static func _gen_water() -> PackedFloat32Array:
	var spray: PackedFloat32Array = _SfxGen._highpass(_SfxGen._noise(0.16, 0.4, 2601), 0.5)
	var n: int = spray.size()
	for i in n:
		var u: float = float(i) / float(n)
		spray[i] *= sin(PI * minf(u * 3.0, 1.0)) * exp(-5.0 * u)
	var bubble: PackedFloat32Array = _SfxGen._sine_sweep(650.0, 320.0, 0.08, 0.12)
	_SfxGen._apply_env_ad(bubble, 0.004, 30.0)
	return _SfxGen._mix(spray, bubble)


## Hoof clop: pitched-down wooden knock with a low thud.
static func _gen_hoof() -> PackedFloat32Array:
	var clop: PackedFloat32Array = _SfxGen._sine_sweep(360.0, 230.0, 0.07, 0.3)
	_SfxGen._apply_env_ad(clop, 0.0008, 55.0)
	var thud: PackedFloat32Array = _SfxGen._sine(85.0, 0.1, 0.35)
	_SfxGen._apply_env_ad(thud, 0.001, 35.0)
	var click: PackedFloat32Array = _SfxGen._noise(0.015, 0.25, 2701)
	_SfxGen._apply_env_ad(click, 0.0003, 180.0)
	return _SfxGen._mix(_SfxGen._mix(clop, thud), click)
