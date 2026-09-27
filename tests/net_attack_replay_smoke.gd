## Headless smoke test: remote attacks replay on this screen (GID-135).
##
## A real BattleScene receives an authority state mirror whose `fx` says the
## opponent's minion hit our hero. Before adopting the state, the attacker's
## panel must lunge (a ghost appears on the float layer); after, the hero HP
## matches the mirror and a damage number floats — with no SCRIPT ERROR.
##
##   godot --headless --path . -s tests/net_attack_replay_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _GameState = preload("res://game_logic/battle/GameState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _Proto = preload("res://game_logic/net/BattleNetProtocol.gd")

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var fails: Array[String] = await _run()
	for f: String in fails:
		print("  [FAIL] " + f)
	print("\nnet_attack_replay_smoke: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)

func _run() -> Array[String]:
	var fails: Array[String] = []
	var save_manager: Object = root.get_node("SceneManager").get("save_manager")
	save_manager.call("set_setting", "battle_mode", "turn")
	var battle: Node = (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	battle.set("enemy_data", {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "ghost", "ghost", "ghost", "ghost"]})
	root.add_child(battle)
	await process_frame
	await process_frame
	var state: _GameState = battle.get("_state")
	var foe := _CardInstance.new({"id": "replay_foe", "name": "Replay Foe", "cost": 1, "attack": 3,
		"health": 5, "card_class": "minion", "description": ""})
	state.players[1].board.add_card_at_slot(foe, 0)
	battle.call("_refresh_all")
	await process_frame
	var hp: int = state.players[0].hero.health
	state.players[0].hero.take_damage(3)
	var after: Dictionary = state.to_dict()
	state.players[0].hero.health = hp  # this screen hasn't seen the hit yet
	var layer: CanvasLayer = battle.get("_float_layer") as CanvasLayer
	var before_ghosts: int = _count_panels(layer)
	var fx: Array = [_Proto.encode_attack_fx(1, 0, 0, _Proto.TARGET_HERO)]
	var net: Node = battle.get("battle_net") as Node
	var adopted: bool = bool(net.call("_accept_state_mirror", _Proto.encode_state(after, 999, fx)))
	if not adopted:
		fails.append("mirror was not adopted")
	if _count_panels(layer) <= before_ghosts:
		fails.append("no lunge ghost appeared for the remote attack")
	var new_state: _GameState = battle.get("_state")
	if new_state.players[0].hero.health != hp - 3:
		fails.append("hero HP %d, expected %d" % [new_state.players[0].hero.health, hp - 3])
	for _i in range(40):
		await process_frame
	return fails

func _count_panels(layer: CanvasLayer) -> int:
	var n: int = 0
	for c in layer.get_children():
		if c is PanelContainer:
			n += 1
	return n
