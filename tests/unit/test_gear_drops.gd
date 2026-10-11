## GID-187 / TID-791: gear sources follow the curve (GearDrops).
extends "res://tests/framework/test_case.gd"

const GearDrops = preload("res://game_logic/items/GearDrops.gd")
const GearCurve = preload("res://game_logic/items/GearCurve.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const SaveGear = preload("res://autoloads/save_manager/SaveGear.gd")
const SideQuests = preload("res://game_logic/quests/SideQuests.gd")

func test_every_level_and_slot_has_a_wearable_drop() -> void:
	for lv: int in range(1, 61):
		for s: String in GearDrops.SLOTS:
			if GearDrops.best_for(s, lv) == "":
				assert_lte(lv, 2, "%s has nothing wearable until level %d" % [s, lv])  # off-hand / ring / trinket open at 2
				continue
			var c: Array[String] = GearDrops.candidates(lv, s)
			assert_gt(c.size(), 0, "no %s drop at level %d" % [s, lv])
			for id: String in c:
				assert_lte(WeaponRegistry.get_weapon(id).level_req, lv, "%s wearable at %d" % [id, lv])

func test_drops_sit_near_the_player_level() -> void:
	for id: String in GearDrops.candidates(30):
		var w: WeaponData = WeaponRegistry.get_weapon(id)
		assert_true(w.item_level >= 30 - GearDrops.DROP_BELOW or id == GearDrops.best_for(GearCurve.slot_of(w), 30),
				"%s (ilvl %d) is far below 30" % [id, w.item_level])

func test_starter_weapon_never_drops() -> void:
	for lv: int in [1, 5, 30]:
		assert_false(GearDrops.candidates(lv).has(GearDrops.STARTER_WEAPON))

func test_expected_loadout_fills_every_slot_and_climbs() -> void:
	var low: Dictionary = GearDrops.expected_loadout(5)
	var high: Dictionary = GearDrops.expected_loadout(50)
	assert_eq(low.size(), GearDrops.SLOTS.size())
	assert_eq(high.size(), GearDrops.SLOTS.size())
	for s: String in GearDrops.SLOTS:
		assert_gt(WeaponRegistry.get_weapon(str(high[s])).item_level,
				WeaponRegistry.get_weapon(str(low[s])).item_level, s)

func test_pity_fills_a_slot_that_fell_behind() -> void:
	var lv: int = 40
	var equipped: Dictionary = GearDrops.expected_loadout(lv)
	equipped["boots"] = GearDrops.best_for("boots", 5)  # two+ bands behind
	assert_eq(GearDrops.behind_slots(lv, equipped), ["boots"] as Array[String])
	var rng := RandomNumberGenerator.new()
	for i: int in 20:
		rng.seed = i
		var id: String = GearDrops.pick(lv, [], equipped, rng)
		assert_eq(GearCurve.slot_of(WeaponRegistry.get_weapon(id)), "boots")

func test_pick_prefers_unowned() -> void:
	var lv: int = 25
	var equipped: Dictionary = GearDrops.expected_loadout(lv)
	var all: Array[String] = GearDrops.candidates(lv)
	var keep: String = all[0]
	var owned: Array = all.duplicate()
	owned.erase(keep)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_eq(GearDrops.pick(lv, owned, equipped, rng), keep)

func test_drops_record_the_authored_roll() -> void:
	var id: String = GearDrops.best_for("armor", 50)
	var w: WeaponData = WeaponRegistry.get_weapon(id)
	var roll: Dictionary = SaveGear.roll_for(id, 4, 50, RandomNumberGenerator.new())
	assert_eq(str(roll["rarity"]), w.rarity)
	assert_eq(int(roll["ilvl"]), w.item_level)
	assert_false(roll.has("affix"), "no random affix")

func test_quest_gear_is_wearable_at_the_quest_level() -> void:
	for q: Dictionary in SideQuests.all():
		var id: String = str(q.get("id", ""))
		var choice: Array = (q.get("rewards", {}) as Dictionary).get("gear_choice", [])
		for g: Variant in choice:
			var w: WeaponData = WeaponRegistry.get_weapon(str(g))
			assert_true(w != null, "%s: unknown gear %s" % [id, g])
			assert_lte(w.level_req, int(q.get("min_level", 1)) + 1, "%s: %s needs level %d" % [id, g, w.level_req])

func test_price_grows_with_the_curve() -> void:
	var low: WeaponData = WeaponRegistry.get_weapon(GearDrops.best_for("armor", 5))
	var high: WeaponData = WeaponRegistry.get_weapon(GearDrops.best_for("armor", 50))
	assert_gt(GearDrops.price(high), GearDrops.price(low))

func test_build_fit_prefers_own_school_mastery() -> void:
	var w := WeaponData.new()
	w.stats = {"spell_power": 10, "mastery:dark": 10}
	assert_gt(GearDrops.fit(w, "dark"), GearDrops.fit(w, "light"), "another school's Mastery is worth nothing")
	var loadout: Dictionary = GearDrops.expected_loadout(40, "light")
	for s: String in loadout:
		var item: WeaponData = WeaponRegistry.get_weapon(str(loadout[s]))
		var top: WeaponData = WeaponRegistry.get_weapon(GearDrops.best_for(s, 40))
		assert_gte(item.item_level, top.item_level - GearDrops.FIT_WINDOW, s)
