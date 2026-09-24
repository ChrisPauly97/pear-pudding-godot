## Unit tests for terrain-aware footsteps (GID-129 / TID-491).
##
## Covers FootstepSurface's surface table (biome, tile, named map, weather),
## the mounted variants, and that every key is registered in AudioManager and
## has a synthesized fallback.
extends "res://tests/framework/test_case.gd"

const FootstepSurface = preload("res://game_logic/FootstepSurface.gd")


func test_overworld_biome_ground() -> void:
	var g: int = IsoConst.TILE_GRASS
	assert_eq(FootstepSurface.surface_for(g, 0, "main", ""), "grass")
	assert_eq(FootstepSurface.surface_for(g, 1, "main", ""), "grass")
	assert_eq(FootstepSurface.surface_for(g, 2, "main", ""), "sand")
	assert_eq(FootstepSurface.surface_for(g, 3, "main", ""), "stone")
	assert_eq(FootstepSurface.surface_for(g, 4, "main", ""), "snow")
	assert_eq(FootstepSurface.surface_for(IsoConst.TILE_HILL, 4, "main", ""), "stone")
	assert_eq(FootstepSurface.surface_for(g, -1, "main", ""), "grass", "unknown biome → grass")


func test_paths_are_stone_except_desert() -> void:
	var p: int = IsoConst.TILE_PATH
	assert_eq(FootstepSurface.surface_for(p, 0, "main", ""), "stone")
	assert_eq(FootstepSurface.surface_for(p, 4, "main", ""), "stone")
	assert_eq(FootstepSurface.surface_for(p, 2, "main", ""), "sand")
	assert_eq(FootstepSurface.surface_for(IsoConst.TILE_CRACKED, 1, "main", ""), "stone")


func test_rain_makes_puddles() -> void:
	var g: int = IsoConst.TILE_GRASS
	var p: int = IsoConst.TILE_PATH
	assert_eq(FootstepSurface.surface_for(g, 0, "main", "rain"), "grass", "light rain leaves grass")
	assert_eq(FootstepSurface.surface_for(p, 0, "main", "rain"), "water", "light rain pools on paths")
	assert_eq(FootstepSurface.surface_for(g, 0, "main", "heavy_rain"), "water")
	assert_eq(FootstepSurface.surface_for(g, 2, "main", "heavy_rain"), "sand", "sand soaks it up")


func test_named_map_floors() -> void:
	var g: int = IsoConst.TILE_GRASS
	assert_eq(FootstepSurface.surface_for(g, -1, "player_home", ""), "wood")
	assert_eq(FootstepSurface.surface_for(g, -1, "guildhall", ""), "wood")
	assert_eq(FootstepSurface.surface_for(g, -1, "blancogov_temple", ""), "stone")
	assert_eq(FootstepSurface.surface_for(g, -1, "dungeon_2_99", ""), "stone")
	assert_eq(FootstepSurface.surface_for(g, -1, "spire_floor_3", ""), "stone")
	assert_eq(FootstepSurface.surface_for(g, -1, "madrian", ""), "grass")
	assert_eq(FootstepSurface.surface_for(IsoConst.TILE_PATH, -1, "madrian", ""), "stone")
	assert_eq(FootstepSurface.surface_for(g, -1, "madrian", "heavy_rain"), "grass", "no weather off-main")


func test_sfx_for_on_foot_and_mounted() -> void:
	var on_foot: Dictionary = FootstepSurface.sfx_for("snow", false)
	assert_eq(on_foot["key"], "footstep_snow")
	assert_eq(on_foot["pitch"], 1.0)
	var hard: Dictionary = FootstepSurface.sfx_for("stone", true)
	assert_eq(hard["key"], FootstepSurface.HOOF_KEY)
	var soft: Dictionary = FootstepSurface.sfx_for("grass", true)
	assert_eq(soft["key"], "footstep_grass")
	assert_lt(float(soft["pitch"]), 1.0, "mounted soft steps are heavier")
	assert_eq(FootstepSurface.sfx_for("lava", false)["key"], "footstep_grass", "unknown → grass")


func test_every_key_registered_and_synthesized() -> void:
	for key: String in FootstepSurface.all_keys():
		assert_true(AudioManager.SFX_PATHS.has(key), "'%s' must be in AudioManager.SFX_PATHS" % key)
		var stream: AudioStreamWAV = FootstepSurface.get_sfx(key)
		assert_not_null(stream, "'%s' must synthesize" % key)
		assert_gt(stream.data.size(), 0, "'%s' must have PCM data" % key)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "'%s' is a one-shot" % key)
	for s: String in FootstepSurface.SURFACES:
		var key: String = str(FootstepSurface.sfx_for(s, false)["key"])
		assert_true(key in FootstepSurface.all_keys(), "surface '%s' must map to a known key" % s)
