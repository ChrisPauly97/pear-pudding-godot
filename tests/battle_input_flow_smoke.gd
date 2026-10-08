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
	# Free cards (0-cost technique cards such as Strike, GID-175) stay playable at 0 mana: drop them.
	var hand: Array = me.get("hand")
	for c: Object in hand.duplicate():
		if int(c.get("cost")) <= 0:
			hand.erase(c)
	var board: Object = me.get("board")
	for c: Object in (board.call("get_cards") as Array):
		c.set("attack_count", 0)
	battle.set("_hero_power_used", true)
	var turn_at: int = int(state.get("turn_number"))
	battle.call("_refresh_all")
	await _wait(2500)
	if int(state.get("turn_number")) == turn_at:
		fails.append("turn did not end by itself with nothing playable")
	await _check_pack_on_board(sm, fails)
	await _check_enemy_spells(sm, save_manager, fails)
	return fails

## BID-078: a turn-based enemy whose deck is all damage spells actually hurts you.
func _check_enemy_spells(sm: Node, save_manager: Object, fails: Array[String]) -> void:
	sm.call("_finish_battle")
	sm.call("_restore_world")
	await _wait(900)
	save_manager.call("set_setting", "auto_end_turn", false)
	sm.call("_start_battle", {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["shadow_bolt", "shadow_bolt", "shadow_bolt", "shadow_bolt", "shadow_bolt", "shadow_bolt"]})
	await _wait(1500)
	var st: Object = current_scene.get("_state")
	if st == null:
		fails.append("spell-deck battle did not start")
		return
	await _wait_for_my_turn(st)
	var me: Object = (st.get("players") as Array)[0]
	var hp_before: int = int((me.get("hero") as Object).get("health"))
	var hp_after: int = hp_before
	for _round in range(3):  # the enemy needs 2 mana for a bolt
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = true
		root.push_input(space)
		await _wait(400)
		await _wait_for_my_turn(st)
		hp_after = int((me.get("hero") as Object).get("health"))
		if hp_after < hp_before:
			break
	if hp_after >= hp_before:
		fails.append("an all-spell enemy did no damage on its turn (%d -> %d)" % [hp_before, hp_after])

## TID-541: a pack enemy's pack is already on the enemy board when the fight opens.
func _check_pack_on_board(sm: Node, fails: Array[String]) -> void:
	sm.call("_finish_battle")
	sm.call("_restore_world")
	await _wait(900)
	sm.call("_start_battle", {"enemy_type": "ghoul_pack", "is_boss": false,
		"enemy_deck": ["ghoul", "ghoul", "zombie", "zombie", "skeleton", "skeleton"]})
	await _wait(1500)
	var st: Object = current_scene.get("_state")
	if st == null:
		fails.append("pack battle did not start")
		return
	var enemy: Object = (st.get("players") as Array)[1]
	var units: Array = (enemy.get("board") as Object).call("get_cards")
	if units.size() < 3:
		fails.append("ghoul pack should start with its 3 units on the board (got %d)" % units.size())

func _wait_for_my_turn(state: Object) -> void:
	for _i in range(100):
		if int(state.get("current_player_idx")) == 0 and not bool(current_scene.get("_ai_thinking")) \
				and not bool(current_scene.get("_action_busy")):
			return
		await _wait(100)
