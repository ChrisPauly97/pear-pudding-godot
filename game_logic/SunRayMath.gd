extends RefCounted
## Sun-ray rules (GID-129 / TID-488) — pure, static, no scene access.
##
## Rays belong to a low sun: they fade in as the sun clears the horizon, peak
## through the golden hour and are gone well before midday (so the midday
## screen never hazes, see the glow notes in `WorldScene._setup_environment`).
## Weather scales them through the WeatherLook `sun_rays` multiplier.
##
## The iso camera is orthographic, so the sun itself is never on screen: a
## point "far along the sun direction" projects arbitrarily far off-screen.
## Instead the sun direction is projected onto the camera plane and the shafts
## radiate from a virtual source just past that screen edge — dawn (NE sun)
## streams in from screen-right, dusk (SW sun) from screen-left, a higher sun
## from the top.

## Sun height (sin of the arc angle) at which rays are fully faded in / start
## fading out / are gone.
const RISE_H: float = 0.06
const FADE_START_H: float = 0.2
const FADE_END_H: float = 0.6
## The virtual source sits this far along its ray from the screen centre,
## relative to where that ray leaves the screen (1.0 = on the edge).
const SOURCE_MARGIN: float = 1.2
## Below this camera-plane length the sun lies along the view axis and has no
## screen direction to stream from.
const MIN_PLANE_LEN: float = 0.1
const FULL_PLANE_LEN: float = 0.3
## Volumetric fog (High / Forward+): density at full ray strength. Scaled by
## strength so the fog is gone (and switched off) at midday.
const VOLUMETRIC_MAX_DENSITY: float = 0.018
## Below this strength the effect is switched off entirely (no GPU cost).
const MIN_STRENGTH: float = 0.01


## Ray strength 0..1 for a sun height `sun_h` and the weather's `sun_rays` multiplier.
static func strength(sun_h: float, weather_mult: float) -> float:
	var rise: float = smoothstep(0.0, RISE_H, sun_h)
	var fade: float = 1.0 - smoothstep(FADE_START_H, FADE_END_H, sun_h)
	return clampf(rise * fade * weather_mult, 0.0, 1.0)


## Screen-space direction (x right, y down) of the sun from the screen centre,
## and how strongly it lies across the screen (0 = along the view axis).
## Returns Vector3(dir.x, dir.y, plane_fade).
static func screen_direction(sun_dir: Vector3, cam_basis: Basis) -> Vector3:
	var sx: float = sun_dir.dot(cam_basis.x.normalized())
	var sy: float = sun_dir.dot(cam_basis.y.normalized())
	var plane := Vector2(sx, -sy)
	var plane_len: float = plane.length()
	if plane_len < 0.0001:
		return Vector3.ZERO
	var d: Vector2 = plane / plane_len
	return Vector3(d.x, d.y, smoothstep(MIN_PLANE_LEN, FULL_PLANE_LEN, plane_len))


## Virtual source position in SCREEN_UV space for a screen direction `dir`
## (unit, y down) on a viewport of width/height `aspect`: just past the edge
## where that direction leaves the screen, whichever edge that is.
static func source_uv(dir: Vector2, aspect: float) -> Vector2:
	var v := Vector2(dir.x / maxf(aspect, 0.1), dir.y)
	var reach: float = maxf(absf(v.x), absf(v.y))
	if reach < 0.0001:
		return Vector2(0.5, 0.5)
	return Vector2(0.5, 0.5) + v * (0.5 / reach) * SOURCE_MARGIN


## Volumetric-fog density for a ray strength (0 when the rays are off).
static func volumetric_density(ray_strength: float) -> float:
	if ray_strength < MIN_STRENGTH:
		return 0.0
	return VOLUMETRIC_MAX_DENSITY * ray_strength
