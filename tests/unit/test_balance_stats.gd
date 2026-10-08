## GID-176 / TID-716: balance simulator aggregation math.
extends "res://tests/framework/test_case.gd"

const BalanceStats = preload("res://game_logic/battle/BalanceStats.gd")

func test_wilson_interval() -> void:
	var ci: Array[float] = BalanceStats.wilson(50, 100)
	assert_lt(absf(ci[0] - 0.4038), 0.001)
	assert_lt(absf(ci[1] - 0.5962), 0.001)
	var all: Array[float] = BalanceStats.wilson(30, 30)
	assert_eq(all[1], 1.0)
	assert_lt(absf(all[0] - 0.8865), 0.001, "30/30 is still only ≥ 88.6 % at 95 %")
	assert_eq(BalanceStats.wilson(0, 0), [0.0, 1.0] as Array[float])

func test_percentile_nearest_rank() -> void:
	var v: Array[float] = [5.0, 1.0, 3.0, 2.0, 4.0]
	assert_eq(BalanceStats.percentile(v, 0.5), 3.0)
	assert_eq(BalanceStats.percentile(v, 0.1), 1.0)
	assert_eq(BalanceStats.percentile(v, 0.9), 5.0)
	assert_eq(BalanceStats.percentile([] as Array[float], 0.5), 0.0)

func test_summarize() -> void:
	var rs: Array[Dictionary] = [
		{"result": "win", "seconds": 10.0, "hero_hp_frac": 0.5, "dealt_cards": 30, "dealt_auto": 10},
		{"result": "loss", "seconds": 20.0, "hero_hp_frac": 0.0, "dealt_cards": 10, "dealt_auto": 30},
		{"result": "timeout", "seconds": 300.0, "hero_hp_frac": 1.0},
	]
	var s: Dictionary = BalanceStats.summarize(rs)
	assert_eq(int(s["n"]), 3)
	assert_eq(int(s["wins"]), 1)
	assert_eq(int(s["timeouts"]), 1)
	assert_eq(float(s["median_s"]), 20.0)
	assert_eq(float(s["card_share"]), 0.5)

func test_csv_row_matches_header() -> void:
	var row: String = BalanceStats.csv_row("x", 7, {"result": "win", "plays": {"b": 2, "a": 1}})
	assert_eq(row.split(",").size(), BalanceStats.CSV_HEADER.split(",").size())
	assert_true(row.ends_with("a:1;b:2"), "plays sorted")
