## QuestZones: WoW-style quest area blobs on the maps.
extends "res://tests/framework/test_case.gd"

const QuestZones = preload("res://game_logic/quests/QuestZones.gd")
const QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")


func test_camp_outline_covers_every_enemy_slot() -> void:
	var camp: Dictionary = StarterZone.CAMPS[2]
	var tile: Vector2i = camp["tile"]
	var z: Dictionary = QuestZones.for_target({"map": "main", "tx": tile.x, "tz": tile.y})
	var poly: PackedVector2Array = QuestZones.outline(z)
	assert_true(poly.size() >= 3)
	for i: int in range(int(camp["count"])):
		var off := Vector2(StarterZone.slot_tile(camp, i) - tile)
		assert_true(Geometry2D.is_point_in_polygon(off, poly), "slot %d inside the area" % i)


func test_site_is_single_spot() -> void:
	var z: Dictionary = QuestZones.for_target({"map": "main", "site": "wilderness_camp"})
	assert_eq((z["pts"] as Array).size(), 1)
	assert_true(Geometry2D.is_point_in_polygon(Vector2.ZERO, QuestZones.outline(z)))


func test_bounty_enemy_type_zones_at_its_camps() -> void:
	var bounty: Dictionary = {"id": "b1", "type": "defeat_enemy_type", "target": "ghoul_pack", "count": 2}
	var qs: Array[Dictionary] = QuestLog.active_quests({}, {}, [bounty])
	var zones: Array[Dictionary] = QuestLog.zones(qs[1])
	var expected: int = 0
	for c: Dictionary in StarterZone.CAMPS:
		if str(c["enemy_type"]) == "ghoul_pack":
			expected += 1
	assert_eq(zones.size(), expected)


func test_story_site_step_has_zone() -> void:
	var found: bool = false
	var flags: Dictionary = {}
	for step: Dictionary in QuestLog._StoryQuests.STEPS:
		if step.has("site"):
			var q: Dictionary = QuestLog.story_quest(flags)
			assert_eq(QuestLog.zones(q).size(), 1, str(step["id"]))
			found = true
			break
		flags[str(step["done_flag"])] = true
	assert_true(found)
