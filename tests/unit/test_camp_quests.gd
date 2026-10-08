## GID-177 / TID-722: Chapter 1 road camps and the repeatable camp bonus objectives.
extends "res://tests/framework/test_case.gd"

const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const Rivers = preload("res://game_logic/world/Rivers.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const CampDressing = preload("res://game_logic/world/CampDressing.gd")
const XpCurve = preload("res://game_logic/progression/XpCurve.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")

func test_camps_cover_chapter_one() -> void:
	var levels: Dictionary = {}
	for c: Dictionary in StarterZone.CAMPS:
		levels[StarterZone.camp_level(c)] = true
	for l: int in range(1, 11):
		assert_true(levels.has(l), "a camp at level %d" % l)

func test_road_camps_sit_on_clear_ground() -> void:
	RealmLayout.warm()
	for c: Dictionary in StarterZone.CAMPS:
		if not c.has("dress"):
			continue
		var t: Vector2i = c["tile"]
		var lvl: int = StarterZone.camp_level(c)
		var zr: Vector2i = ZoneLevels.range_at_tile(t.x, t.y)
		assert_true(lvl >= zr.x and lvl <= zr.y, "%s inside its zone" % str(c["id"]))
		assert_eq(RealmLayout.town_at_tile(t.x, t.y), "", "%s not in a town" % str(c["id"]))
		assert_gte(RealmLayout.road_distance(float(t.x), float(t.y)),
				StarterZone.CAMP_CLEAR_RADIUS + 2.0, "%s off the road" % str(c["id"]))
		for slot: int in range(int(c["count"])):
			var s: Vector2i = StarterZone.slot_tile(c, slot)
			assert_false(Rivers.deep_water(s.x, s.y), "%s slot %d dry" % [str(c["id"]), slot])
		assert_false(EnemyRegistry.get_deck(str(c["enemy_type"])).is_empty(), "%s enemy has a deck" % str(c["id"]))
		assert_gt(CampDressing.props_for(str(c["id"])).size(), 0, "%s is dressed" % str(c["id"]))
	for a: Dictionary in StarterZone.CAMPS:
		for b: Dictionary in StarterZone.CAMPS:
			if a != b:
				assert_gte(Vector2(a["tile"] as Vector2i).distance_to(Vector2(b["tile"] as Vector2i)),
						2.0 * StarterZone.CAMP_CLEAR_RADIUS, "%s / %s clearings apart" % [str(a["id"]), str(b["id"])])

func test_every_camp_has_a_bonus_objective() -> void:
	for c: Dictionary in StarterZone.CAMPS:
		var q: Dictionary = SideQuests.def(SideQuests.camp_quest_id(str(c["id"])))
		assert_false(q.is_empty(), "%s has a cull quest" % str(c["id"]))
		assert_true(SideQuests.is_repeatable(q) and bool(q["auto"]))
		assert_gte(int(q["min_level"]), SideQuests.CAMP_QUEST_MIN_LEVEL)

func test_enough_quests_per_level() -> void:
	for l: int in range(3, 10):
		var n: int = 0
		for q: Dictionary in SideQuests.all():
			var ml: int = int(q.get("min_level", 1))
			if ml <= l and ml >= l - 2:
				n += 1
		assert_gte(n, 3, "≥ 3 quests open around level %d (%d)" % [l, n])

func test_quest_kill_targets_match_their_level() -> void:
	for q: Dictionary in SideQuests.all():
		var ml: int = int(q.get("min_level", 1))
		if ml > 10:
			continue
		for o: Dictionary in SideQuests.objectives(q):
			if str(o["type"]) != "kill" or not o.has("tx"):
				continue
			var camp: Dictionary = {}
			for c: Dictionary in StarterZone.CAMPS:
				if c["tile"] == Vector2i(int(o["tx"]), int(o["tz"])):
					camp = c
			assert_false(camp.is_empty(), "%s targets a camp" % str(q["id"]))
			if camp.is_empty():
				continue
			assert_eq(str(camp["enemy_type"]), str(o["target"]), "%s target is the camp's type" % str(q["id"]))
			assert_lte(absi(StarterZone.camp_level(camp) - ml), 2,
					"%s (L%d) camp at L%d" % [str(q["id"]), ml, StarterZone.camp_level(camp)])

func test_auto_start_cooldown_and_payout() -> void:
	var sm := SaveManagerScript.new()
	sm.new_game(false)
	var camp: Dictionary = StarterZone.camp("wolf_hollow")
	var id: String = SideQuests.camp_quest_id("wolf_hollow")
	assert_false(sm.quests.auto_start(id, 0.0), "too low a level")
	sm.add_xp(XpCurve.xp_to_reach(5))
	assert_true(sm.quests.auto_start(id, 1000.0))
	assert_false(sm.quests.auto_start(id, 1000.0), "already running")
	var xp0: int = sm.xp
	for _i: int in SideQuests.CAMP_QUEST_KILLS:
		sm.quests.progress_event("kill", str(camp["enemy_type"]))
	assert_false(sm.quests.is_active(id), "auto-completed")
	assert_gt(sm.xp, xp0, "paid out")
	assert_false(sm.quests_completed.has(id), "repeatables never close for good")
	assert_false(sm.quests.auto_start(id, 1000.0 + 10.0), "on cooldown")
	assert_true(sm.quests.auto_start(id, Time.get_unix_time_from_system() + SideQuests.CAMP_QUEST_COOLDOWN_S + 1.0),
			"restarts after the cooldown")
