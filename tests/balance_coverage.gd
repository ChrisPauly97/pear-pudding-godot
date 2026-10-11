## Wide balance coverage (GID-186): runs `BalanceCoverage` sections — every Chapter 1
## level, the world types past Chapter 1 over levels 5-60, the school matrix and the
## bosses — and fails when a target is missed. CI runs the sections side by side:
##
##   godot --headless --path . -s tests/balance_coverage.gd -- --section range
##   godot --headless --path . -s tests/balance_coverage.gd -- --section world_low --tune power_per_level=0.1
##
## No --section runs them all. Exit code 0 = pass, 1 = fail.
extends SceneTree

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var cov: GDScript = load("res://game_logic/battle/BalanceCoverage.gd")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sections: Array = (cov.get("SECTIONS") as Array).duplicate()
	var tune: Dictionary = {}
	for i: int in args.size() - 1:
		if args[i] == "--section":
			sections = Array(args[i + 1].split(",", false))
		elif args[i] == "--tune":
			for kv: String in args[i + 1].split(",", false):
				tune[kv.get_slice("=", 0)] = float(kv.get_slice("=", 1))
	var fails: Array = []
	for section: Variant in sections:
		var t0: int = Time.get_ticks_msec()
		var res: Dictionary = cov.call("run_section", str(section), tune)
		var measured: Dictionary = res["measured"]
		var keys: Array = measured.keys()
		keys.sort()
		for k: Variant in keys:
			var m: Dictionary = measured[k]
			if m.has("untagged"):
				print("%-10s %-40s win %5.1f%%  untagged %5.1f%%" % [section, str(k), 100.0 * float(m["rate"]),
					100.0 * float(m["untagged"])])
			else:
				print("%-10s %-30s win %5.1f%%  median %5.1f s" % [section, str(k), 100.0 * float(m["win_rate"]),
					float(m["median_s"])])
		print("%s: %d cells in %.1f s" % [section, measured.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		fails.append_array(res["fails"])
	for f: Variant in fails:
		printerr("COVERAGE FAIL: " + str(f))
	print("RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)
