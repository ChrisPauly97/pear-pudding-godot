## Headless smoke test for swimming (GID-172): in a real WorldScene, deep river water switches
## the hero to swimming (the Coastline module), the current carries them, and running out of
## stamina washes them up on the nearest shore at 1 HP.
##
##   godot --headless --path . -s tests/swim_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _WORLD_SCENE_PATH: String = "res://scenes/world/WorldScene.tscn"
const _Rivers = preload("res://game_logic/world/Rivers.gd")
const _Swimming = preload("res://game_logic/world/Swimming.gd")
const IsoConst = preload("res://autoloads/IsoConst.gd")
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var fails: Array[String] = await _run()
	for f: String in fails:
		print("  [FAIL] " + f)
	print("\nswim_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)


func _wait(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await physics_frame


func _run() -> Array[String]:
	var fails: Array[String] = []
	var sm: Node = root.get_node_or_null("SceneManager")
	var save: Object = sm.get("save_manager")
	save.call("new_game", 1)
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	sm.call("_transition_to", _SceneFlow.State.WORLD)
	await _wait(1500)
	var player: Node3D = ws.get("_player")
	var coast: Node = ws.get("coastline")
	if player == null or coast == null:
		return ["no player / coastline module"]
	# Into the deep, flowing lower west river.
	var line: PackedVector2Array = _Rivers.centreline(1)
	var spot := Vector2.INF
	for k: int in range(line.size() / 2, line.size()):
		var q: Vector2 = line[k]
		if _Rivers.deep_water(floori(q.x), floori(q.y)) and _Rivers.depth(q.x, q.y) > 2.5:
			spot = q
			break
	if spot == Vector2.INF:
		return ["no deep stretch on the west river"]
	var ts: float = IsoConst.TILE_SIZE
	player.global_position = Vector3(spot.x * ts, 0.5, spot.y * ts)
	await _wait(300)
	var t: Vector2i = IsoConst.world_to_tile(player.global_position.x, player.global_position.z)
	if not _Rivers.deep_water(t.x, t.y):
		fails.append("test spot %s is not deep water" % str(t))
	if not bool(player.get("swimming")):
		fails.append("the hero is not swimming in deep river water")
	var push: Vector3 = player.get("current_push")
	if push.length() < 0.1:
		fails.append("no river current on the swimmer")
	if float(coast.get("stamina")) >= 1.0:
		fails.append("swimming did not drain stamina")
	# Exhausted: washes up ashore at 1 HP.
	save.set("hero_hp_frac", 1.0)
	coast.set("stamina", 0.001)
	await _wait(1500)
	t = IsoConst.world_to_tile(player.global_position.x, player.global_position.z)
	if bool(player.get("swimming")):
		fails.append("still swimming after exhaustion")
	if _Rivers.tile_depth(t.x, t.y) > -1.0:
		fails.append("washed up at %s, which is not dry land (depth %.1f)" % [str(t), _Rivers.tile_depth(t.x, t.y)])
	if Vector2(t).distance_to(spot) > 12.0:
		fails.append("washed up far from the river (%s)" % str(t))
	# 1 HP (WASHED_UP_FRAC), plus the second or so of out-of-combat regen since.
	if float(save.get("hero_hp_frac")) > _Swimming.WASHED_UP_FRAC + 0.03:
		fails.append("hero HP after washing up is %.3f, not ~1 HP" % float(save.get("hero_hp_frac")))
	if float(coast.get("stamina")) < 0.99:
		fails.append("stamina not refilled after washing up")
	return fails
