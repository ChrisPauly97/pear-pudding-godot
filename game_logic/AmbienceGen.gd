extends RefCounted

## Procedural fallbacks for the weather and time-of-day ambience layers
## (GID-129 / TID-490). Same approach as SfxGen.get_ambience(): a few seconds
## of shaped noise and tones baked into a looping AudioStreamWAV, built once on
## first use and cached. A real file at AmbienceLayers.LAYER_PATHS[key] wins.

const _SfxGen = preload("res://game_logic/SfxGen.gd")

const MIX_RATE: int = _SfxGen.MIX_RATE

static var _cache: Dictionary = {}


static func get_layer(key: String) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStreamWAV = _build(key)
	_cache[key] = stream
	return stream


static func _build(key: String) -> AudioStreamWAV:
	var s: PackedFloat32Array
	match key:
		"rain":
			s = _gen_rain(0.18, 0.1, 70, 6060)
		"heavy_rain":
			s = _gen_rain(0.3, 0.26, 160, 6161)
		"wind":
			s = _gen_wind()
		"sandstorm":
			s = _gen_sandstorm()
		"crackle":
			s = _gen_crackle()
		"birds":
			s = _gen_birds()
		"crickets":
			s = _gen_crickets()
		"owls":
			s = _gen_owls()
		_:
			s = _gen_wind()
	_SfxGen._make_seamless(s, int(0.15 * MIX_RATE))
	return _SfxGen._to_wav(s, true)


# ── Helpers ───────────────────────────────────────────────────────────────

## Adds `overlay` into `base` at `offset`, wrapping past the end so a transient
## near the loop point continues at the head (seamless without a crossfade).
## Packed arrays are passed by reference, so this mixes in place.
static func _add_into(base: PackedFloat32Array, overlay: PackedFloat32Array, offset: int) -> void:
	var n: int = base.size()
	if n == 0:
		return
	for i in overlay.size():
		var idx: int = (offset + i) % n
		base[idx] = clampf(base[idx] + overlay[i], -1.0, 1.0)


## Multiplies `s` by 1 - depth + depth * (0.5 + 0.5 * sin), with `cycles`
## whole periods across the buffer so the modulation also loops cleanly.
static func _swell(s: PackedFloat32Array, cycles: float, depth: float, phase: float = 0.0) -> void:
	var n: int = s.size()
	for i in n:
		var u: float = float(i) / float(n)
		var m: float = 0.5 + 0.5 * sin(TAU * cycles * u + phase)
		s[i] *= 1.0 - depth + depth * m


static func _scaled(s: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for i in s.size():
		s[i] *= gain
	return s


# ── Weather layers ────────────────────────────────────────────────────────

## Hiss bed + low wash + scattered drip ticks. Heavy rain is the same recipe
## with a louder wash and more drips.
static func _gen_rain(hiss: float, wash: float, drips: int, seed_val: int) -> PackedFloat32Array:
	var dur: float = 5.0
	var bed: PackedFloat32Array = _scaled(_SfxGen._highpass(_SfxGen._noise(dur, 1.0, seed_val), 0.55), hiss)
	var low: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, seed_val + 1), 0.08), wash)
	_add_into(bed, low, 0)
	var r: RandomNumberGenerator = _SfxGen._rng(seed_val + 2)
	for d in drips:
		var tick: PackedFloat32Array = _SfxGen._noise(0.012, r.randf_range(0.06, 0.2), seed_val + 10 + d)
		_SfxGen._apply_env_ad(tick, 0.0005, 260.0)
		_add_into(bed, tick, r.randi_range(0, bed.size() - 1))
	_swell(bed, 1.0, 0.15)
	return bed


static func _gen_wind() -> PackedFloat32Array:
	var dur: float = 6.0
	var bed: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 7070), 0.03), 0.9)
	var whistle: PackedFloat32Array = _SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 7071), 0.2)
	whistle = _scaled(_SfxGen._highpass(whistle, 0.9), 0.35)
	_swell(whistle, 3.0, 0.8, 1.3)
	_add_into(bed, whistle, 0)
	_swell(bed, 2.0, 0.6)
	return bed


static func _gen_sandstorm() -> PackedFloat32Array:
	var dur: float = 5.0
	var grit: PackedFloat32Array = _scaled(_SfxGen._highpass(_SfxGen._noise(dur, 1.0, 8080), 0.35), 0.3)
	var roar: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 8081), 0.04), 0.8)
	_add_into(grit, roar, 0)
	_swell(grit, 3.0, 0.5)
	return grit


## Low ember rumble with sharp pops (ash fall, volcanic).
static func _gen_crackle() -> PackedFloat32Array:
	var dur: float = 5.0
	var bed: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 9090), 0.012), 0.7)
	var r: RandomNumberGenerator = _SfxGen._rng(9091)
	for c in 55:
		var pop: PackedFloat32Array = _SfxGen._noise(r.randf_range(0.006, 0.025), r.randf_range(0.1, 0.35), 9100 + c)
		_SfxGen._apply_env_ad(pop, 0.0005, 160.0)
		_add_into(bed, pop, r.randi_range(0, bed.size() - 1))
	return bed


# ── Time-of-day layers ────────────────────────────────────────────────────

## Sparse chirp phrases (2–4 quick sweeps) over near-silence.
static func _gen_birds() -> PackedFloat32Array:
	var dur: float = 7.0
	var bed: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 1111), 0.02), 0.08)
	var r: RandomNumberGenerator = _SfxGen._rng(1112)
	var phrase_starts: Array[float] = [0.4, 1.9, 3.1, 4.8, 6.1]
	for start: float in phrase_starts:
		var notes: int = r.randi_range(2, 4)
		var base_f: float = r.randf_range(2300.0, 3400.0)
		var t: float = start
		for _n in notes:
			var up: bool = r.randf() < 0.5
			var f_a: float = base_f * (0.85 if up else 1.15)
			var chirp: PackedFloat32Array = _SfxGen._sine_sweep(f_a, base_f, r.randf_range(0.05, 0.09), 0.12)
			_SfxGen._apply_env_ad(chirp, 0.008, 28.0)
			_add_into(bed, chirp, int(t * MIX_RATE))
			t += r.randf_range(0.09, 0.16)
	return bed


## Two crickets: a pulsed high tone gated into short trills.
static func _gen_crickets() -> PackedFloat32Array:
	var dur: float = 4.0
	var n: int = int(dur * MIX_RATE)
	var out: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 1212), 0.02), 0.06)
	var voices: Array[Vector3] = [Vector3(4200.0, 0.5, 0.0), Vector3(4700.0, 0.8, 0.27)]
	for v: Vector3 in voices:
		var period: float = v.y  # seconds between trills
		for i in n:
			var t: float = float(i) / float(MIX_RATE)
			var local: float = fmod(t + v.z, period)
			if local > 0.22:
				continue
			var pulse: float = 0.5 + 0.5 * sin(TAU * 32.0 * t)
			var env: float = sin(PI * local / 0.22)
			out[i] = clampf(out[i] + sin(TAU * v.x * t) * 0.07 * pulse * env, -1.0, 1.0)
	return out


## Soft night air with a distant "hoo-hoo" twice per loop.
static func _gen_owls() -> PackedFloat32Array:
	var dur: float = 8.0
	var bed: PackedFloat32Array = _scaled(_SfxGen._lowpass(_SfxGen._noise(dur, 1.0, 1313), 0.015), 0.1)
	var hoot_times: Array[float] = [1.2, 1.65, 5.0, 5.4, 5.85]
	for idx in hoot_times.size():
		var f: float = 390.0 if idx % 2 == 0 else 350.0
		var hoot: PackedFloat32Array = _SfxGen._sine_sweep(f, f * 0.9, 0.32, 0.16)
		var m: int = hoot.size()
		for i in m:
			hoot[i] *= sin(PI * float(i) / float(m))
		_add_into(bed, hoot, int(hoot_times[idx] * MIX_RATE))
	return bed
