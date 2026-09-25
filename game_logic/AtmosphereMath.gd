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


## Fake light shafts (TID-495): world-anchored grid cells around the player;
## a cell holds a shaft when its hash falls under SHAFT_CELL_CHANCE. Anchoring
## to world cells (not the player) keeps shafts still while the player walks.
const SHAFT_CELL: float = 7.0
const SHAFT_CELL_CHANCE: float = 0.45
const SHAFT_RANGE_CELLS: int = 3
## A low sun would lay the beams flat across the screen; keep them steep.
const SHAFT_MIN_AXIS_Y: float = 0.5


## Depth-fog pass (TID-498): peak alpha, reached where the height-fog curve
## peaks (dawn in rain). Same time/weather curve as the height fog.
const DEPTH_FOG_MAX_ALPHA: float = 0.55
## Fog layer: surfaces below `DEPTH_FOG_TOP` fog in over `DEPTH_FOG_DEPTH`.
const DEPTH_FOG_TOP: float = 1.2
const DEPTH_FOG_DEPTH: float = 1.6


## Height-fog density for a sun height `sun_h` (sin of the arc angle) and the
## WeatherLook `height_fog` multiplier.
static func height_fog_density(sun_h: float, weather_mult: float) -> float:
	var base: float = lerpf(HEIGHT_FOG_NIGHT, HEIGHT_FOG_MIDDAY, smoothstep(0.05, 0.5, sun_h))
	var dawn: float = HEIGHT_FOG_DAWN_BONUS * (1.0 - smoothstep(0.0, HEIGHT_FOG_DAWN_WIDTH, absf(sun_h - 0.02)))
	return clampf((base + dawn) * maxf(weather_mult, 0.0), 0.0, HEIGHT_FOG_MAX)

static func _cell_hash(cx: int, cz: int, salt: int) -> float:
	var h: int = (cx * 73856093) ^ (cz * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## Up to `count` shaft ground points (x, z) nearest to `center`, deterministic
## per world cell. Each entry is Vector3(x, z, seed 0..1).
static func shaft_anchors(center: Vector2, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var ccx: int = floori(center.x / SHAFT_CELL)
	var ccz: int = floori(center.y / SHAFT_CELL)
	for dz: int in range(-SHAFT_RANGE_CELLS, SHAFT_RANGE_CELLS + 1):
		for dx: int in range(-SHAFT_RANGE_CELLS, SHAFT_RANGE_CELLS + 1):
			var cx: int = ccx + dx
			var cz: int = ccz + dz
			if _cell_hash(cx, cz, 1) > SHAFT_CELL_CHANCE:
				continue
			var x: float = (float(cx) + 0.15 + 0.7 * _cell_hash(cx, cz, 2)) * SHAFT_CELL
			var z: float = (float(cz) + 0.15 + 0.7 * _cell_hash(cx, cz, 3)) * SHAFT_CELL
			out.append(Vector3(x, z, _cell_hash(cx, cz, 4)))
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.y).distance_squared_to(center) < Vector2(b.x, b.y).distance_squared_to(center))
	if out.size() > count:
		out.resize(count)
	return out


## Beam axis (unit, pointing up toward the light) for a light direction.
static func shaft_axis(toward_light: Vector3) -> Vector3:
	var d: Vector3 = toward_light.normalized()
	var flat := Vector2(d.x, d.z)
	var y: float = maxf(d.y, SHAFT_MIN_AXIS_Y)
	var h: float = sqrt(maxf(0.0, 1.0 - y * y))
	if flat.length_squared() < 0.000001:
		return Vector3.UP
	flat = flat.normalized() * h
	return Vector3(flat.x, y, flat.y)


## Depth-fog pass alpha 0..DEPTH_FOG_MAX_ALPHA for a sun height and the
## WeatherLook `height_fog` multiplier (the same curve as the height fog).
static func depth_fog_density(sun_h: float, weather_mult: float) -> float:
	return height_fog_density(sun_h, weather_mult) / HEIGHT_FOG_MAX * DEPTH_FOG_MAX_ALPHA
