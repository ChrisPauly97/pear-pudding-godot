## Headless smoke test for fighting in place (GID-135 / TID-528).
##
## With Battle Mode = Real-time, a solo battle opens over the live WorldScene:
## the world stays in the tree but frozen, its CanvasLayers (HUD) hide, the
## camera pushes in, and the battle overlay becomes current_scene. Leaving the
## battle thaws the world, restores the HUD and zooms back out — no wipe.
##
##   godot --headless --path . -s tests/in_world_battle_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _WORLD_SCENE_PATH: String = "res://scenes/world/WorldScene.tscn"
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var fails: Array[String] = await _run()
	for f: String in fails:
		print("  [FAIL] " + f)
	print("\nin_world_battle_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)

func _wait(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _run() -> Array[String]:
	var fails: Array[String] = []
	var sm: Node = root.get_node_or_null("SceneManager")
	var save_manager: Object = sm.get("save_manager")
	save_manager.call("new_game", 1)
	save_manager.call("set_setting", "battle_mode", "realtime")
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	sm.call("_transition_to", _SceneFlow.State.WORLD)
	await _wait(300)
	var cam: Camera3D = ws.get("_camera") as Camera3D
	var hud: CanvasLayer = ws.get_node_or_null("HUD") as CanvasLayer
	var cam_size: float = cam.size

	# Stand-in for the engaged EnemyNPC: it must stay visible during the fight.
	# Real order: engage emits → the battle can start synchronously (gambits
	# auto-skipped) → only then does the enemy call free_after_battle.
	var enemy := Node3D.new()
	ws.add_child(enemy)
	sm.call("_start_battle", {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "skeleton", "skeleton", "ghost", "ghost"]})
	sm.call("free_after_battle", enemy)
	await _wait(600)
	var battle: Node = current_scene
	if not ws.is_inside_tree():
		fails.append("world was detached instead of fought in place")
	if ws.process_mode != Node.PROCESS_MODE_DISABLED:
		fails.append("world not frozen during the battle")
	if battle == ws or battle == null or not bool(battle.get("in_world")):
		fails.append("battle overlay is not the in-world current scene")
	if hud != null and hud.visible:
		fails.append("world HUD still visible over the battle")
	if not is_instance_valid(enemy):
		fails.append("engaged enemy vanished when the in-world battle started")
	if not (cam.size < cam_size * 0.9):
		fails.append("camera did not push in (%.2f -> %.2f)" % [cam_size, cam.size])

	sm.call("_finish_battle")
	sm.call("_restore_world")
	await _wait(600)
	if current_scene != ws:
		fails.append("world is not current_scene after the battle")
	if ws.process_mode != Node.PROCESS_MODE_INHERIT:
		fails.append("world still frozen after the battle")
	if hud != null and not hud.visible:
		fails.append("world HUD not restored")
	if absf(cam.size - cam_size) > 0.01:
		fails.append("camera did not zoom back out (%.2f vs %.2f)" % [cam.size, cam_size])
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		fails.append("engaged enemy not removed after the battle")
	if int(sm.call("current_state")) != _SceneFlow.State.WORLD:
		fails.append("SceneManager not back in WORLD state")
	await _check_double_engage(sm, save_manager, fails)
	await _check_add_joins(sm, save_manager, fails)
	return fails

## TID-551: a second enemy engaging mid-fight joins it; beating both through the
## real victory screen returns to the world and marks both defeated.
func _check_add_joins(sm: Node, save_manager: Object, fails: Array[String]) -> void:
	var data := {"id": "smoke_main", "enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "skeleton", "skeleton", "ghost", "ghost"]}
	sm.call("_on_enemy_engaged", data.duplicate())
	await _wait(500)
	var battle: Node = current_scene
	if not bool(sm.call("accepts_engage")):
		fails.append("a real-time fight did not accept an add")
		return
	var add := data.duplicate()
	add["id"] = "smoke_add"
	sm.call("_on_enemy_engaged", add)
	await _wait(300)
	var state: Object = battle.get("_state")
	var players: Array = state.get("players")
	if players.size() != 3:
		fails.append("the add did not join (players=%d)" % players.size())
		return
	var rt_mod: Node = battle.get("realtime")
	var visuals: Object = rt_mod.get("_visuals")
	var rows: Dictionary = visuals.get("add_rows")
	if not rows.has(2):
		fails.append("no row / token built for the add")
	for i in [1, 2]:
		var hero: Object = (players[i] as Object).get("hero")
		hero.set("health", 0)
	battle.call("_check_game_over")
	for _i in range(8):
		await _wait(500)
		for n: Node in root.find_children("*", "Button", true, false):
			var b := n as Button
			if b.is_visible_in_tree() and b.text in ["Continue", "Collect", "Collect All"]:
				b.pressed.emit()
		if int(sm.call("current_state")) == _SceneFlow.State.WORLD:
			break
	await _wait(400)
	if int(sm.call("current_state")) != _SceneFlow.State.WORLD or current_scene.get("_camera") == null:
		fails.append("did not return to the world after beating both enemies")
	var defeated: Array = save_manager.get("defeated_enemies")
	if not defeated.has("smoke_main") or not defeated.has("smoke_add"):
		fails.append("both enemies should be marked defeated (got %s)" % str(defeated))

## Two enemies engaging back to back with the gambit picker on must give ONE
## picker and one battle — never a battle stacked on a battle.
func _check_double_engage(sm: Node, save_manager: Object, fails: Array[String]) -> void:
	save_manager.call("set_setting", "auto_skip_gambits", false)
	var data := {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "skeleton", "skeleton", "ghost", "ghost"]}
	sm.call("_on_enemy_engaged", data.duplicate())
	if bool(sm.call("accepts_engage")):
		fails.append("engage still accepted while the gambit picker is open")
	sm.call("_on_enemy_engaged", data.duplicate())
	await process_frame
	var pickers: int = 0
	for n: Node in root.get_children():
		if n is CanvasLayer and n.get_child_count() > 0 and n.get_child(0).has_signal("gambit_chosen"):
			pickers += 1
	if pickers != 1:
		fails.append("expected 1 gambit picker after two engages, got %d" % pickers)
	for n: Node in root.get_children():
		if n is CanvasLayer and n.get_child_count() > 0 and n.get_child(0).has_signal("gambit_chosen"):
			n.get_child(0).emit_signal("gambit_chosen", "")
	await _wait(600)
	sm.call("_finish_battle")
	sm.call("_restore_world")
	await _wait(600)
	if int(sm.call("current_state")) != _SceneFlow.State.WORLD or current_scene.get("_camera") == null:
		fails.append("did not return to the world after the double-engage fight")
	save_manager.call("set_setting", "auto_skip_gambits", true)
