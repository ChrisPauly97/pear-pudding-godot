## Headless smoke test for the real-time battle prototype (GID-135 / TID-546).
##
## Standalone (like coop_pve_ai_turn_smoke.gd): it instantiates a real
## BattleScene.tscn with Settings > Battle Mode = Real-time and lets the clock
## run, proving the module starts, hides End Turn, the enemy telegraphs and
## plays units, and swings land — without any SCRIPT ERROR.
##
##   godot --headless --path . -s tests/realtime_battle_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _BATTLE_SCENE_PATH: String = "res://scenes/battle/BattleScene.tscn"
const _GameState = preload("res://game_logic/battle/GameState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _ENEMY_DECK: Array[String] = ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton",
	"ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton"]
const _MAX_WAIT_MS: int = 20000

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = await _run()
	print("\nrealtime_battle_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

func _run() -> bool:
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	if scene_manager == null:
		print("  [FAIL] SceneManager autoload not found")
		return false
	var save_manager: Object = scene_manager.get("save_manager")
	save_manager.call("set_setting", "battle_mode", "realtime")
	save_manager.call("set_setting", "auto_skip_gambits", true)
	Engine.time_scale = 4.0

	var packed: PackedScene = load(_BATTLE_SCENE_PATH)
	var battle: Node = packed.instantiate()
	battle.name = "BattleScene"
	battle.set("enemy_data", {"enemy_type": "undead_basic", "is_boss": false, "enemy_deck": _ENEMY_DECK})
	root.add_child(battle)
	await process_frame
	await process_frame

	var rt_mod: Node = battle.get("realtime")
	if rt_mod == null or not bool(rt_mod.call("is_active")):
		print("  [FAIL] real-time module did not start")
		return false
	var fails: Array[String] = []
	# Any tutorial popup must freeze the clock; then dismiss them like the player would.
	var modal_up: bool = battle.get("_tutorial_overlay") != null or not get_nodes_in_group("modal_popup").is_empty()
	if modal_up and not bool(rt_mod.call("is_blocked")):
		fails.append("clock kept running under a tutorial popup")
	_dismiss_popups(battle)
	var end_btn: Button = battle.get_node("SidePanel/EndTurnButton") as Button
	if end_btn.visible:
		fails.append("End Turn button should be hidden in real time")
	var state: _GameState = battle.get("_state")
	var player_hp: int = state.players[0].hero.health
	var start_ms: int = Time.get_ticks_msec()
	var enemy_played: bool = false
	var player_hit: bool = false
	while Time.get_ticks_msec() - start_ms < _MAX_WAIT_MS:
		await process_frame
		_dismiss_popups(battle)
		enemy_played = enemy_played or not state.players[1].board.get_cards().is_empty()
		player_hit = state.players[0].hero.health < player_hp
		if (enemy_played and player_hit) or state.is_game_over():
			break
	Engine.time_scale = 1.0
	if state.current_player_idx != 0:
		fails.append("current_player_idx left the player (%d)" % state.current_player_idx)
	if not enemy_played:
		fails.append("enemy never played a unit")
	if not player_hit:
		fails.append("no enemy swing reached the player hero")
	if not state.is_game_over():
		await _check_commanded_attack(battle, state, fails)
	for f: String in fails:
		print("  [FAIL] " + f)
	if fails.is_empty():
		print("  [PASS] enemy cast units and swings landed (player HP %d -> %d)" % [
			player_hp, state.players[0].hero.health])
	battle.queue_free()
	await process_frame
	return fails.is_empty()

func _dismiss_popups(battle: Node) -> void:
	var tip: Variant = battle.get("_tutorial_overlay")
	if tip != null and is_instance_valid(tip):
		(tip as Node).free()
		battle.set("_tutorial_overlay", null)
	for n: Node in get_nodes_in_group("modal_popup"):
		n.free()

## A ready Ally attacks on command even while the player is on global cooldown.
func _check_commanded_attack(battle: Node, state: _GameState, fails: Array[String]) -> void:
	var ally := _CardInstance.new({"id": "smoke_ally", "name": "Smoke Ally", "cost": 1, "attack": 3,
		"health": 20, "card_class": "minion", "description": ""})
	ally.summoning_sick = false
	var mine: Array = state.players[0].board.slots
	var free_slot: int = mine.find(null)
	if free_slot < 0:
		return
	state.players[0].board.add_card_at_slot(ally, free_slot)
	var rt: Object = (battle.get("realtime") as Node).get("rt")
	rt.call("start_gcd", 0)
	for c: _CardInstance in state.players[1].board.get_cards():
		state.players[1].board.remove_card(c)  # clear Wards so the hero is a legal target
	var hp: int = state.players[1].hero.health
	(battle.get("card_input") as Node).call("_attempt_attack", ally, null)
	for _i in range(90):
		await process_frame
	if ally.attack_count != 0 or state.players[1].hero.health > hp - 3:
		fails.append("commanded Ally attack did not land during the global cooldown")
