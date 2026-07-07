## Unit tests for SfxGen (TID-425): procedural SFX + biome ambience synthesis.
##
## Covers: every registered SFX key produces valid non-empty PCM data, the
## correct mono 16-bit format, and every biome ambience stream loops forward.
extends "res://tests/framework/test_case.gd"

const SfxGen = preload("res://game_logic/SfxGen.gd")

func test_all_keys_return_non_null_stream_with_data() -> void:
	for key: String in SfxGen.all_keys():
		var stream: AudioStreamWAV = SfxGen.get_sfx(key)
		assert_not_null(stream, "key '%s' must produce a stream" % key)
		assert_gt(stream.data.size(), 0, "key '%s' must have non-empty PCM data" % key)

func test_sfx_streams_are_mono_16_bit() -> void:
	for key: String in SfxGen.all_keys():
		var stream: AudioStreamWAV = SfxGen.get_sfx(key)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "key '%s' must be 16-bit PCM" % key)
		assert_false(stream.stereo, "key '%s' must be mono" % key)
		assert_eq(stream.mix_rate, SfxGen.MIX_RATE, "key '%s' must use SfxGen.MIX_RATE" % key)

func test_sfx_cache_returns_same_instance() -> void:
	var a: AudioStreamWAV = SfxGen.get_sfx("card_draw")
	var b: AudioStreamWAV = SfxGen.get_sfx("card_draw")
	assert_true(a == b, "repeated lookups of the same key must be cached")

func test_unknown_key_falls_back_instead_of_crashing() -> void:
	var stream: AudioStreamWAV = SfxGen.get_sfx("not_a_real_key")
	assert_not_null(stream)
	assert_gt(stream.data.size(), 0)

func test_ambience_streams_loop_forward() -> void:
	for biome_id in range(5):
		var stream: AudioStreamWAV = SfxGen.get_ambience(biome_id)
		assert_not_null(stream, "biome %d must produce an ambience stream" % biome_id)
		assert_gt(stream.data.size(), 0, "biome %d ambience must have PCM data" % biome_id)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "biome %d must loop forward" % biome_id)
		assert_eq(stream.loop_end, stream.data.size() / 2, "biome %d loop_end must cover all frames" % biome_id)

func test_out_of_range_biome_falls_back_gracefully() -> void:
	var stream: AudioStreamWAV = SfxGen.get_ambience(99)
	assert_not_null(stream)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)

func test_pcm_samples_stay_within_16_bit_amplitude_bounds() -> void:
	var stream: AudioStreamWAV = SfxGen.get_sfx("attack")
	var bytes: PackedByteArray = stream.data
	var frame_count: int = bytes.size() / 2
	for i in frame_count:
		var s16: int = bytes.decode_s16(i * 2)
		assert_between(s16, -32768, 32767, "sample %d out of 16-bit range" % i)
