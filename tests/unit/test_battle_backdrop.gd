## Unit tests for the biome-aware battle backdrop (GID-126 / TID-475).
##
## The backdrop's look can only be judged by eye (see
## `tools/preview_battle_backdrop.gd`), so these tests guard the things that
## can silently break instead: that every biome — plus the no-biome sentinel
## every puzzle, PvP and dungeon battle carries — has a complete palette entry,
## that `apply()` produces a material wired to the real shader, and that every
## uniform the shader declares is actually written.  A typo'd parameter name is
## otherwise a silent no-op in Godot.
extends "res://tests/framework/test_case.gd"

const BattleBackdrop = preload("res://scenes/battle/BattleBackdrop.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

const _SHADER_PATH := "res://assets/shaders/battle_backdrop.gdshader"

## Keys every PALETTE entry must carry. `ridge_base` is deliberately optional —
## only the neutral vault, which has no biome to borrow hill colours from,
## overrides it.
const _REQUIRED_KEYS: Array[String] = [
	"ground", "ground_gain", "ground_desat", "ground_scale",
	"props", "prop_h",
	"sky_day", "sky_night",
	"ridge_amp", "ridge_jag", "ridge_sharp",
	"celestial", "dim",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _all_ids() -> Array[int]:
	var ids: Array[int] = [BattleBackdrop.NEUTRAL]
	for b in range(BiomeDef.COUNT):
		ids.append(b)
	return ids


func _applied(biome: int, is_night: bool) -> ShaderMaterial:
	var rect := ColorRect.new()
	BattleBackdrop.apply(rect, biome, is_night, false)
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	rect.free()
	return mat


## Uniform names declared by the shader source, so the test tracks the file
## rather than a hand-maintained copy of it.
func _shader_uniform_names() -> Array[String]:
	var src := FileAccess.get_file_as_string(_SHADER_PATH)
	var names: Array[String] = []
	var re := RegEx.new()
	re.compile("(?m)^uniform\\s+\\w+\\s+(\\w+)")
	for m in re.search_all(src):
		names.append(m.get_string(1))
	return names

# ---------------------------------------------------------------------------
# 1. Palette completeness
# ---------------------------------------------------------------------------

func test_every_biome_and_the_neutral_sentinel_have_a_palette_entry() -> void:
	for id in _all_ids():
		assert_true(BattleBackdrop.PALETTE.has(id),
			"PALETTE missing entry for biome %d" % id)


func test_every_palette_entry_has_every_required_key() -> void:
	for id in _all_ids():
		var entry: Dictionary = BattleBackdrop.PALETTE[id]
		for key in _REQUIRED_KEYS:
			assert_true(entry.has(key),
				"PALETTE[%d] missing key '%s'" % [id, key])


func test_every_palette_entry_supplies_two_sky_stops_and_two_props() -> void:
	for id in _all_ids():
		var entry: Dictionary = BattleBackdrop.PALETTE[id]
		assert_eq((entry["sky_day"] as Array).size(), 2,
			"PALETTE[%d].sky_day must be [top, horizon]" % id)
		assert_eq((entry["sky_night"] as Array).size(), 2,
			"PALETTE[%d].sky_night must be [top, horizon]" % id)
		assert_eq((entry["props"] as Array).size(), 2,
			"PALETTE[%d].props must name both scatter sprites" % id)


func test_every_palette_entry_loads_its_textures() -> void:
	for id in _all_ids():
		var entry: Dictionary = BattleBackdrop.PALETTE[id]
		assert_true(entry["ground"] is Texture2D,
			"PALETTE[%d].ground did not preload" % id)
		for p in (entry["props"] as Array):
			assert_true(p is Texture2D,
				"PALETTE[%d] prop did not preload" % id)


## The neutral entry is the fallback for every id the table does not name, so
## an out-of-range biome must never crash or return an empty dictionary.
func test_unknown_biome_ids_fall_back_to_the_neutral_vault() -> void:
	for id in [-99, -2, BiomeDef.COUNT, 999]:
		assert_eq(BattleBackdrop.palette_for(id),
			BattleBackdrop.PALETTE[BattleBackdrop.NEUTRAL],
			"biome %d should fall back to the neutral vault" % id)

# ---------------------------------------------------------------------------
# 2. apply() wiring
# ---------------------------------------------------------------------------

func test_apply_installs_a_shader_material_running_the_backdrop_shader() -> void:
	var mat := _applied(BiomeDef.GRASSLANDS, false)
	assert_true(mat != null, "apply() left no ShaderMaterial on the rect")
	assert_eq(mat.shader.resource_path, _SHADER_PATH,
		"material is not running the backdrop shader")


## A misspelled parameter name is silently ignored by Godot, so assert that
## every uniform the shader declares actually received a value.
func test_apply_writes_every_uniform_the_shader_declares() -> void:
	var mat := _applied(BiomeDef.FOREST, false)
	for name in _shader_uniform_names():
		assert_true(mat.get_shader_parameter(name) != null,
			"shader uniform '%s' was never set by apply()" % name)


func test_apply_covers_every_biome_day_and_night() -> void:
	for id in _all_ids():
		for night in [false, true]:
			var mat := _applied(id, night)
			assert_true(mat != null,
				"apply() produced no material for biome %d (night=%s)" % [id, night])
			assert_eq(float(mat.get_shader_parameter("night")),
				1.0 if night else 0.0,
				"biome %d did not carry its night flag" % id)


func test_night_darkens_the_ground_tint() -> void:
	for b in range(BiomeDef.COUNT):
		var day: Vector3 = _applied(b, false).get_shader_parameter("ground_tint")
		var night: Vector3 = _applied(b, true).get_shader_parameter("ground_tint")
		assert_true(night.length() < day.length(),
			"biome %d ground is not darker at night" % b)


## The vault is roofed — it must not draw a sun or a moon.
func test_the_neutral_vault_draws_no_celestial_body() -> void:
	var mat := _applied(BattleBackdrop.NEUTRAL, false)
	assert_eq(float(mat.get_shader_parameter("celestial")), 0.0,
		"the roofed vault should have no sun/moon")


func test_open_air_biomes_draw_a_celestial_body() -> void:
	for b in range(BiomeDef.COUNT):
		assert_eq(float(_applied(b, false).get_shader_parameter("celestial")), 1.0,
			"biome %d lost its sun/moon" % b)


## Colour uniforms are vec3 and the ground gain can overshoot 1.0; an
## out-of-range component would blow out the image rather than clip.
func test_colour_uniforms_stay_in_range() -> void:
	var colour_params: Array[String] = [
		"sky_top", "sky_horizon", "ridge_far", "ridge_near",
		"ground_tint", "ground_avg", "glow_tint", "dim_color",
	]
	for id in _all_ids():
		for night in [false, true]:
			var mat := _applied(id, night)
			for p in colour_params:
				var v: Vector3 = mat.get_shader_parameter(p)
				for c in [v.x, v.y, v.z]:
					assert_true(c >= 0.0 and c <= 1.0,
						"biome %d %s out of [0,1]: %s" % [id, p, v])


## `animate` off must actually reach the shader — the preview tool relies on it
## to capture reproducible frames.
func test_animation_can_be_frozen() -> void:
	assert_eq(float(_applied(BiomeDef.DESERT, false).get_shader_parameter("anim")), 0.0,
		"apply(animate=false) did not freeze the shader clock")


## apply() is called on every battle entry, including ones that never got a
## GameState; a null rect must be a no-op rather than a crash.
func test_apply_tolerates_a_null_rect() -> void:
	BattleBackdrop.apply(null, BiomeDef.GRASSLANDS, false)
	assert_true(true, "apply(null) must not crash")

# ---------------------------------------------------------------------------
# 3. Derived values
# ---------------------------------------------------------------------------

## The horizon is what makes the divider read as a skyline; if BattleScene's
## Divider anchor moves, this constant has to move with it.
func test_horizon_matches_the_battle_scene_divider_anchor() -> void:
	var scene := FileAccess.get_file_as_string("res://scenes/battle/BattleScene.tscn")
	var re := RegEx.new()
	re.compile("(?s)\\[node name=\"Divider\".*?anchor_top = ([0-9.]+)")
	var m := re.search(scene)
	assert_true(m != null, "could not find the Divider anchor in BattleScene.tscn")
	assert_eq(float(m.get_string(1)), BattleBackdrop.HORIZON,
		"BattleBackdrop.HORIZON drifted from the Divider anchor")


## ground_avg is measured from the texture rather than guessed, so it must land
## somewhere plausible rather than at the 0.5 fallback for a failed read.
func test_ground_average_is_measured_from_the_texture() -> void:
	var grass: Vector3 = _applied(BiomeDef.GRASSLANDS, false).get_shader_parameter("ground_avg")
	var stone: Vector3 = _applied(BattleBackdrop.NEUTRAL, false).get_shader_parameter("ground_avg")
	assert_true(grass != Vector3(0.5, 0.5, 0.5),
		"grass ground_avg fell back to the unmeasured default")
	assert_true(stone.length() < grass.length(),
		"the dungeon's stone floor should average darker than grassland")
