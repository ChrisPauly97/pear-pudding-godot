## Unit tests for TownLife — walking townsfolk and daily schedules (GID-156).
extends "res://tests/framework/test_case.gd"

const TownLife = preload("res://game_logic/world/TownLife.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")

const DAY: float = 600.0


## A plus-shaped street: x 0..20 along z=10, z 0..20 along x=10.
func _streets() -> Dictionary:
	var tiles: Dictionary = {}
	for i: int in range(21):
		tiles[Vector2i(i, 10)] = true
		tiles[Vector2i(10, i)] = true
	var lamps: Array[Vector2i] = [Vector2i(2, 11), Vector2i(18, 9), Vector2i(9, 2), Vector2i(11, 18)]
	return {"tiles": tiles, "lamps": lamps}


func _npc(id: String, tx: int, tz: int, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": id, "x": IsoConst.tile_center(tx), "z": IsoConst.tile_center(tz),
			"npc_type": "", "flag_key": ""}
	d.merge(extra, true)
	return d


func _npcs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(6):
		out.append(_npc("t:npc_%d" % i, 3 + i * 2, 11))
	return out


func _tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / IsoConst.TILE_SIZE), floori(p.y / IsoConst.TILE_SIZE))


func test_candidates_exclude_special_npcs() -> void:
	assert_true(TownLife.is_candidate(_npc("madrian:npc_4", 0, 0)), "plain extra walks")
	assert_false(TownLife.is_candidate(_npc("merchant_8", 0, 0, {"npc_type": "merchant"})), "merchant stays")
	assert_false(TownLife.is_candidate(_npc("madrian:npc_2", 0, 0, {"flag_key": "x"})), "story NPC stays")
	assert_false(TownLife.is_candidate(_npc("madrian:npc_9", 0, 0, {"show_flag_key": "x"})), "gated NPC stays")
	assert_false(TownLife.is_candidate(_npc("hilda_baker", 0, 0)), "named quest giver stays")


func test_plan_is_deterministic_and_capped() -> void:
	var a: Dictionary = TownLife.plan(_streets(), Vector2i(10, 10), _npcs(), 7, DAY)
	var b: Dictionary = TownLife.plan(_streets(), Vector2i(10, 10), _npcs(), 7, DAY)
	assert_gt(a.size(), 0, "some townsfolk walk")
	assert_true(a.size() <= TownLife.MAX_WALKERS, "walker cap")
	assert_eq(a.keys(), b.keys(), "same walkers every time")
	for id: Variant in a:
		var wa: Dictionary = a[id]
		var wb: Dictionary = b[id]
		for t: float in [0.0, 17.3, 333.3]:
			var pa: Vector2 = TownLife.sample(wa, t)["pos"]
			var pb: Vector2 = TownLife.sample(wb, t)["pos"]
			assert_eq(pa, pb, "same position at t=%s" % t)


func test_walkers_stay_on_streets_and_never_jump() -> void:
	var streets: Dictionary = _streets()
	var tiles: Dictionary = streets["tiles"]
	var plan: Dictionary = TownLife.plan(streets, Vector2i(10, 10), _npcs(), 3, DAY)
	var step: float = 0.25
	for id: Variant in plan:
		var w: Dictionary = plan[id]
		var loops: float = DAY / float(w["period"])
		assert_almost_eq(loops, roundf(loops), 0.001, "whole loops per day")
		var prev: Vector2 = TownLife.sample(w, 0.0)["pos"]
		var t: float = step
		while t <= DAY + 0.01:
			var p: Vector2 = TownLife.sample(w, t)["pos"]
			assert_true(tiles.has(_tile_of(p)), "on a street tile")
			assert_true(p.distance_to(prev) <= TownLife.WALK_SPEED * step + 0.01, "no teleport")
			prev = p
			t += step
		var wrap: Vector2 = TownLife.sample(w, 0.0)["pos"]
		assert_true(prev.distance_to(wrap) <= TownLife.WALK_SPEED * step + 0.01, "day wrap is continuous")


func test_indoor_townsfolk_do_not_walk() -> void:
	var npcs: Array[Dictionary] = [_npc("t:npc_far", 1, 1)]
	assert_true(TownLife.plan(_streets(), Vector2i(10, 10), npcs, 1, DAY).is_empty(), "far from streets")


func test_role_hours() -> void:
	assert_true(TownLife.is_out(TownLife.ROLE_VILLAGER, 0.5), "villager out at noon")
	assert_false(TownLife.is_out(TownLife.ROLE_VILLAGER, 0.9), "villager in at night")
	assert_true(TownLife.is_out(TownLife.ROLE_REVELLER, 0.85), "reveller out late")
	assert_true(TownLife.is_out(TownLife.ROLE_GUARD, 0.95), "guard out at night")
	assert_true(TownLife.is_out(TownLife.ROLE_GUARD, 0.1), "guard out before dawn")
	assert_false(TownLife.is_out(TownLife.ROLE_GUARD, 0.5), "guard off at noon")
	var plan: Dictionary = TownLife.plan(_streets(), Vector2i(10, 10), _npcs(), 5, DAY)
	var day_out: int = 0
	var night_out: int = 0
	var guards: int = 0
	for id: Variant in plan:
		var role: String = str((plan[id] as Dictionary)["role"])
		day_out += 1 if TownLife.is_out(role, 0.5) else 0
		night_out += 1 if TownLife.is_out(role, 0.97) else 0
		guards += 1 if role == TownLife.ROLE_GUARD else 0
	assert_eq(guards, 1, "one guard per town")
	assert_gt(day_out, night_out, "busier by day than at night")


func test_real_towns_have_walkers() -> void:
	var total: int = 0
	for town: String in RealmLayout.town_names():
		var shift: Vector2 = RealmLayout.world_shift(town)
		var npcs: Array[Dictionary] = []
		for e: Dictionary in RealmLayout.entities("npcs"):
			if str(e.get("town", "")) != town:
				continue
			var local: Dictionary = e.duplicate()
			local["x"] = float(e["x"]) - shift.x
			local["z"] = float(e["z"]) - shift.y
			npcs.append(local)
		total += TownLife.plan(RealmLayout.street_plan(town), RealmLayout.hub_of(town), npcs, 1, DAY).size()
	assert_gt(total, 3, "the stitched towns have walking townsfolk")
