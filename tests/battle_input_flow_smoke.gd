## Headless smoke test for the turn-based input flow (GID-135 / TID-530):
## Space ends the turn, and with nothing left to play the turn ends by itself.
##
##   godot --headless --path . -s tests/battle_input_flow_smoke.gd
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
	print("\nbattle_input_flow_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
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
	save_manager.call("set_setting", "battle_mode", "turn")
	save_manager.call("set_setting", "auto_skip_gambits", true)
	save_manager.call("set_story_flag", "seen_tutorial_tap_and_hold")
	save_manager.call("set_story_flag", "tutorial_battle_tip")
	var ws: Node = (load(_WORLD_SCENE_PATH) as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	sm.call("_transition_to", _SceneFlow.State.WORLD)
	await _wait(300)
	sm.call("_start_battle", {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "skeleton", "skeleton", "ghost", "ghost"]})
	await _wait(1500)
	var battle: Node = current_scene
	var state: Object = battle.get("_state") if battle != null else null
	if state == null:
		fails.append("no turn-based battle started")
		return fails
	save_manager.call("set_setting", "auto_end_turn", false)
	await _wait_for_my_turn(state)
	var turn_before: int = int(state.get("turn_number"))
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	await _wait(300)
	if int(state.get("turn_number")) == turn_before:
		fails.append("Space did not end the turn")
	# Auto end turn: on our next turn, strip every move and wait.
	save_manager.call("set_setting", "auto_end_turn", true)
	await _wait_for_my_turn(state)
	var me: Object = (state.get("players") as Array)[0]
	(me.get("hero") as Object).set("mana", 0)
	var board: Object = me.get("board")
	for c: Object in (board.call("get_cards") as Array):
		c.set("attack_count", 0)
	battle.set("_hero_power_used", true)
	var turn_at: int = int(state.get("turn_number"))
	battle.call("_refresh_all")
	await _wait(2500)
	if int(state.get("turn_number")) == turn_at:
		fails.append("turn did not end by itself with nothing playable")
	return fails

func _wait_for_my_turn(state: Object) -> void:
	for _i in range(100):
		if int(state.get("current_player_idx")) == 0 and not bool(current_scene.get("_ai_thinking")) \
				and not bool(current_scene.get("_action_busy")):
			return
		await _wait(100)
