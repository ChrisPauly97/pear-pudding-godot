## GID-145 / TID-614-589: real audio files back every SFX key and ambience slot.
extends "res://tests/framework/test_case.gd"

const _AmbienceLayers = preload("res://game_logic/AmbienceLayers.gd")

func test_every_sfx_key_has_a_real_file() -> void:
	for key: String in AudioManager.SFX_PATHS:
		var path: String = AudioManager.SFX_PATHS[key]
		assert_true(ResourceLoader.exists(path), "'%s' needs %s" % [key, path])

func test_sfx_takes_exist_and_load_as_randomizer() -> void:
	for key: String in AudioManager.SFX_TAKES:
		var base: String = AudioManager.SFX_PATHS[key]
		var count: int = int(AudioManager.SFX_TAKES[key])
		for i: int in range(2, count + 1):
			var take: String = base.get_basename() + "_%d.ogg" % i
			assert_true(ResourceLoader.exists(take), "'%s' take %d missing" % [key, i])
		var rnd := AudioManager._load_sfx_takes(base, count) as AudioStreamRandomizer
		assert_not_null(rnd, "'%s' should load as a randomizer" % key)
		if rnd != null:
			assert_eq(rnd.streams_count, count)

func test_gain_table_only_names_real_keys() -> void:
	for key: String in AudioManager.SFX_GAIN_DB:
		assert_true(AudioManager.SFX_PATHS.has(key), "gain for unknown key '%s'" % key)
	for key: String in AudioManager.SFX_TAKES:
		assert_true(AudioManager.SFX_PATHS.has(key), "takes for unknown key '%s'" % key)

func test_ambience_files_exist_and_loop() -> void:
	var paths: Array[String] = []
	paths.assign(AudioManager.AMBIENCE_PATHS)
	for key: String in _AmbienceLayers.LAYER_PATHS:
		if key != "owls":  # no clean CC0 owl loop yet; synthesized fallback
			paths.append(str(_AmbienceLayers.LAYER_PATHS[key]))
	for path: String in paths:
		assert_true(ResourceLoader.exists(path), "missing %s" % path)
		var stream := load(path) as AudioStreamOggVorbis
		assert_not_null(stream, "%s should be ogg" % path)
		if stream != null:
			assert_true(stream.loop, "%s must loop seamlessly" % path)
