## GID-182 / TID-766: profession trainers and unlocks. The three profession features
## sit on the UnlockLadder, taught by the Master Artisan in Madrian; a station stays
## shut until its profession is learned (pure gate); the v51 migration grants them to
## older saves only; the Character screen's profession block reads the save; and the
## trainer stands on open ground in the square.
extends "res://tests/framework/test_case.gd"

const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const TownDecor = preload("res://game_logic/world/TownDecor.gd")
const WorldMap = preload("res://game_logic/world/WorldMap.gd")
const StationSites = preload("res://game_logic/professions/StationSites.gd")
const IsoConst = preload("res://autoloads/IsoConst.gd")
const CharacterProfessions = preload("res://scenes/ui/CharacterProfessions.gd")

const _FEATURES: Array[String] = [
	UnlockLadder.FEAT_COOKING, UnlockLadder.FEAT_ALCHEMY, UnlockLadder.FEAT_CRAFTING,
]
const _CRAFTER_NPC: String = "crafter_madrian"


func test_three_profession_features_on_the_ladder() -> void:
	for id: String in _FEATURES:
		assert_true(UnlockLadder.has(id), "%s is a ladder row" % id)
		assert_eq(str(UnlockLadder.def(id)["kind"]), "feature", "%s is a feature" % id)
		assert_eq(UnlockLadder.trainer_for(id), "crafter", "%s taught by the Master Artisan" % id)
		assert_gt(UnlockLadder.level_req(id), 10, "%s comes after the early one-per-level run" % id)
		assert_gt(UnlockLadder.cost(id), 0, "%s costs gold" % id)
		assert_gt(str(UnlockLadder.def(id)["how_to"]).length(), 40, "%s explains itself" % id)


func test_crafter_trainer_is_wired_to_its_npc() -> void:
	assert_eq(UnlockLadder.trainer_name("crafter"), "Master Artisan")
	assert_eq(str(UnlockLadder.TRAINER_NPCS.get("crafter", "")), _CRAFTER_NPC)
	assert_eq(UnlockLadder.trainer_at(_CRAFTER_NPC), "crafter")
	assert_eq(UnlockLadder.for_trainer("crafter").size(), _FEATURES.size(), "teaches exactly the three")


func test_every_profession_has_a_feature_and_back() -> void:
	for prof: String in ProfessionDefs.PROFESSIONS:
		var id: String = UnlockLadder.profession_feature(prof)
		assert_ne(id, "", "%s has a gating feature" % prof)
		assert_true(UnlockLadder.has(id), "%s feature is on the ladder" % prof)
	assert_eq(UnlockLadder.profession_feature("not_a_profession"), "", "unknown profession is ungated")
	assert_eq(UnlockLadder.PROFESSION_FEATURES.size(), ProfessionDefs.PROFESSIONS.size())


func test_station_refuses_until_learned_then_opens() -> void:
	for prof: String in ProfessionDefs.PROFESSIONS:
		var id: String = UnlockLadder.profession_feature(prof)
		var block: String = UnlockLadder.station_block(prof, [])
		assert_ne(block, "", "%s station refuses when not learned" % prof)
		assert_true(block.contains("Master Artisan"), "message names the trainer: " + block)
		assert_true(block.contains(str(UnlockLadder.level_req(id))), "message names the level: " + block)
		assert_eq(UnlockLadder.station_block(prof, [id]), "", "%s station opens when learned" % prof)


func test_station_gate_agrees_with_has_learned() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	for prof: String in ProfessionDefs.PROFESSIONS:
		var id: String = UnlockLadder.profession_feature(prof)
		var shut: bool = UnlockLadder.station_block(prof, sm.learned_abilities) != ""
		assert_eq(shut, not sm.has_learned(id), "%s gate matches has_learned" % prof)
	sm.learned_abilities.append(UnlockLadder.FEAT_ALCHEMY)
	assert_eq(UnlockLadder.station_block(ProfessionDefs.ALCHEMY, sm.learned_abilities), "")
	assert_ne(UnlockLadder.station_block(ProfessionDefs.COOKING, sm.learned_abilities), "",
			"one feature opens one station")


func test_gathering_is_not_a_profession_gate() -> void:
	# Gathering nodes are never gated: only stations map to a feature.
	for id: String in ["herb", "ore", "fish"]:
		assert_eq(UnlockLadder.profession_feature(id), "", "%s is not a profession" % id)


func test_migration_v51_grants_old_saves_only() -> void:
	assert_eq(SaveMigrations.CURRENT_VERSION, 51)
	var old: Dictionary = {"version": 50, "learned_abilities": ["mend"]}
	SaveMigrations.apply(old)
	for id: String in _FEATURES:
		assert_true((old["learned_abilities"] as Array).has(id), "v50 save gets %s" % id)
	assert_true((old["learned_abilities"] as Array).has("mend"), "existing learned kept")
	assert_eq(int(old["version"]), 51)
	var ancient: Dictionary = {"version": 44, "learned_abilities": []}
	SaveMigrations.apply(ancient)
	assert_true((ancient["learned_abilities"] as Array).has(UnlockLadder.FEAT_CRAFTING), "v44 save gets them too")
	var fresh: Dictionary = {"version": 51, "learned_abilities": []}
	SaveMigrations.apply(fresh)
	assert_true((fresh["learned_abilities"] as Array).is_empty(), "a v51 save is not granted")


func test_fresh_save_must_learn_the_professions() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	for id: String in _FEATURES:
		assert_false(sm.has_learned(id), "fresh save has not learned %s" % id)


func test_character_block_shows_levels_and_known_recipes() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	sm.learned_abilities.assign(_FEATURES)
	var parent := VBoxContainer.new()
	CharacterProfessions.build(parent, sm, 720.0)
	var texts: Array[String] = []
	_collect_text(parent, texts)
	assert_true(_any_contains(texts, "Level 1  -  XP 0 /"), "level and XP line shown")
	for prof: String in ProfessionDefs.PROFESSIONS:
		var known: int = 0
		var total: int = 0
		for id: String in ProfessionDefs.recipes_for(prof):
			total += 1
			if ProfessionDefs.band(id, 1) != "locked":
				known += 1
		var want: String = "Recipes known: %d / %d" % [known, total]
		assert_true(_any_contains(texts, want), "%s shows '%s'" % [prof, want])
	parent.free()


func test_character_block_points_at_the_trainer_when_unlearned() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	sm.new_game(false)
	var parent := VBoxContainer.new()
	CharacterProfessions.build(parent, sm, 720.0)
	var texts: Array[String] = []
	_collect_text(parent, texts)
	assert_true(_any_contains(texts, "Master Artisan"), "unlearned professions name the trainer")
	assert_false(_any_contains(texts, "Recipes known"), "no recipe count before learning")
	parent.free()


func test_crafter_stands_on_open_ground_in_the_square() -> void:
	var wm: WorldMap = RealmLayout.town_map("madrian")
	assert_not_null(wm, "madrian map loads")
	var tile: Vector2i = Vector2i(-1, -1)
	for e: Dictionary in wm.npcs:
		if str(e.get("id", "")) == _CRAFTER_NPC:
			tile = IsoConst.world_to_tile(float(e["x"]), float(e["z"]))
	assert_ne(tile, Vector2i(-1, -1), "crafter is placed on madrian")
	assert_false(TownDecor.blocked_local("madrian").has(tile), "not on a set piece")
	for s: Dictionary in StationSites.sites_in("madrian"):
		assert_ne(s["tile"], tile, "not on station %s" % str(s["id"]))
	var t: int = wm.get_tile(tile.x, tile.y)
	assert_false(t == WorldMap.TILE_WALL or t == WorldMap.TILE_CRACKED, "open ground")
	var clashes: int = 0
	for e: Dictionary in _all_entities(wm):
		if IsoConst.world_to_tile(float(e.get("x", 0.0)), float(e.get("z", 0.0))) == tile:
			clashes += 1
	assert_eq(clashes, 1, "only the crafter stands on its tile")


func _all_entities(wm: WorldMap) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for list: Array in [wm.npcs, wm.doors, wm.chests, wm.scrolls, wm.shrines, wm.enemies, wm.waystones]:
		for e: Variant in list:
			out.append(e as Dictionary)
	return out


func _collect_text(root: Node, out: Array[String]) -> void:
	for c: Node in root.get_children():
		if c is Label:
			out.append((c as Label).text)
		_collect_text(c, out)


func _any_contains(texts: Array[String], needle: String) -> bool:
	for t: String in texts:
		if t.contains(needle):
			return true
	return false
