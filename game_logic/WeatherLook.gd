extends RefCounted
## Per-weather atmosphere look (GID-129 / TID-486): how each weather id
## reshapes fog, sky, sun, shadows, ambient tint and grass wind.
##
## `CLEAR` holds every key at its neutral value; `OVERRIDES` lists only what a
## weather changes. `look_for(id)` merges the two, so extending the look (e.g.
## TID-487's rain wetness or lightning) is one `CLEAR` default plus per-weather
## overrides — callers read keys with `look.get(key)` and never change.
##
## `DayNightCycle` blends between looks (`blend`) and applies them; WorldScene
## only forwards the weather id. Every key is a plain Environment/light/global
## shader value, so the look works on every renderer and quality tier.

## Storms may thicken fog, but never past this multiple of the base density —
## the player must stay readable at the centre of the iso view.
const MAX_FOG_DENSITY_MULT: float = 3.0

const CLEAR: Dictionary = {
	# Ambient light multiplier (the old WeatherParticles screen tint).
	"tint": Color(1.0, 1.0, 1.0),
	# Multiplier on the environment's base depth-fog density.
	"fog_density_mult": 1.0,
	# Fog colour the weather pulls toward; weight 0 keeps the sky-derived colour.
	"fog_color": Color(0.80, 0.82, 0.85),
	"fog_color_weight": 0.0,
	# 0..1: how far the sky colours grey toward `fog_color` (overcast).
	"sky_overcast": 0.0,
	# Multiplier on sun and moon energy (cloud cover).
	"sun_energy_mult": 1.0,
	# Multiplier on the sun's base shadow opacity (diffuse light, soft shadows).
	"shadow_opacity_mult": 1.0,
	# Grass wind: direction (XZ), `wind_strength` multiplier, steady downwind bend.
	# Clear keeps the grass shaders' default breeze — a zero direction would
	# normalize to NaN in the shader.
	"wind_direction": Vector2(0.94385835, 0.33035042),
	"wind_scale": 1.0,
	"wind_lean": 0.0,
	# TID-487: ground wetness target (0 dry .. 1 soaked). DayNightCycle eases the
	# terrain toward it on its own clock — quick to wet, slow to dry.
	"wetness": 0.0,
	# TID-487: storm strength (0 = no lightning). Scales strike frequency.
	"lightning": 0.0,
	# Colour the flash pulls ambient light and sky toward.
	"lightning_color": Color(0.80, 0.86, 1.00),
	# TID-488: multiplier on dawn/dusk sun-ray strength. Cloud and dust cover
	# dampens shafts; storms and whiteouts kill them.
	"sun_rays": 1.0,
	# GID-130 / TID-494: multiplier on the valley height-fog density. Rain and
	# snow thicken low mist; wind (sand, dust) scours it away.
	"height_fog": 1.0,
}

const OVERRIDES: Dictionary = {
	"rain": {
		"tint": Color(0.85, 0.85, 0.95),
		"fog_density_mult": 1.6, "fog_color": Color(0.55, 0.58, 0.66), "fog_color_weight": 0.55,
		"sky_overcast": 0.5, "sun_energy_mult": 0.6, "shadow_opacity_mult": 0.5,
		"wind_direction": Vector2(0.37139068, 0.92847669), "wind_scale": 1.6, "wind_lean": 0.04,
		"wetness": 0.6,
		"sun_rays": 0.4,
		"height_fog": 1.6,
	},
	"heavy_rain": {
		"tint": Color(0.70, 0.70, 0.85),
		"fog_density_mult": 2.2, "fog_color": Color(0.42, 0.45, 0.53), "fog_color_weight": 0.8,
		"sky_overcast": 0.8, "sun_energy_mult": 0.35, "shadow_opacity_mult": 0.2,
		"wind_direction": Vector2(0.49613894, 0.86824314), "wind_scale": 2.6, "wind_lean": 0.10,
		"wetness": 1.0, "lightning": 1.0,
		"sun_rays": 0.0,
		"height_fog": 2.0,
	},
	"sandstorm": {
		"tint": Color(0.95, 0.85, 0.70),
		"fog_density_mult": 3.0, "fog_color": Color(0.78, 0.62, 0.40), "fog_color_weight": 0.9,
		"sky_overcast": 0.7, "sun_energy_mult": 0.55, "shadow_opacity_mult": 0.35,
		"wind_direction": Vector2(0.98058068, 0.19611614), "wind_scale": 3.0, "wind_lean": 0.14,
		"sun_rays": 0.2,
		"height_fog": 0.3,
	},
	"dust_devil": {
		"tint": Color(0.92, 0.84, 0.68),
		"fog_density_mult": 1.8, "fog_color": Color(0.75, 0.63, 0.45), "fog_color_weight": 0.6,
		"sky_overcast": 0.4, "sun_energy_mult": 0.8, "shadow_opacity_mult": 0.7,
		"wind_direction": Vector2(0.70710678, 0.70710678), "wind_scale": 2.2, "wind_lean": 0.06,
		"sun_rays": 0.7,
		"height_fog": 0.5,
	},
	"ash_fall": {
		"tint": Color(0.70, 0.65, 0.65),
		"fog_density_mult": 2.2, "fog_color": Color(0.45, 0.40, 0.38), "fog_color_weight": 0.7,
		"sky_overcast": 0.7, "sun_energy_mult": 0.5, "shadow_opacity_mult": 0.4,
		"wind_direction": Vector2(0.31622777, 0.94868330), "wind_scale": 0.8, "wind_lean": 0.0,
		"sun_rays": 0.35,
		"height_fog": 1.3,
	},
	"volcanic": {
		"tint": Color(0.60, 0.55, 0.55),
		"fog_density_mult": 2.4, "fog_color": Color(0.50, 0.30, 0.22), "fog_color_weight": 0.75,
		"sky_overcast": 0.75, "sun_energy_mult": 0.45, "shadow_opacity_mult": 0.35,
		"wind_direction": Vector2(0.39391929, 0.91914503), "wind_scale": 1.2, "wind_lean": 0.02,
		# Dry lightning in the ash cloud, red-tinted by the lava glow.
		"lightning": 0.7, "lightning_color": Color(1.00, 0.55, 0.35),
		"sun_rays": 0.1,
		"height_fog": 1.5,
	},
	"snow": {
		"tint": Color(0.95, 0.95, 1.00),
		"fog_density_mult": 1.5, "fog_color": Color(0.85, 0.88, 0.95), "fog_color_weight": 0.6,
		"sky_overcast": 0.5, "sun_energy_mult": 0.7, "shadow_opacity_mult": 0.6,
		"wind_direction": Vector2(0.37139068, 0.92847669), "wind_scale": 0.7, "wind_lean": 0.0,
		"sun_rays": 0.5,
		"height_fog": 1.4,
	},
	"blizzard": {
		"tint": Color(0.80, 0.80, 0.95),
		"fog_density_mult": 3.0, "fog_color": Color(0.82, 0.85, 0.92), "fog_color_weight": 0.9,
		"sky_overcast": 0.85, "sun_energy_mult": 0.35, "shadow_opacity_mult": 0.2,
		"wind_direction": Vector2(0.91914503, 0.39391929), "wind_scale": 2.8, "wind_lean": 0.12,
		"sun_rays": 0.0,
		"height_fog": 1.2,
	},
}


## The full look for `weather_id` (a fresh copy). Unknown or empty ids are clear.
static func look_for(weather_id: String) -> Dictionary:
	var look: Dictionary = CLEAR.duplicate()
	var over: Dictionary = OVERRIDES.get(weather_id, {})
	look.merge(over, true)
	return look


## Lerps every key of `a` toward `b` by `t` (0..1). Floats, Colors and Vector2s
## interpolate; any other value snaps to `b` from t = 0.5.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var k: float = clampf(t, 0.0, 1.0)
	var out: Dictionary = {}
	for key: Variant in CLEAR:
		var va: Variant = a.get(key, CLEAR[key])
		var vb: Variant = b.get(key, CLEAR[key])
		if va is float and vb is float:
			out[key] = lerpf(float(va), float(vb), k)
		elif va is Color and vb is Color:
			var ca: Color = va
			out[key] = ca.lerp(vb as Color, k)
		elif va is Vector2 and vb is Vector2:
			var v2a: Vector2 = va
			out[key] = v2a.lerp(vb as Vector2, k)
		else:
			out[key] = vb if k >= 0.5 else va
	return out


static func screen_tint(weather_id: String) -> Color:
	return look_for(weather_id)["tint"] as Color


static func wind_direction(weather_id: String) -> Vector2:
	return look_for(weather_id)["wind_direction"] as Vector2
