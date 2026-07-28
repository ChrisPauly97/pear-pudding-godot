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

## Keys every PALETTE entry must carry. `arena_tint` is deliberately optional —
## only the neutral vault, which has no biome to borrow a bare-earth colour
## from, overrides it.
const _REQUIRED_KEYS: Array[String] = [
	"ground", "ground_gain", "ground_desat", "ground_scale",
	"props", "prop_cells", "prop_density", "prop_scale",
	"light_day", "light_night",
	"dim",
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


func test_every_palette_entry_names_both_scatter_sprites() -> void:
	for id in _all_ids():
		var entry: Dictionary = BattleBackdrop.PALETTE[id]
		assert_eq((entry["props"] as Array).size(), 2,
			"PALETTE[%d].props must name both scatter sprites" % id)


## The shader resolves the whole prop layer with a single cell test and a
## single texture fetch, which is only correct while every prop stays inside
## its own cell. `prop_scale > 0.5` breaks that and props start getting clipped
## at cell boundaries.
func test_prop_scale_keeps_props_inside_their_cell() -> void:
	for id in _all_ids():
		var scale: float = float(BattleBackdrop.PALETTE[id]["prop_scale"])
		assert_true(scale > 0.0 and scale <= 0.5,
			"PALETTE[%d].prop_scale must be in (0, 0.5], got %f" % [id, scale])


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


## A shader that fails to compile still loads as a Resource and still accepts
## `set_shader_parameter` for anything — nothing about `apply()` would look
## wrong. Godot exposes no compile status to GDScript, but a failed parse
## registers no uniforms, so comparing the runtime uniform list against the
## names in the source is the guard. (This is what caught a sampler used in a
## ternary, which Godot's shader language rejects.)
func test_the_shader_actually_compiles() -> void:
	var declared: Array[String] = _shader_uniform_names()
	assert_true(declared.size() > 0, "parsed no uniforms out of the shader source")
	var registered: Array[String] = []
	for u in (_applied(BiomeDef.GRASSLANDS, false).shader.get_shader_uniform_list()):
		registered.append(str(u["name"]))
	for name in declared:
		assert_true(registered.has(name),
			"uniform '%s' is declared but not registered — the shader did not compile" % name)


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


## Day and night must actually reach the light colour, not just the ground —
## it is the pooled light and the battle line that carry the time of day now
## that there is no sky to recolour.
func test_light_tint_changes_between_day_and_night() -> void:
	for id in _all_ids():
		var day: Vector3 = _applied(id, false).get_shader_parameter("light_tint")
		var night: Vector3 = _applied(id, true).get_shader_parameter("light_tint")
		var entry: Dictionary = BattleBackdrop.PALETTE[id]
		if entry["light_day"] == entry["light_night"]:
			continue  # the roofed vault is torchlit around the clock
		assert_true(day != night,
			"biome %d serves the same light colour day and night" % id)


## Colour uniforms are vec3 and the ground gain can overshoot 1.0; an
## out-of-range component would blow out the image rather than clip.
func test_colour_uniforms_stay_in_range() -> void:
	var colour_params: Array[String] = [
		"ground_tint", "ground_avg", "arena_tint", "light_tint", "dim_color",
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

## The lit battle line is drawn on the layout's own divider rather than beside
## it; if BattleScene's Divider anchor moves, this constant has to move with it.
func test_divider_matches_the_battle_scene_divider_anchor() -> void:
	var scene := FileAccess.get_file_as_string("res://scenes/battle/BattleScene.tscn")
	var re := RegEx.new()
	re.compile("(?s)\\[node name=\"Divider\".*?anchor_top = ([0-9.]+)")
	var m := re.search(scene)
	assert_true(m != null, "could not find the Divider anchor in BattleScene.tscn")
	assert_eq(float(m.get_string(1)), BattleBackdrop.DIVIDER_Y,
		"BattleBackdrop.DIVIDER_Y drifted from the Divider anchor")


## The arena has to sit inside the card area — it ends at x = 0.86, where the
## side panel begins — with ground still showing around it. An arena that runs
## off the screen edge stops reading as a mat laid on the ground.
func test_arena_fits_inside_the_card_area_with_a_margin() -> void:
	var c: Vector2 = BattleBackdrop.ARENA_CENTER
	var h: Vector2 = BattleBackdrop.ARENA_HALF
	assert_true(c.x - h.x > 0.0, "arena runs off the left edge")
	assert_true(c.x + h.x < 0.86, "arena runs under the side panel")
	assert_true(c.y - h.y > 0.0, "arena runs off the top edge")
	assert_true(c.y + h.y < 1.0, "arena runs off the bottom edge")
	assert_true(BattleBackdrop.DIVIDER_Y > c.y - h.y
		and BattleBackdrop.DIVIDER_Y < c.y + h.y,
		"the battle line falls outside the arena it is scored across")


## ground_avg is measured from the texture rather than guessed, so it must land
## somewhere plausible rather than at the 0.5 fallback for a failed read.
func test_ground_average_is_measured_from_the_texture() -> void:
	var grass: Vector3 = _applied(BiomeDef.GRASSLANDS, false).get_shader_parameter("ground_avg")
	var stone: Vector3 = _applied(BattleBackdrop.NEUTRAL, false).get_shader_parameter("ground_avg")
	assert_true(grass != Vector3(0.5, 0.5, 0.5),
		"grass ground_avg fell back to the unmeasured default")
	assert_true(stone.length() < grass.length(),
		"the dungeon's stone floor should average darker than grassland")
