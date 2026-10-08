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
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _ENEMY_DECK: Array[String] = ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton",
	"ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton"]
const _MAX_WAIT_MS: int = 20000

func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = await _run()
	ok = await _run_onboarding() and ok
	ok = await _run_mentor_barks_scenario() and ok
	ok = await _run_leaderless_pack() and ok
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
	save_manager.set("realtime_fights", 99)  # past the onboarding ramp; checked separately below
	# GID-141: Mend / Kick are trainer-taught; this player has learned them (and the hand).
	(save_manager.get("learned_abilities") as Array).append_array(
			["mend", "kick", "feat_minions", "feat_spells", "feat_companion"])
	for tip: String in ["rt_intro", "rt_skill_mend", "rt_skill_kick", "rt_cards", "rt_low_hp", "rt_enemy_cast",
			"rt_out_of_mana", "rt_ally", "rt_add"]:
		save_manager.call("set_story_flag", "seen_tutorial_" + tip)
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
	_check_diagonal_layout(battle, fails)
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
	if not state.is_game_over():
		await _check_cast_time(battle, fails)
	if not state.is_game_over():
		await _check_spell_queue(battle, fails)
	if not state.is_game_over():
		await _check_skill_bar(battle, state, fails)
	if not state.is_game_over():
		await _check_tuning_panel(battle, fails)
	if not state.is_game_over():
		_check_enemy_spell(battle, state, fails)
	for f: String in fails:
		print("  [FAIL] " + f)
	if fails.is_empty():
		print("  [PASS] enemy cast units and swings landed (player HP %d -> %d)" % [
			player_hp, state.players[0].hero.health])
	battle.queue_free()
	await process_frame
	return fails.is_empty()

## New player's first real-time fight (TID-552 / TID-553): Strike only, no
## hand, and the intro tip is up (clock paused) until it's dismissed.
func _run_onboarding() -> bool:
	var save_manager: Object = root.get_node("SceneManager").get("save_manager")
	save_manager.set("realtime_fights", 0)
	save_manager.set("level", 1)
	# A fresh player: nothing learned from a trainer yet (GID-141).
	var learned: Array = save_manager.get("learned_abilities")
	var kept: Array = learned.duplicate()
	learned.clear()
	(save_manager.get("story_flags") as Dictionary).erase("seen_tutorial_rt_intro")
	var battle: Node = (load(_BATTLE_SCENE_PATH) as PackedScene).instantiate()
	battle.set("enemy_data", {"enemy_type": "undead_basic", "is_boss": false, "enemy_deck": _ENEMY_DECK})
	root.add_child(battle)
	await process_frame
	await process_frame
	var fails: Array[String] = []
	var rt_mod: Node = battle.get("realtime")
	if rt_mod.get("skills") != null:
		fails.append("the fixed skill bar is gone (GID-175)")
	# GID-175: no Allies / spells learned → the hand is shown but holds only technique cards.
	if not (battle.get("_player_hand_view") as Control).visible:
		fails.append("first fight should show the (technique-only) hand")
	var first_state: _GameState = battle.get("_state")
	for c: _CardInstance in first_state.players[0].hand + first_state.players[0].draw_deck:
		if not c.template_id.begins_with("tech_"):
			fails.append("first fight dealt a non-technique card: %s" % c.template_id)
	if int(save_manager.get("realtime_fights")) != 1:
		fails.append("fight was not counted towards the ramp")
	if not bool(save_manager.call("get_story_flag", "seen_tutorial_rt_intro")):
		fails.append("intro tip was not shown")
	if not bool(rt_mod.call("is_blocked")):
		fails.append("clock should pause under the intro tip")
	_dismiss_popups(battle)
	if bool(rt_mod.call("is_blocked")):
		fails.append("clock still paused after the tip was dismissed")
	for f: String in fails:
		print("  [FAIL] onboarding: " + f)
	if fails.is_empty():
		print("  [PASS] onboarding: first fight is Strike-only with the intro tip")
	learned.append_array(kept)
	battle.queue_free()
	await process_frame
	return fails.is_empty()

## GID-135 / TID-558: Maiteln equipped + still on the onboarding ramp should
## build mentor_barks and run a fight without a SCRIPT ERROR.
func _run_mentor_barks_scenario() -> bool:
	var save_manager: Object = root.get_node("SceneManager").get("save_manager")
	save_manager.set("active_companion", "maiteln")
	save_manager.set("realtime_fights", 0)
	save_manager.set("level", 1)
	Engine.time_scale = 4.0

	var battle: Node = (load(_BATTLE_SCENE_PATH) as PackedScene).instantiate()
	battle.set("enemy_data", {"enemy_type": "undead_basic", "is_boss": false, "enemy_deck": _ENEMY_DECK})
	root.add_child(battle)
	await process_frame
	await process_frame

	var fails: Array[String] = []
	var rt_mod: Node = battle.get("realtime")
	if rt_mod == null or not bool(rt_mod.call("is_active")):
		fails.append("real-time module did not start")
	elif rt_mod.get("mentor_barks") == null:
		fails.append("mentor_barks was not built for an eligible Maiteln fight")
	_dismiss_popups(battle)
	var state: _GameState = battle.get("_state")
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < _MAX_WAIT_MS and not state.is_game_over():
		await process_frame
		_dismiss_popups(battle)
	Engine.time_scale = 1.0
	for f: String in fails:
		print("  [FAIL] mentor_barks: " + f)
	if fails.is_empty():
		print("  [PASS] mentor_barks: ran the length of a fight cleanly")
	battle.queue_free()
	await process_frame
	save_manager.set("active_companion", "")
	return fails.is_empty()

## BID-077: the Horde Shambler is a leaderless pack — its pack starts on the board,
## the hidden hero can't be hit, and clearing the board ends the fight in a win.
func _run_leaderless_pack() -> bool:
	var battle: Node = (load(_BATTLE_SCENE_PATH) as PackedScene).instantiate()
	battle.set("enemy_data", {"enemy_type": "undead_horde", "is_boss": false, "enemy_deck": _ENEMY_DECK})
	root.add_child(battle)
	await process_frame
	await process_frame
	_dismiss_popups(battle)
	var fails: Array[String] = []
	var state: _GameState = battle.get("_state")
	var enemy: _PlayerState = state.players[1]
	if not enemy.hero.leaderless:
		fails.append("undead_horde's hero is not leaderless")
	if enemy.board.get_cards().is_empty():
		fails.append("the horde's pack did not start on the board")
	var hp: int = enemy.hero.health
	enemy.hero.take_damage(99)
	if enemy.hero.health != hp:
		fails.append("the leaderless stand-in took damage")
	for c: _CardInstance in enemy.board.get_cards().duplicate():
		enemy.board.remove_card(c)
	await process_frame
	if not state.is_game_over() or state.winner() != 0:
		fails.append("clearing the pack's board did not win the fight")
	for f: String in fails:
		print("  [FAIL] leaderless pack: " + f)
	if fails.is_empty():
		print("  [PASS] leaderless pack: hero untouchable, board clear wins")
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
	# Put the enemy mid-cast: an Ally hitting the enemy hero must interrupt it.
	var foe_card := _CardInstance.new({"id": "smoke_cast", "name": "Smoke Cast", "cost": 1, "attack": 1,
		"health": 1, "card_class": "minion", "description": ""})
	state.players[1].hand.append(foe_card)
	rt.set("enemy_casting", foe_card)
	rt.set("enemy_cast_remaining", 5.0)
	(battle.get("card_input") as Node).call("_attempt_attack", ally, null)
	for _i in range(90):
		await process_frame
	if ally.attack_count != 0 or state.players[1].hero.health > hp - 3:
		fails.append("commanded Ally attack did not land during the global cooldown")
	if rt.get("enemy_casting") != null:
		fails.append("Ally hit on the enemy hero did not interrupt its cast")

## A 3-cost spell shows a cast bar: the play is deferred, then resolves.
func _check_cast_time(battle: Node, fails: Array[String]) -> void:
	var rt_mod: Node = battle.get("realtime") as Node
	var rt: Object = rt_mod.get("rt")
	for _i in range(200):  # let any running GCD / cast finish first
		if not bool(rt_mod.call("on_cooldown")):
			break
		await process_frame
	var spell := _CardInstance.new({"id": "smoke_bolt", "name": "Smoke Bolt", "cost": 3, "attack": 0,
		"health": 0, "card_class": "spell", "description": ""})
	var resolved: Array[bool] = [false]
	var deferred: bool = bool(rt_mod.call("run_cast", spell, func() -> void: resolved[0] = true))
	if not deferred or resolved[0] or not bool(rt_mod.call("on_cooldown")):
		fails.append("3-cost spell did not start a cast bar")
		return
	var t0: int = Time.get_ticks_msec()
	while not resolved[0] and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	if not resolved[0]:
		fails.append("cast never completed")
	if rt == null:
		fails.append("no RealtimeCombat")

## Spell queue (TID-555): an instant (0-cast-time) play attempted inside the
## queue-window tail of the GCD must wait for the GCD to actually end, not
## resolve early. `run_cast` is the shared path for a deck spell's instant play
## and the skill bar's instant on-GCD abilities (BattleSkillBar.press routes
## every non-off_gcd press through it), so this covers both.
func _check_spell_queue(battle: Node, fails: Array[String]) -> void:
	var rt_mod: Node = battle.get("realtime") as Node
	var rt: Object = rt_mod.get("rt")
	for _i in range(200):  # let any running GCD / cast finish first
		if not bool(rt_mod.call("on_cooldown")):
			break
		await process_frame
	rt.call("start_gcd", 0)
	var t0: int = Time.get_ticks_msec()
	while not bool(rt.call("in_queue_window", 0)) and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	if not bool(rt.call("in_queue_window", 0)):
		fails.append("spell queue: never entered the queue window")
		return
	var instant := _CardInstance.new({"id": "smoke_instant", "name": "Smoke Instant", "cost": 0, "attack": 0,
		"health": 0, "card_class": "spell", "description": ""})
	var resolved: Array[bool] = [false]
	var queued: bool = bool(rt_mod.call("run_cast", instant, func() -> void: resolved[0] = true))
	if not queued or resolved[0]:
		fails.append("spell queue: an instant play inside the window fired immediately instead of queuing")
	var t1: int = Time.get_ticks_msec()
	while not resolved[0] and Time.get_ticks_msec() - t1 < 8000:
		await process_frame
	if not resolved[0]:
		fails.append("spell queue: queued instant play never resolved")

## Technique cards (GID-175): Strike from the hand damages the enemy hero and
## starts the GCD, then recycles to the bottom of the deck; Mend runs its own
## 1.5 s cast bar and heals when it completes.
func _check_skill_bar(battle: Node, state: _GameState, fails: Array[String]) -> void:
	var rt_mod: Node = battle.get("realtime") as Node
	var input: Object = battle.get("card_input")
	var me: _PlayerState = state.players[0]
	for _i in range(200):
		if not bool(rt_mod.call("on_cooldown")):
			break
		await process_frame
	var hero: Object = me.hero
	hero.set("mana", int(hero.get("max_mana")))
	var enemy_hp: int = state.players[1].hero.health
	var strike := _CardInstance.new(CardRegistry.get_template("tech_strike"))
	me.hand.append(strike)
	battle.call("_refresh_all")
	var targeting: Object = battle.get("targeting")
	input.call("_on_hand_card_tap", strike)
	if me.hand.has(strike) and not bool(rt_mod.call("is_casting")):
		targeting.call("_on_target_chosen_hero", 1)
	var t_strike: int = Time.get_ticks_msec()
	while me.hand.has(strike) and Time.get_ticks_msec() - t_strike < 4000:
		await process_frame
	while bool(rt_mod.call("is_casting")) and Time.get_ticks_msec() - t_strike < 8000:
		await process_frame
	if state.players[1].hero.health >= enemy_hp and not state.is_game_over():
		fails.append("Strike did not damage the enemy hero")
	if not me.draw_deck.has(strike):
		fails.append("Strike did not recycle into the draw pile")
	elif me.draw_deck[0] != strike:
		fails.append("Strike should sit at the bottom of the draw pile")
	for _i in range(200):
		if not bool(rt_mod.call("on_cooldown")):
			break
		await process_frame
	hero.set("mana", int(hero.get("max_mana")))
	hero.set("health", 5)
	var mend := _CardInstance.new(CardRegistry.get_template("tech_mend"))
	me.hand.append(mend)
	battle.call("_refresh_all")
	input.call("_on_hand_card_tap", mend)
	var t_mend: int = Time.get_ticks_msec()
	while not bool(rt_mod.call("is_casting")) and me.hand.has(mend) and Time.get_ticks_msec() - t_mend < 4000:
		await process_frame
	if me.hand.has(mend) and not bool(rt_mod.call("is_casting")):
		fails.append("Mend did not start a cast")
	while bool(rt_mod.call("is_casting")) and Time.get_ticks_msec() - t_mend < 8000:
		await process_frame
	if me.hand.has(mend):
		fails.append("Mend never completed / healed")

## Hero strips live inside the tokens; each board row steps down-right.
func _check_diagonal_layout(battle: Node, fails: Array[String]) -> void:
	var hero: Node = battle.get("_player_hero_view")
	if hero.get_parent().name == "PlayerArea":
		fails.append("player hero strip was not moved into its token")
	for key: String in ["_player_board_view", "_enemy_board_view"]:
		var board: Control = battle.get(key) as Control
		var prev := Vector2(-INF, -INF)
		for child in board.get_children():
			var c := child as Control
			if c == null or not c.visible:
				continue
			if not (c.position.x > prev.x and c.position.y > prev.y):
				fails.append("%s slots are not on a top-left → bottom-right diagonal" % key)
				break
			prev = c.position

## The Tune panel pauses the clock, edits the live tuning and persists it.
func _check_tuning_panel(battle: Node, fails: Array[String]) -> void:
	var rt_mod: Node = battle.get("realtime") as Node
	rt_mod.call("open_tuning")
	await process_frame
	var panels: Array[Node] = get_nodes_in_group("modal_popup")
	if panels.is_empty() or not bool(rt_mod.call("is_blocked")):
		fails.append("tuning panel did not open / pause the clock")
		return
	var tune: Object = (rt_mod.get("rt") as Object).get("tune")
	var before: float = float(tune.call("get_f", "player_gcd"))
	panels[0].call("_nudge", "player_gcd", 1)
	if not float(tune.call("get_f", "player_gcd")) > before:
		fails.append("tuning panel nudge did not change the live value")
	var save_manager: Object = root.get_node("SceneManager").get("save_manager")
	var saved: Dictionary = save_manager.call("get_setting", "combat_tuning", {})
	if not saved.has("player_gcd"):
		fails.append("tuning change was not saved")
	panels[0].call("_reset_all")
	panels[0].call("_close")
	await process_frame
	await process_frame
	if bool(rt_mod.call("is_blocked")):
		fails.append("clock still paused after closing the tuning panel")


## BID-078: an enemy spell resolves at the player — not at the caster, even though
## real time pins current_player_idx to the player.
func _check_enemy_spell(battle: Node, state: _GameState, fails: Array[String]) -> void:
	var enemy := state.players[1]
	var bolt := _CardInstance.new(CardRegistry.get_template("shadow_bolt"))
	enemy.hand.append(bolt)
	enemy.hero.max_mana = 99999
	enemy.hero.mana = 99999
	var player_before: int = state.players[0].hero.health
	var enemy_before: int = enemy.hero.health
	for c in state.players[0].board.get_cards().duplicate():
		state.players[0].board.remove_card(c)
	if not enemy.play_card(bolt):
		fails.append("enemy could not play its spell")
		return
	var rt_node: Node = battle.get("realtime")
	rt_node.call("_after_enemy_play", bolt, 1)
	if state.players[0].hero.health >= player_before:
		fails.append("enemy spell did not hurt the player (%d -> %d)" % [player_before, state.players[0].hero.health])
	if enemy.hero.health < enemy_before:
		fails.append("enemy spell hit its own caster")
