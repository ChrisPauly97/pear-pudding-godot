## Night light rules (GID-129 / TID-489) — pure and static so tests can pin them.
##
## scenes/world/modules/NightLights.gd reads these: which sources glow, how
## strongly for a sun height, how each style flickers, and which ones get a rig.
extends RefCounted

## One entry per light style. `radius` is the pool's ground reach in world
## units, `energy` its additive strength at the centre, `flicker` how far the
## energy dips (0 = steady) and `speed` how fast it wavers.
const STYLES: Dictionary = {
	"lantern": {"color": Color(1.0, 0.72, 0.38), "radius": 4.5, "energy": 0.55,
		"flicker": 0.14, "speed": 1.0, "height": 1.7},
	"campfire": {"color": Color(1.0, 0.52, 0.18), "radius": 6.0, "energy": 0.8,
		"flicker": 0.32, "speed": 1.6, "height": 0.4},
	"waystone": {"color": Color(0.45, 0.85, 1.0), "radius": 4.0, "energy": 0.45,
		"flicker": 0.06, "speed": 0.3, "height": 1.2},
	"mana_well": {"color": Color(0.5, 0.62, 1.0), "radius": 4.0, "energy": 0.45,
		"flicker": 0.1, "speed": 0.4, "height": 0.8},
}

## Sun heights (sin of the arc angle) between which lights fade in: they start
## warming while the sun is still just above the horizon and are full once it
## has set, so towns light up at dusk rather than snapping on at nightfall.
const FADE_TOP: float = 0.15
const FADE_BOTTOM: float = -0.05


## 0 in daylight, 1 at night, smooth across dusk and dawn.
static func night_factor(sun_h: float) -> float:
	return 1.0 - smoothstep(FADE_BOTTOM, FADE_TOP, sun_h)


## Brightness multiplier in [1 - amount, 1]. Three incommensurate sines are
## cheap and never visibly repeat; `phase` keeps neighbouring lights apart.
static func flicker(t: float, phase: float, amount: float, speed: float) -> float:
	var s: float = t * speed
	var n: float = (sin(s * 7.1 + phase) * 0.5 + sin(s * 12.9 + phase * 2.3) * 0.3
			+ sin(s * 23.7 + phase * 0.7) * 0.2)
	return 1.0 - amount * (0.5 + 0.5 * n)


## A stable per-position phase, so a light keeps its rhythm when it moves rig.
static func phase_for(pos: Vector3) -> float:
	return fposmod(pos.x * 1.37 + pos.z * 2.11, TAU)


## The `count` sources (`{"pos": Vector3, ...}`) nearest `origin` on the ground
## plane within `max_dist`, nearest first.
static func nearest(sources: Array[Dictionary], origin: Vector3, count: int,
		max_dist: float) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for src: Dictionary in sources:
		var p: Vector3 = src.get("pos", Vector3.ZERO)
		var d2: float = Vector2(p.x - origin.x, p.z - origin.z).length_squared()
		if d2 <= max_dist * max_dist:
			var entry: Dictionary = src.duplicate()
			entry["d2"] = d2
			scored.append(entry)
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d2"]) < float(b["d2"]))
	if scored.size() > count:
		scored.resize(maxi(count, 0))
	return scored
