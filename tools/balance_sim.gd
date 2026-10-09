## Headless balance simulator (GID-176 / TID-716): runs many seeded real-time
## fights with `BalanceBot` through the game's own rules (`BalanceFight`) and
## prints one summary row per case, plus a per-fight CSV.
##
##   godot --headless --path . -s tools/balance_sim.gd -- [options]
##
##   --fights N          fights per case (200)
##   --seed S            first seed; fight i uses S + i (1)
##   --level L           player level (1)
##   --learned MODE      ladder (rows with level_req <= L, default) | all | none | id,id,…
##   --deck MODE         starter (default: new-game deck + Strike) | id,id,…
##   --skills id,id,…    unlocked skill-tree nodes (card modifiers, GID-179; none)
##   --weapon ID / --offhand ID
##   --enemy T[,T…]      enemy types, or "all" (undead_basic)
##   --enemy-level N     enemy zone level (default: the type's own tier level)
##   --enemy-offset D    enemy level = player level + D (overrides --enemy-level)
##   --boss              fight it as a boss (tier 4, boss HP)
##   --tune k=v,k=v      CombatTuning overrides (clamped to each knob's range)
##   --policy k=v,…      BalanceBot knobs: heal_below, summon, interrupt, focus
##   --sweep key=v1,v2   one case per value; key = level | enemy_level | a tuning knob | a policy knob
##   --csv PATH          per-fight CSV (default user://balance/<time>.csv; "none" to skip)
##   --max-seconds S     per-fight cap, counted as a timeout (300)
##   --write-baseline    measure the CI balance bands (BalanceBands) and rewrite
##                       tests/data/balance_baseline.json; commit the diff
##
## It measures a fixed bot, not a skilled human: compare settings against
## each other. See docs/agent/balance-sim.md.
extends SceneTree

var _opts: Dictionary = {
	"fights": "200", "seed": "1", "level": "1", "learned": "ladder", "deck": "starter", "weapon": "",
	"offhand": "", "enemy": "undead_basic", "enemy-level": "", "enemy-offset": "", "boss": "", "tune": "", "policy": "",
	"sweep": "", "csv": "", "max-seconds": "300", "skills": "",
}

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			var key: String = a.substr(2)
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				_opts[key] = args[i + 1]
				i += 1
			else:
				_opts[key] = "1"
		i += 1
	_go.call_deferred()

func _go() -> void:
	if _opts.has("write-baseline"):
		_write_baseline()
		return
	var fight: GDScript = load("res://game_logic/battle/BalanceFight.gd")
	var stats: GDScript = load("res://game_logic/battle/BalanceStats.gd")
	var registry: GDScript = load("res://autoloads/EnemyRegistry.gd")
	var enemies: Array[String] = []
	if str(_opts["enemy"]) == "all":
		enemies.assign(registry.call("get_all_enemy_ids"))
	else:
		enemies.assign(str(_opts["enemy"]).split(",", false))
	var known: Array = registry.call("get_all_enemy_ids")
	for e: String in enemies:
		if not known.has(e):
			printerr("Unknown enemy type '%s'. Known: %s" % [e, ", ".join(PackedStringArray(known))])
			quit(1)
			return
	var sweep_key: String = ""
	var sweep_vals: PackedStringArray = [""]
	if str(_opts["sweep"]) != "":
		var parts: PackedStringArray = str(_opts["sweep"]).split("=")
		sweep_key = parts[0]
		sweep_vals = parts[1].split(",", false)
	var csv: FileAccess = _open_csv(stats)
	var n: int = int(_opts["fights"])
	var base_seed: int = int(_opts["seed"])
	var t0: int = Time.get_ticks_msec()
	var total: int = 0
	print(stats.call("table_header"))
	for enemy: String in enemies:
		for v: String in sweep_vals:
			var cfg: Dictionary = _config(enemy, sweep_key, v)
			var policy: Dictionary = _kv(str(_opts["policy"]))
			if sweep_key in ["heal_below", "summon", "interrupt", "focus"]:
				policy[sweep_key] = float(v)
			var label: String = enemy + ("" if sweep_key == "" else " %s=%s" % [sweep_key, v])
			var results: Array[Dictionary] = []
			for f: int in n:
				cfg["seed"] = base_seed + f
				var r: Dictionary = fight.call("run", cfg, policy)
				results.append(r)
				if csv != null:
					csv.store_line(str(stats.call("csv_row", label, base_seed + f, r)))
			total += n
			print(stats.call("table_row", label, stats.call("summarize", results)))
	var ms: int = maxi(1, Time.get_ticks_msec() - t0)
	print("%d fights in %.1f s (%.0f fights/s)%s" % [total, ms / 1000.0, total * 1000.0 / ms,
		"" if csv == null else "  csv: " + ProjectSettings.globalize_path(csv.get_path())])
	quit(0)

## Measures BalanceBands and writes the baseline JSON (with the commit it came from).
func _write_baseline() -> void:
	var bands: GDScript = load("res://game_logic/battle/BalanceBands.gd")
	var cells: Dictionary = bands.call("measure")
	var git: Array = []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], git)
	var commit: String = str(git[0]).strip_edges() if not git.is_empty() else "unknown"
	var data: Dictionary = {"measured_at": commit, "cells": cells}
	var path: String = str(bands.get("BASELINE_PATH"))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("Cannot write " + path)
		quit(1)
		return
	f.store_string(JSON.stringify(data, "\t", true) + "\n")
	f.close()
	var fails: Array = bands.call("check", cells, {})
	for msg: Variant in fails:
		printerr("Target missed: " + str(msg))
	print("Wrote %s (%d cells, at %s)" % [ProjectSettings.globalize_path(path), cells.size(), commit])
	quit(0)

## The BalanceFight config for one case.
func _config(enemy: String, sweep_key: String, v: String) -> Dictionary:
	var level: int = int(_opts["level"])
	if sweep_key == "level":
		level = int(v)
	var cfg: Dictionary = {"player_level": level, "enemy_type": enemy, "learned": _learned(level),
		"max_seconds": float(_opts["max-seconds"]), "is_boss": str(_opts["boss"]) != ""}
	if str(_opts["skills"]) != "":
		cfg["skills"] = Array(str(_opts["skills"]).split(",", false))
	if str(_opts["deck"]) != "starter":
		cfg["deck"] = Array(str(_opts["deck"]).split(",", false))
	for k: String in ["weapon", "offhand"]:
		if str(_opts[k]) != "":
			cfg[k] = str(_opts[k])
	if str(_opts["enemy-level"]) != "":
		cfg["enemy_level"] = int(_opts["enemy-level"])
	if str(_opts["enemy-offset"]) != "":
		cfg["enemy_level"] = maxi(1, level + int(_opts["enemy-offset"]))
	if sweep_key == "enemy_level":
		cfg["enemy_level"] = int(v)
	var tune: Dictionary = _kv(str(_opts["tune"]))
	var knobs: GDScript = load("res://game_logic/battle/CombatTuning.gd")
	if sweep_key != "" and (knobs.call("row_for", sweep_key) as Array).size() > 0:
		tune[sweep_key] = float(v)
	cfg["tuning"] = tune
	return cfg

## Ladder ids the player knows: by level (default), all, none or an explicit list.
func _learned(level: int) -> Array:
	var ladder: GDScript = load("res://game_logic/progression/UnlockLadder.gd")
	var mode: String = str(_opts["learned"])
	var out: Array = []
	match mode:
		"none":
			pass
		"all":
			out.assign(ladder.call("all_ids"))
		"ladder":
			for id: Variant in ladder.call("all_ids"):
				if int(ladder.call("level_req", str(id))) <= level:
					out.append(str(id))
		_:
			out.assign(mode.split(",", false))
	return out

## "a=1,b=2" → {a: 1.0, b: 2.0}.
func _kv(s: String) -> Dictionary:
	var out: Dictionary = {}
	for pair: String in s.split(",", false):
		var kv: PackedStringArray = pair.split("=")
		if kv.size() == 2:
			out[kv[0]] = float(kv[1])
	return out

func _open_csv(stats: GDScript) -> FileAccess:
	var path: String = str(_opts["csv"])
	if path == "none":
		return null
	if path == "":
		DirAccess.make_dir_recursive_absolute("user://balance")
		path = "user://balance/%s.csv" % Time.get_datetime_string_from_system().replace(":", "-")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_line(str(stats.get("CSV_HEADER")))
	return f
