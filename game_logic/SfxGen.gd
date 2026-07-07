class_name SfxGen

# Procedurally synthesizes short chiptune-style SFX and looping biome ambience
# beds into AudioStreamWAV objects at call time (cached forever). Mirrors the
# runtime-texture-generation pattern used by TextureGen.gd, so no external
# audio assets are ever required (no .uid sidecar problem, no APK bloat).

const MIX_RATE: int = 22050
const _TAU: float = PI * 2.0

const _KEYS: Array[String] = [
	"card_draw", "card_play", "spell_resolve", "attack", "battle_win", "battle_lose",
	"enemy_engage", "enemy_alert", "chest_open", "scroll_pickup", "door_enter",
	"footstep", "nightfall_ambient", "ui_click", "land", "dig_success", "waystone_travel",
]

static var _cache: Dictionary = {}

static func all_keys() -> Array[String]:
	var out: Array[String] = []
	out.assign(_KEYS)
	return out

static func get_sfx(key: String) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStreamWAV = _build(key)
	_cache[key] = stream
	return stream

## biome_id matches IsoConst biome indices (0=Grasslands .. 4=Mountains).
static func get_ambience(biome_id: int) -> AudioStreamWAV:
	var key: String = "__ambience_%d" % biome_id
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStreamWAV = _build_ambience(biome_id)
	_cache[key] = stream
	return stream

# ── Dispatch ──────────────────────────────────────────────────────────────

static func _build(key: String) -> AudioStreamWAV:
	match key:
		"card_draw":
			return _gen_card_draw()
		"card_play":
			return _gen_card_play()
		"spell_resolve":
			return _gen_spell_resolve()
		"attack":
			return _gen_attack()
		"battle_win":
			return _gen_battle_win()
		"battle_lose":
			return _gen_battle_lose()
		"enemy_engage", "enemy_alert":
			return _gen_alarm()
		"chest_open":
			return _gen_chest_open()
		"scroll_pickup":
			return _gen_scroll_pickup()
		"door_enter":
			return _gen_door_enter()
		"footstep":
			return _gen_footstep()
		"nightfall_ambient":
			return _gen_nightfall_ambient()
		"ui_click":
			return _gen_ui_click()
		"land":
			return _gen_land()
		"dig_success":
			return _gen_dig_success()
		"waystone_travel":
			return _gen_waystone_travel()
		_:
			return _gen_ui_click()

static func _build_ambience(biome_id: int) -> AudioStreamWAV:
	match biome_id:
		0:
			return _gen_ambience_grasslands()
		1:
			return _gen_ambience_forest()
		2:
			return _gen_ambience_desert()
		3:
			return _gen_ambience_scorched()
		4:
			return _gen_ambience_mountains()
		_:
			return _gen_ambience_grasslands()

# ── Sample-level primitives ───────────────────────────────────────────────

static func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

static func _sine(freq: float, dur: float, amp: float = 0.5) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		out[i] = sin(_TAU * freq * t) * amp
	return out

static func _sine_sweep(freq_a: float, freq_b: float, dur: float, amp: float = 0.5) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var f: float = lerpf(freq_a, freq_b, t / dur)
		phase += _TAU * f / float(MIX_RATE)
		out[i] = sin(phase) * amp
	return out

static func _saw(freq: float, dur: float, amp: float = 0.3) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var phase: float = fmod(t * freq, 1.0)
		out[i] = (phase * 2.0 - 1.0) * amp
	return out

static func _saw_sweep(freq_a: float, freq_b: float, dur: float, amp: float = 0.3) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var f: float = lerpf(freq_a, freq_b, t / dur)
		phase = fmod(phase + f / float(MIX_RATE), 1.0)
		out[i] = (phase * 2.0 - 1.0) * amp
	return out

static func _square(freq: float, dur: float, amp: float = 0.3) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var phase: float = fmod(t * freq, 1.0)
		out[i] = (amp if phase < 0.5 else -amp)
	return out

static func _noise(dur: float, amp: float, seed_val: int) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var r: RandomNumberGenerator = _rng(seed_val)
	for i in n:
		out[i] = r.randf_range(-amp, amp)
	return out

static func _silence(dur: float) -> PackedFloat32Array:
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	return out

## One-pole low-pass — softens noise into a dull rumble/breeze.
static func _lowpass(samples: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples.size())
	var prev: float = 0.0
	for i in samples.size():
		prev = prev + alpha * (samples[i] - prev)
		out[i] = prev
	return out

## One-pole high-pass — thins noise into a whistle/hiss.
static func _highpass(samples: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples.size())
	var prev_in: float = 0.0
	var prev_out: float = 0.0
	for i in samples.size():
		var cur: float = samples[i]
		prev_out = alpha * (prev_out + cur - prev_in)
		prev_in = cur
		out[i] = prev_out
	return out

## Attack ramp-in + exponential decay envelope, applied in place.
static func _apply_env_ad(samples: PackedFloat32Array, attack: float, decay_rate: float) -> void:
	var n: int = samples.size()
	var n_a: int = maxi(1, int(attack * MIX_RATE))
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-decay_rate * t)
		if i < n_a:
			env *= float(i) / float(n_a)
		samples[i] *= env

static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v: float = 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		out[i] = clampf(v, -1.0, 1.0)
	return out

## Adds `overlay` into `base` starting at `offset` samples, extending `base`
## if needed. Used to layer sparkle/chirp/crackle transients into a bed.
static func _mix_at(base: PackedFloat32Array, overlay: PackedFloat32Array, offset: int) -> PackedFloat32Array:
	var need: int = offset + overlay.size()
	var out := PackedFloat32Array()
	out.resize(maxi(base.size(), need))
	out.fill(0.0)
	for i in base.size():
		out[i] = base[i]
	for i in overlay.size():
		var idx: int = offset + i
		out[idx] = clampf(out[idx] + overlay[i], -1.0, 1.0)
	return out

static func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out

## Blends the tail into the head so a looping bed wraps without a click.
static func _make_seamless(samples: PackedFloat32Array, xfade_samples: int) -> void:
	var n: int = samples.size()
	var x: int = mini(xfade_samples, n / 4)
	for i in x:
		var t: float = float(i) / float(x)
		var head: float = samples[i]
		var tail: float = samples[n - x + i]
		var blended: float = lerpf(tail, head, t)
		samples[i] = blended
		samples[n - x + i] = blended

static func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		var s16: int = int(round(v * 32767.0))
		bytes.encode_s16(i * 2, s16)
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav

# ── SFX recipes ───────────────────────────────────────────────────────────

static func _gen_card_draw() -> AudioStreamWAV:
	var s: PackedFloat32Array = _sine_sweep(300.0, 1100.0, 0.12, 0.4)
	_apply_env_ad(s, 0.01, 9.0)
	return _to_wav(s)

static func _gen_card_play() -> AudioStreamWAV:
	var thunk: PackedFloat32Array = _square(110.0, 0.1, 0.35)
	_apply_env_ad(thunk, 0.002, 18.0)
	var noise: PackedFloat32Array = _noise(0.05, 0.25, 501)
	_apply_env_ad(noise, 0.001, 40.0)
	return _to_wav(_mix(thunk, noise))

static func _gen_spell_resolve() -> AudioStreamWAV:
	var dur: float = 0.35
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var vibrato: float = sin(_TAU * 6.0 * t) * 6.0
		var f1: float = 523.25 + vibrato
		var f2: float = 659.25 + vibrato
		out[i] = sin(_TAU * f1 * t) * 0.28 + sin(_TAU * f2 * t) * 0.22
	_apply_env_ad(out, 0.04, 3.2)
	return _to_wav(out)

static func _gen_attack() -> AudioStreamWAV:
	var noise: PackedFloat32Array = _noise(0.18, 0.5, 42)
	_apply_env_ad(noise, 0.002, 22.0)
	var punch: PackedFloat32Array = _sine(90.0, 0.18, 0.4)
	_apply_env_ad(punch, 0.002, 14.0)
	return _to_wav(_mix(noise, punch))

static func _gen_battle_win() -> AudioStreamWAV:
	var notes: Array[float] = [523.25, 659.25, 783.99]
	var parts: Array = []
	for f: float in notes:
		var s: PackedFloat32Array = _sine(f, 0.2, 0.4)
		_apply_env_ad(s, 0.01, 6.0)
		parts.append(s)
	return _to_wav(_concat(parts))

static func _gen_battle_lose() -> AudioStreamWAV:
	var notes: Array[float] = [440.0, 349.23]
	var parts: Array = []
	for f: float in notes:
		var s: PackedFloat32Array = _sine(f, 0.3, 0.4)
		_apply_env_ad(s, 0.01, 4.0)
		parts.append(s)
	return _to_wav(_concat(parts))

static func _gen_alarm() -> AudioStreamWAV:
	var a: PackedFloat32Array = _sine(880.0, 0.12, 0.4)
	_apply_env_ad(a, 0.005, 10.0)
	var b: PackedFloat32Array = _sine(660.0, 0.15, 0.4)
	_apply_env_ad(b, 0.005, 8.0)
	return _to_wav(_concat([a, b]))

static func _gen_chest_open() -> AudioStreamWAV:
	var out: PackedFloat32Array = _saw_sweep(180.0, 90.0, 0.22, 0.22)
	_apply_env_ad(out, 0.02, 6.0)
	var ping_freqs: Array[float] = [1568.0, 1975.99, 2349.32]
	for idx in ping_freqs.size():
		var p: PackedFloat32Array = _sine(ping_freqs[idx], 0.12, 0.22)
		_apply_env_ad(p, 0.002, 18.0)
		var offset: int = int(0.15 * MIX_RATE) + int(0.08 * idx * MIX_RATE)
		out = _mix_at(out, p, offset)
	return _to_wav(out)

static func _gen_scroll_pickup() -> AudioStreamWAV:
	var notes: Array[float] = [659.25, 783.99, 987.77]
	var out := PackedFloat32Array()
	for i in notes.size():
		var s: PackedFloat32Array = _sine(notes[i], 0.15, 0.24)
		_apply_env_ad(s, 0.004, 10.0)
		out = _mix_at(out, s, int(0.05 * i * MIX_RATE))
	return _to_wav(out)

static func _gen_door_enter() -> AudioStreamWAV:
	var n: PackedFloat32Array = _noise(0.3, 0.4, 77)
	var lp: PackedFloat32Array = _lowpass(n, 0.06)
	var out := PackedFloat32Array()
	out.resize(lp.size())
	var size: int = lp.size()
	for i in size:
		var t: float = float(i) / float(size)
		var env: float = sin(PI * t)
		out[i] = lp[i] * env
	return _to_wav(out)

static func _gen_footstep() -> AudioStreamWAV:
	var n: PackedFloat32Array = _noise(0.06, 0.45, 909)
	var lp: PackedFloat32Array = _lowpass(n, 0.35)
	_apply_env_ad(lp, 0.001, 60.0)
	return _to_wav(lp)

static func _gen_nightfall_ambient() -> AudioStreamWAV:
	var dur: float = 1.5
	var n: int = int(dur * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var lfo: float = sin(_TAU * 0.3 * t) * 4.0
		var f: float = 110.0 + lfo
		var env: float = sin(PI * (t / dur))
		out[i] = (sin(_TAU * f * t) * 0.3 + sin(_TAU * f * 1.5 * t) * 0.15) * env
	return _to_wav(out)

static func _gen_ui_click() -> AudioStreamWAV:
	var s: PackedFloat32Array = _sine(2200.0, 0.03, 0.3)
	_apply_env_ad(s, 0.001, 80.0)
	return _to_wav(s)

static func _gen_land() -> AudioStreamWAV:
	var thud: PackedFloat32Array = _sine(70.0, 0.12, 0.4)
	_apply_env_ad(thud, 0.002, 20.0)
	var n: PackedFloat32Array = _noise(0.05, 0.15, 313)
	_apply_env_ad(n, 0.001, 40.0)
	return _to_wav(_mix(thud, n))

static func _gen_dig_success() -> AudioStreamWAV:
	var thump: PackedFloat32Array = _noise(0.12, 0.35, 611)
	_apply_env_ad(thump, 0.003, 18.0)
	var chime: PackedFloat32Array = _sine(1046.5, 0.18, 0.25)
	_apply_env_ad(chime, 0.01, 9.0)
	return _to_wav(_mix_at(thump, chime, int(0.05 * MIX_RATE)))

static func _gen_waystone_travel() -> AudioStreamWAV:
	var sweep: PackedFloat32Array = _sine_sweep(200.0, 1400.0, 0.35, 0.3)
	_apply_env_ad(sweep, 0.02, 5.0)
	var shimmer: PackedFloat32Array = _sine(1800.0, 0.2, 0.15)
	_apply_env_ad(shimmer, 0.05, 8.0)
	return _to_wav(_mix_at(sweep, shimmer, int(0.1 * MIX_RATE)))

# ── Biome ambience recipes (looping) ──────────────────────────────────────

static func _gen_ambience_grasslands() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: PackedFloat32Array = _noise(dur, 0.5, 1001)
	var bed: PackedFloat32Array = _lowpass(n, 0.04)
	for c in 3:
		var chirp: PackedFloat32Array = _sine_sweep(2200.0, 2800.0, 0.08, 0.12)
		_apply_env_ad(chirp, 0.01, 30.0)
		bed = _mix_at(bed, chirp, int((0.8 + c * 1.1) * MIX_RATE))
	_make_seamless(bed, int(0.2 * MIX_RATE))
	return _to_wav(bed, true)

static func _gen_ambience_forest() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: PackedFloat32Array = _noise(dur, 0.45, 2002)
	var bed: PackedFloat32Array = _lowpass(n, 0.025)
	var count: int = bed.size()
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		bed[i] *= 0.6 + 0.4 * sin(_TAU * 0.15 * t)
	_make_seamless(bed, int(0.2 * MIX_RATE))
	return _to_wav(bed, true)

static func _gen_ambience_desert() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: PackedFloat32Array = _noise(dur, 0.4, 3003)
	var bed: PackedFloat32Array = _highpass(n, 0.15)
	_make_seamless(bed, int(0.2 * MIX_RATE))
	return _to_wav(bed, true)

static func _gen_ambience_scorched() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: PackedFloat32Array = _noise(dur, 0.5, 4004)
	var bed: PackedFloat32Array = _lowpass(n, 0.015)
	for c in 6:
		var crackle: PackedFloat32Array = _noise(0.04, 0.3, 4100 + c)
		_apply_env_ad(crackle, 0.001, 60.0)
		bed = _mix_at(bed, crackle, int((0.5 + c * 0.6) * MIX_RATE))
	_make_seamless(bed, int(0.2 * MIX_RATE))
	return _to_wav(bed, true)

static func _gen_ambience_mountains() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: PackedFloat32Array = _noise(dur, 0.4, 5005)
	var bed: PackedFloat32Array = _lowpass(n, 0.03)
	var count: int = bed.size()
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var drone: float = sin(_TAU * 60.0 * t) * 0.05 + sin(_TAU * 63.0 * t) * 0.05
		bed[i] = clampf(bed[i] * 0.7 + drone, -1.0, 1.0)
	_make_seamless(bed, int(0.2 * MIX_RATE))
	return _to_wav(bed, true)
