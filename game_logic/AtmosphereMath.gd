extends RefCounted
## Fake-volumetric atmosphere rules (GID-130) — pure, static, no scene access.
##
## The Mobile renderer has no volumetric fog, so GID-130 builds stand-ins that
## work on every renderer. Their time-of-day and weather curves live here so
## tests can pin them without a scene.

## Height fog (TID-494): world Y the valley mist tops out at. Flat ground sits
## at y≈0 and hills peak around IsoConst.HILL_PEAK_H (1.5), so hilltops poke
## out of the mist while valleys and flat plains sit in it.
const HEIGHT_FOG_TOP: float = 0.8
## `Environment.fog_height_density` per time of day. Godot's height fog is
## `1 - exp(-depth_below_top * density)`, so at ground level the night value
## covers ~20 %, the midday value ~5 %.
const HEIGHT_FOG_NIGHT: float = 0.28
const HEIGHT_FOG_MIDDAY: float = 0.06
## Extra density around sunrise/sunset: mist is thickest at dawn.
const HEIGHT_FOG_DAWN_BONUS: float = 0.18
## Sun height half-width of the dawn bump.
const HEIGHT_FOG_DAWN_WIDTH: float = 0.22
## Never so thick the player's feet disappear.
const HEIGHT_FOG_MAX: float = 0.7


## Height-fog density for a sun height `sun_h` (sin of the arc angle) and the
## WeatherLook `height_fog` multiplier.
static func height_fog_density(sun_h: float, weather_mult: float) -> float:
	var base: float = lerpf(HEIGHT_FOG_NIGHT, HEIGHT_FOG_MIDDAY, smoothstep(0.05, 0.5, sun_h))
	var dawn: float = HEIGHT_FOG_DAWN_BONUS * (1.0 - smoothstep(0.0, HEIGHT_FOG_DAWN_WIDTH, absf(sun_h - 0.02)))
	return clampf((base + dawn) * maxf(weather_mult, 0.0), 0.0, HEIGHT_FOG_MAX)
