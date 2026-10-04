## End-to-end rules of the Pear Pudding legend (GID-153 / TID-657): tellers placed,
## riddle glades kept clear by world gen, the full chain and the one-time reward.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const Tales            = preload("res://game_logic/quests/Tales.gd")
const RiddleSpots      = preload("res://game_logic/world/RiddleSpots.gd")
const RealmLayout      = preload("res://game_logic/world/RealmLayout.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const WaterMath        = preload("res://game_logic/world/WaterMath.gd")
const LegendaryPotions = preload("res://game_logic/battle/LegendaryPotions.gd")
const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")

const SEEDS: Array[int] = [1, 42, 9999]

var _sm: SaveManagerScript

func get_suite_name() -> String:
	return "PearPuddingLegend"

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true
	_sm.story_flags = {}
	_sm.potions = {}

func after_each() -> void:
	_sm.free()

func test_every_teller_is_placed_in_their_town() -> void:
	var placed: Dictionary = {}
	for npc: Dictionary in RealmLayout.entities("npcs"):
		placed[str(npc.get("id", ""))] = RealmLayout.town_at_world(float(npc.get("x", 0.0)),
				float(npc.get("z", 0.0)))
	for t: Dictionary in Tales.TALES:
		var id: String = str(t["npc"])
		assert_true(placed.has(id), "%s is placed" % id)
		assert_eq(str(placed.get(id, "")), str(t["town"]), "%s stands in %s" % [id, t["town"]])

func test_riddle_glades_are_reserved_but_unmarked() -> void:
	for s: Dictionary in RiddleSpots.SPOTS:
		var t: Vector2i = s["tile"]
		var d: float = RealmLayout.reserved_distance(t.x, t.y)
		assert_true(d > 0.0, "%s never becomes a path tile" % s["id"])
		assert_true(d <= 1.0, "%s is reserved ground" % s["id"])
		assert_eq(RealmLayout.town_at_tile(t.x, t.y), "", "%s is in the wilds" % s["id"])
		var cs: int = IsoConst.CHUNK_SIZE
		assert_true(RealmLayout.chunk_touches_realm(floori(float(t.x) / cs), floori(float(t.y) / cs)))

func test_riddle_glades_are_walkable_dry_and_empty() -> void:
	var cs: int = IsoConst.CHUNK_SIZE
	for world_seed: int in SEEDS:
		for s: Dictionary in RiddleSpots.SPOTS:
			var t: Vector2i = s["tile"]
			var cx: int = floori(float(t.x) / cs)
			var cz: int = floori(float(t.y) / cs)
			var chunk = InfiniteWorldGen.generate_chunk(cx, cz, world_seed)
			var lx: int = t.x - cx * cs
			var lz: int = t.y - cz * cs
			assert_eq(int(chunk.call("get_tile", lx, lz)), IsoConst.TILE_GRASS, "%s grass (seed %d)" % [s["id"], world_seed])
			assert_eq(int(chunk.call("get_height", lx, lz)), 0, "%s flat (seed %d)" % [s["id"], world_seed])
			var wx: float = IsoConst.tile_center(t.x)
			var wz: float = IsoConst.tile_center(t.y)
			assert_eq(WaterMath.intensity(wx, wz, world_seed), 0.0, "%s dry (seed %d)" % [s["id"], world_seed])
			for e: Dictionary in (chunk.get("enemies") as Array):
				var dx: float = float(e.get("x", 0.0)) - wx
				var dz: float = float(e.get("z", 0.0)) - wz
				assert_true(dx * dx + dz * dz > 16.0, "no spawn on %s (seed %d)" % [s["id"], world_seed])

func _ctx(t: float = 0.5, weather: String = "clear") -> Dictionary:
	return {"flags": _sm.story_flags, "time_of_day": t, "weather": weather}

func _try(spot_id: String, action: String, t: float = 0.5, weather: String = "clear") -> String:
	var spot: Dictionary = RiddleSpots.def(spot_id)
	var r: String = RiddleSpots.evaluate(spot, action, _ctx(t, weather))
	if r == RiddleSpots.RESULT_SOLVED:
		_sm.story_flags[str(spot["sets_flag"])] = true
	return r

func test_full_chain() -> void:
	# Nothing reacts before the tales.
	assert_eq(_try("leaning_stones", "dig", 0.75), RiddleSpots.RESULT_IDLE)
	_sm.story_flags[Tales.flag_for("soldier")] = true
	assert_eq(_try("leaning_stones", "dig", 0.5), RiddleSpots.RESULT_HINT)
	assert_eq(_try("leaning_stones", "dig", 0.75), RiddleSpots.RESULT_SOLVED)
	_sm.story_flags[Tales.flag_for("rhyme")] = true
	assert_eq(_try("golden_pear_tree", "interact"), RiddleSpots.RESULT_SOLVED)
	# Spectre's sigh: needs the bard's tale; rides the kill event.
	_sm.quests.progress_event("kill", "spectre_wisp")
	assert_false(_sm.get_story_flag(RiddleSpots.SIGH_FLAG), "no sigh before the bard's tale")
	_sm.story_flags[Tales.flag_for("bard")] = true
	_sm.quests.progress_event("kill", "undead_basic")
	assert_false(_sm.get_story_flag(RiddleSpots.SIGH_FLAG), "only spectres sigh")
	_sm.quests.progress_event("kill", "spectre_haunt")
	assert_true(_sm.get_story_flag(RiddleSpots.SIGH_FLAG))
	_sm.story_flags[Tales.flag_for("farmer")] = true
	assert_eq(_try("queens_well", "interact", 0.5, "clear"), RiddleSpots.RESULT_HINT)
	assert_eq(_try("queens_well", "interact", 0.5, "rain"), RiddleSpots.RESULT_SOLVED)
	assert_true(_sm.get_story_flag(RiddleSpots.PUDDING_FLAG))

func test_sigh_needs_the_recipe() -> void:
	_sm.story_flags[Tales.flag_for("bard")] = true
	assert_false(RiddleSpots.earns_sigh("spectre_wisp", _sm.story_flags))
	_sm.story_flags["legend_recipe"] = true
	assert_true(RiddleSpots.earns_sigh("spectre_wisp", _sm.story_flags))

func test_reward_is_granted_once() -> void:
	assert_true(_sm.garden.grant_legendary(LegendaryPotions.PEAR_PUDDING))
	assert_false(_sm.garden.grant_legendary(LegendaryPotions.PEAR_PUDDING))
	assert_eq(int(_sm.potions[LegendaryPotions.PEAR_PUDDING]), 1)

func test_legend_never_appears_in_the_quest_log() -> void:
	for t: Dictionary in Tales.TALES:
		_sm.story_flags[Tales.flag_for(str(t["id"]))] = true
	for e: Dictionary in _sm.quests.log_entries():
		assert_false(str(e).contains("legend"), "quest log entry leaks the legend")

func test_brewing_unlocks_the_secret_achievement() -> void:
	var a: Dictionary = AchievementRegistry.get_achievement("spoonful_of_legend")
	assert_false(a.is_empty())
	assert_eq(AchievementRegistry.display_text(a, false)[0], "???", "secret until unlocked")
	assert_eq(AchievementRegistry.display_text(a, true)[0], "A Spoonful of Legend")
	_sm.set_story_flag(RiddleSpots.PUDDING_FLAG)
	assert_true(_sm.unlocked_achievements.has("spoonful_of_legend"))
