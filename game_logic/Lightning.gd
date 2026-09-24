extends RefCounted
## Storm lightning and ground wetness rules (GID-129 / TID-487). Pure and
## static — DayNightCycle owns the state and applies the results.
##
## Timing is local-random per client: co-op peers share the weather id (and so
## whether a storm is on), but each sees its own strikes. No RPC needed.

## Seconds between strikes at full storm strength. Weaker storms stretch the
## upper bound (see `next_interval`).
const MIN_INTERVAL: float = 8.0
const MAX_INTERVAL: float = 25.0
## Length of one flash (a bright strike plus a weaker re-strike flicker).
const FLASH_SECONDS: float = 0.5
## Light-to-sound delay range: the strike's "distance".
const MIN_THUNDER_DELAY: float = 0.5
const MAX_THUNDER_DELAY: float = 3.5
## Seconds for dry ground to soak fully, and for soaked ground to dry fully.
const WET_SECONDS: float = 20.0
const DRY_SECONDS: float = 90.0


## Seconds until the next strike for a storm of `strength` (0..1].
static func next_interval(rng: RandomNumberGenerator, strength: float) -> float:
	var s: float = clampf(strength, 0.1, 1.0)
	return rng.randf_range(MIN_INTERVAL, MIN_INTERVAL + (MAX_INTERVAL - MIN_INTERVAL) / s)


## Flash brightness (0..1) `t` seconds after a strike: a sharp main flash, a
## short dip, then a weaker re-strike that fades out by FLASH_SECONDS.
static func flash_envelope(t: float) -> float:
	if t < 0.0 or t >= FLASH_SECONDS:
		return 0.0
	if t < 0.03:
		return t / 0.03
	if t < 0.14:
		return lerpf(1.0, 0.15, (t - 0.03) / 0.11)
	if t < 0.20:
		return lerpf(0.15, 0.6, (t - 0.14) / 0.06)
	return lerpf(0.6, 0.0, (t - 0.20) / (FLASH_SECONDS - 0.20))


static func thunder_delay(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(MIN_THUNDER_DELAY, MAX_THUNDER_DELAY)


## Playback pitch for thunder heard `delay` seconds after its flash: distant
## thunder is lower and duller than a close crack.
static func thunder_pitch(delay: float) -> float:
	var d: float = inverse_lerp(MIN_THUNDER_DELAY, MAX_THUNDER_DELAY, clampf(
		delay, MIN_THUNDER_DELAY, MAX_THUNDER_DELAY))
	return lerpf(1.05, 0.75, d)


## Moves ground wetness toward `target` over `delta` seconds: soaks in
## WET_SECONDS, dries over DRY_SECONDS, so puddles outlast the rain.
static func step_wetness(current: float, target: float, delta: float) -> float:
	if current < target:
		return minf(target, current + delta / WET_SECONDS)
	return maxf(target, current - delta / DRY_SECONDS)
