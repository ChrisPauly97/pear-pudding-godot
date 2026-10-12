## GID-187 / TID-792: gear tooltip formatting, percent at level, level requirement flag, compare deltas.
extends "res://tests/framework/test_case.gd"

const GearTooltip = preload("res://game_logic/items/GearTooltip.gd")
const WeaponData = preload("res://data/WeaponData.gd")

func _item(stats: Dictionary, il: int = 12, level_req: int = 10, band: String = "fine") -> WeaponData:
	var w := WeaponData.new()
	w.id = "t_tip"
	w.display_name = "Test Blade"
	w.band = band
	w.item_level = il
	w.level_req = level_req
	w.rarity = "rare"
	w.stats = stats
	return w

func test_stat_label_names_schools() -> void:
	assert_eq(GearTooltip.stat_label("haste"), "Haste")
	assert_eq(GearTooltip.stat_label("mastery:dark"), "Mastery (Dark)")

func test_flat_stat_line_shows_points_and_effect() -> void:
	assert_eq(GearTooltip.stat_line("stamina", 6.0, 1), "+6 Stamina (+6 max HP)")

func test_percent_stat_line_converts_at_level() -> void:
	# Level 1: 1 rating per %, so 12 Haste is 12 %.
	assert_eq(GearTooltip.stat_line("haste", 12.0, 1), "+12 Haste (12.0 %)")
	# Level 30: 1 + 0.1 × 29 = 3.9 rating per %, so 12 Haste is 3.1 %.
	assert_eq(GearTooltip.stat_line("haste", 12.0, 30), "+12 Haste (3.1 %)")

func test_percent_value_at_level_and_cap() -> void:
	assert_almost_eq(GearTooltip.value_at("haste", 12.0, 30), 3.0769, 0.01)
	# stat_pct_cap (0.5) bounds the % however much rating is stacked.
	assert_almost_eq(GearTooltip.value_at("haste", 300.0, 1), 50.0, 0.001)

func test_build_lines_name_band_and_stats() -> void:
	var w: WeaponData = _item({"attack_power": 10, "haste": 12})
	var tip: Dictionary = GearTooltip.build(w, 0, 30)
	assert_eq(str(tip["name"]), "Test Blade")
	assert_eq(str(tip["rarity"]), "rare")
	assert_eq(str(tip["band_line"]), "Fine · item level 12")
	var stat_lines: Array[String] = tip["stat_lines"]
	assert_eq(stat_lines.size(), 2)
	assert_eq(stat_lines[0], "+10 Attack Power (2.6 %)")
	assert_eq(stat_lines[1], "+12 Haste (3.1 %)")
	assert_eq(str(tip["mechanic_line"]), "")

func test_upgrade_level_scales_ratings_and_names_item() -> void:
	var w: WeaponData = _item({"haste": 12})
	var tip: Dictionary = GearTooltip.build(w, 2, 30)
	assert_eq(str(tip["name"]), "Test Blade +2")
	var stat_lines: Array[String] = tip["stat_lines"]
	# +10 % per upgrade level: 12 × 1.2 = 14.4 → 14.
	assert_eq(stat_lines[0], "+14 Haste (%.1f %%)" % (14.0 / 3.9))

func test_level_requirement_flag() -> void:
	var w: WeaponData = _item({"stamina": 6}, 12, 10)
	var below: Dictionary = GearTooltip.build(w, 0, 8)
	assert_false(bool(below["level_ok"]), "level 8 cannot wear a level 10 item")
	assert_eq(str(below["requires_line"]), "Requires level 10 (you are level 8)")
	var at: Dictionary = GearTooltip.build(w, 0, 10)
	assert_true(bool(at["level_ok"]), "level 10 can wear a level 10 item")
	assert_eq(str(at["requires_line"]), "Requires level 10")

func test_mechanic_line_for_legacy_deck_inject() -> void:
	var w: WeaponData = WeaponData.new()
	w.id = "t_inject"
	w.display_name = "Tome"
	w.battle_effect_type = "deck_inject"
	w.injected_card_id = "spark"
	w.injected_card_count = 2
	var tip: Dictionary = GearTooltip.build(w, 0, 1)
	assert_eq(str(tip["mechanic_line"]), "Inject 2× spark")
	var lines: Array[String] = tip["lines"]
	assert_has(lines, "Inject 2× spark")

func test_school_stat_line_and_summary() -> void:
	var w: WeaponData = _item({"attack_power": 10, "haste": 12})
	assert_eq(GearTooltip.summary(w, 0, 30), "+10 Attack Power (2.6 %), +12 Haste (3.1 %)")
	assert_true(GearTooltip.stat_line("mastery:dark", 8.0, 1).begins_with("+8 Mastery (Dark)"))

func test_compare_percent_delta_at_level() -> void:
	var cand: WeaponData = _item({"haste": 12})
	var eq: WeaponData = _item({"haste": 6})
	var deltas: Dictionary = GearTooltip.compare(cand, 0, eq, 0, 30)
	# 12 / 3.9 − 6 / 3.9 ≈ 1.54 % points.
	assert_almost_eq(float(deltas["haste"]), 1.5385, 0.01)
	var rows: Array[Dictionary] = GearTooltip.delta_rows(deltas)
	assert_eq(rows.size(), 1)
	assert_eq(str(rows[0]["text"]), "+1.5 % Haste")
	assert_true(bool(rows[0]["gain"]))

func test_compare_flat_gain_and_loss() -> void:
	var cand: WeaponData = _item({"stamina": 6})
	var eq: WeaponData = _item({"armor": 4})
	var deltas: Dictionary = GearTooltip.compare(cand, 0, eq, 0, 10)
	assert_almost_eq(float(deltas["stamina"]), 6.0, 0.001)
	assert_almost_eq(float(deltas["armor"]), -4.0, 0.001)
	var rows: Array[Dictionary] = GearTooltip.delta_rows(deltas)
	var texts: Array[String] = []
	var gains: Array[bool] = []
	for r: Dictionary in rows:
		texts.append(str(r["text"]))
		gains.append(bool(r["gain"]))
	assert_has(texts, "+6 Stamina")
	assert_has(texts, "-4 Armor")
	assert_has(gains, false)

func test_compare_against_empty_slot_is_all_gains() -> void:
	var cand: WeaponData = _item({"stamina": 6})
	var deltas: Dictionary = GearTooltip.compare(cand, 0, null, 0, 10)
	assert_almost_eq(float(deltas["stamina"]), 6.0, 0.001)
	assert_eq(deltas.size(), 1)

func test_compare_identical_items_has_no_deltas() -> void:
	var a: WeaponData = _item({"haste": 12, "stamina": 6})
	var b: WeaponData = _item({"haste": 12, "stamina": 6})
	assert_eq(GearTooltip.compare(a, 0, b, 0, 20).size(), 0)

func test_sheet_totals_sum_ratings_then_convert() -> void:
	var a: WeaponData = _item({"haste": 12})
	var b: WeaponData = _item({"haste": 12, "stamina": 6})
	var entries: Array[Dictionary] = [{"weapon": a, "level": 0}, {"weapon": b, "level": 0}]
	var lines: Array[String] = GearTooltip.sheet_lines(entries, 30)
	assert_eq(lines.size(), 2)
	# Flat stats first, then percent stats; the % is taken of the summed rating (24 / 3.9 ≈ 6.2).
	assert_eq(lines[0], "+6 Stamina (+6 max HP)")
	assert_eq(lines[1], "+24 Haste (6.2 %)")

func test_sheet_empty_when_nothing_equipped() -> void:
	var entries: Array[Dictionary] = []
	assert_eq(GearTooltip.sheet_lines(entries, 5).size(), 0)
