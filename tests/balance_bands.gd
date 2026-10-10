## CI balance bands (GID-176 / TID-717): runs `BalanceBands.measure()` (~480
## seeded real-time fights, about a minute) and fails if the user's targets or
## the committed baseline (`tests/data/balance_baseline.json`) are missed.
## Too slow for the unit suite, so CI runs it as its own step.
##
##   godot --headless --path . -s tests/balance_bands.gd
##
## Moved the numbers on purpose? Regenerate the baseline and commit the diff:
##   godot --headless --path . -s tools/balance_sim.gd -- --write-baseline
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var bands: GDScript = load("res://game_logic/battle/BalanceBands.gd")
	var t0: int = Time.get_ticks_msec()
	var measured: Dictionary = bands.call("measure")
	var baseline: Dictionary = bands.call("load_baseline")
	var keys: Array = measured.keys()
	keys.sort()
	for k: Variant in keys:
		var m: Dictionary = measured[k]
		var b: Dictionary = baseline.get(k, {})
		print("%-26s win %5.1f%% (baseline %5.1f%%)  median %5.1f s" % [str(k), 100.0 * float(m["win_rate"]),
			100.0 * float(b.get("win_rate", -0.01)), float(m["median_s"])])
	var fails: Array = bands.call("check", measured, baseline)
	if baseline.is_empty():
		fails.append("no baseline at %s" % str(bands.get("BASELINE_PATH")))
	print("%d cells in %.1f s" % [measured.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	# TID-757: school-matched decks per biome roster and the weak-vs-resisted matchup.
	var t1: int = Time.get_ticks_msec()
	var schools: Dictionary = bands.call("measure_schools")
	for biome: String in schools["roster"]:
		var r: Dictionary = schools["roster"][biome]
		var line: String = "%-10s" % biome
		for k: String in ["default", "physical", "light", "dark", "verdant", "rift"]:
			line += "  %s %3.0f" % [k, 100.0 * float(r[k])]
		print(line)
	for mk: String in schools["matchup"]:
		var mu: Dictionary = schools["matchup"][mk]
		print("matchup %s  weak %3.0f  resisted %3.0f" % [mk, 100.0 * float(mu["weak"]), 100.0 * float(mu["resist"])])
	fails.append_array(bands.call("check_schools", schools))
	print("school bands (b) matchup and (c) best school: gating; (a) roster: report only")
	for note: Variant in bands.call("report_schools", schools):
		print("REPORT ONLY (a): " + str(note))
	print("school bands in %.1f s" % ((Time.get_ticks_msec() - t1) / 1000.0))
	for f: Variant in fails:
		printerr("BAND FAIL: " + str(f))
	print("RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)
