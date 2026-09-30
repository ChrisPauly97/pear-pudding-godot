## Captures a turn-based battle screenshot so card faces, backs and board cards
## can be eyeballed (GID-151). Needs a real or virtual display:
##   OUT=/tmp/battle.png xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capture_battle_cards.gd
## DECK (comma list) sets the hand, MODE=realtime|turn, WAIT_MS delays the capture,
## CAST=<ms> casts the hand's draw spell, DEATH=<ms> kills the enemy board,
## REVEAL=<ms> has the enemy play a card and captures <ms> later,
## HOVER=1 lifts the second hand card, POST_MS is the time after the hand is dealt
## (small values catch animations mid-flight).
extends SceneTree

const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _TutorialRegistry = preload("res://game_logic/TutorialRegistry.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

func _initialize() -> void:
	_run.call_deferred()

func _wait(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _run() -> void:
	await process_frame
	var sm: Node = root.get_node("SceneManager")
	var save: Object = sm.get("save_manager")
	save.call("new_game", 1)
	var mode: String = OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "turn"
	save.call("set_setting", "battle_mode", mode)
	save.call("set_setting", "auto_skip_gambits", true)
	var learned: Array[String] = _UnlockLadder.all_ids()
	save.set("learned_abilities", learned)
	save.call("set_story_flag", "tutorial_battle_tip")
	for id: String in _TutorialRegistry._DATA:
		save.call("set_story_flag", "seen_tutorial_" + id)
	var deck_env: String = OS.get_environment("DECK")
	var deck: Array[String] = []
	deck.assign(("dawn_acolyte,blessed_light,ash_warden,alight,bloom_germinate,flux_displace,skeleton,ghost"
			if deck_env == "" else deck_env).split(","))
	save.set("player_deck", deck)
	var ws: Node = (load("res://scenes/world/WorldScene.tscn") as PackedScene).instantiate()
	ws.set("map_name", "main")
	root.add_child(ws)
	current_scene = ws
	sm.call("_transition_to", _SceneFlow.State.WORLD)
	await _wait(300)
	sm.call("_start_battle", {"enemy_type": "undead_basic", "is_boss": false,
		"enemy_deck": ["ghost", "ghost", "skeleton", "skeleton", "ghost", "ghost"]})
	var wait_ms: int = int(OS.get_environment("WAIT_MS")) if OS.get_environment("WAIT_MS") != "" else 4000
	await _wait(wait_ms)
	var battle: Node = current_scene
	var state: Object = battle.get("_state")
	var t0: int = Time.get_ticks_msec()
	while int(state.get("current_player_idx")) != 0 and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	var me: Object = (state.get("players") as Array)[0]
	var hand: Array = me.get("hand")
	hand.clear()
	var rarities: Array[String] = ["common", "rare", "epic", "legendary"]
	for id: String in deck.slice(0, 6):
		var ci := _CardInstance.new(_CardRegistry.get_template(id))
		ci.rarity = rarities[hand.size() % rarities.size()]  # show every rarity treatment
		hand.append(ci)
	(me.get("hero") as Object).set("mana", 10)
	battle.call("_refresh_all")
	await _wait(int(OS.get_environment("POST_MS")) if OS.get_environment("POST_MS") != "" else 800)
	if OS.get_environment("REVEAL") != "":
		var foe: Object = (state.get("players") as Array)[1]
		(foe.get("board") as Object).call("add_card", _CardInstance.new(_CardRegistry.get_template("ash_warden")))
		battle.call("_refresh_all")
		await _wait(int(OS.get_environment("REVEAL")))
	if OS.get_environment("CAST") != "":
		for c: Object in hand:
			if str(c.get("card_class")) == "spell" and str(c.get("spell_effect")) == "draw_card":
				battle.call("_do_play_card", c, 0)
				break
		await _wait(int(OS.get_environment("CAST")))
	if OS.get_environment("DEATH") != "":
		var fx: Object = battle.get("_fx")
		var snap: Array = fx.call("snapshot")
		var foe_board: Object = ((state.get("players") as Array)[1] as Object).get("board")
		for c: Object in (foe_board.call("get_cards") as Array):
			foe_board.call("remove_card", c)
		battle.call("_animate_deaths_from_snapshot", snap)
		await _wait(int(OS.get_environment("DEATH")))
	var hv: Control = battle.get("_player_hand_view") as Control
	if OS.get_environment("HOVER") != "" and hv != null and hv.get_child_count() > 1:
		(battle.get("card_input") as Object).call("_set_hover_lift", hv.get_child(1), true)
		await _wait(200)
	if hv != null and hv.get_child_count() > 0:
		var p0: Control = hv.get_child(0) as Control
		var rim: StyleBoxFlat = p0.get_meta("card_style") as StyleBoxFlat
		print("turn=", state.get("current_player_idx"), " glow=", p0.has_meta("glow_tween"), " rim=", rim != null)
	if hv != null:
		print("hand view visible=", hv.is_visible_in_tree(), " rect=", hv.get_global_rect(), " kids=", hv.get_child_count())
	await RenderingServer.frame_post_draw
	var out: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/battle.png"
	root.get_viewport().get_texture().get_image().save_png(out)
	print("wrote ", out)
	quit()
