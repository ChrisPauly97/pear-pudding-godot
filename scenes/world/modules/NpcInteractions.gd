## What happens when the player talks to an NPC: shop / service types open their
## panel, King Eldar runs his custom Chapter 1 states, duelists offer a wagered
## duel, and everyone else speaks their (flag-aware) dialogue line.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const SkillBar = preload("res://game_logic/battle/SkillBar.gd")
const _SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const _QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

const _DUEL_PANEL_BG := Color(0.08, 0.08, 0.18, 0.96)
## TID-557: fixed enemy id for the town training dummy fight — see EnemyRegistry.gd.
const _TRAINING_DUMMY_ENEMY_TYPE: String = "training_dummy"

var _world: _WorldScene = null

## Runs the interaction for whichever NPC type the player is standing at.
## Side quests (TID-534) come first: a quest to hand in or to offer opens the
## quest panel, whose "Other business" button falls through to the NPC's
## usual interaction.
func interact(npc: Dictionary) -> void:
	var npc_id: String = str(npc.get("id", ""))
	if npc_id != "":
		SceneManager.save_manager.quests.progress_event("talk", npc_id)
	if show_quest_panel(npc):
		return
	# GID-141: a trainer with training waiting teaches first; "Other business"
	# (shop, stable, board) is one tap away on the trainer panel's NPC.
	var trainer: String = _UnlockLadder.trainer_at(npc_id)
	if trainer != "" and str(npc.get("npc_type", "")) != "trainer" and trainer_has_pending(trainer):
		show_trainer_panel(trainer, npc)
		return
	interact_service(npc)

## The NPC's own interaction (shop, trainer, dialogue…), without quests.
func interact_service(npc: Dictionary) -> void:
	match str(npc.get("npc_type", "")):
		"traveling_merchant":
			var stock: Array[String] = []
			var raw: Variant = npc.get("merchant_stock", [])
			if raw is Array:
				stock.assign(raw as Array)
			GameBus.traveling_shop_requested.emit(stock, 30)
		"merchant":
			GameBus.shop_requested.emit()
		"blacksmith":
			GameBus.blacksmith_requested.emit()
		"bounty_board":
			GameBus.bounty_board_requested.emit()
		"stable":
			_world.mounts.show_stable_panel()
		"duelist":
			show_duel_offer_panel(npc)
		"trainer":
			show_trainer_panel(_UnlockLadder.trainer_at(str(npc.get("id", ""))))
		"training_dummy":
			_offer_training_dummy_fight()
		"rest_site":
			_world._dungeon_session_ui.show_rest_site_panel(npc)
		"event_room":
			_world._dungeon_session_ui.show_event_panel(npc)
		"bed":
			_world.player_home.use_bed()
		"trophy_pedestal":
			_world._show_dialogue(str(npc.get("dialogue", "A mysterious trophy.")))
		"chapter1_king_eldar":
			_king_eldar(npc)
		"stash_chest":
			_world.coop_social._toggle_stash_overlay()
		_:
			_speak(npc)

# ── Side quests (GID-136 / TID-534) ─────────────────────────────────────────

## Opens the quest panel when `npc` has a quest ready to hand in (first) or one
## to offer. Returns false when it has neither.
func show_quest_panel(npc: Dictionary) -> bool:
	var sm := SceneManager.save_manager
	var npc_id: String = str(npc.get("id", ""))
	var turn_ins: Array[Dictionary] = sm.quests.turn_ins_for(npc_id)
	if not turn_ins.is_empty():
		_quest_panel(npc, turn_ins[0], true)
		return true
	var offers: Array[Dictionary] = sm.quests.offers_for(npc_id)
	if not offers.is_empty():
		_quest_panel(npc, offers[0], false)
		return true
	return false

func _quest_panel(npc: Dictionary, q: Dictionary, turn_in: bool) -> void:
	var sm := SceneManager.save_manager
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var modal: Dictionary = _world._build_modal(0.7, 0.62, _DUEL_PANEL_BG, 0.016, 0.03, 0.5)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	var font: int = int(vh * 0.022)
	var id: String = str(q.get("id", ""))

	var title := _UiUtil.make_label(str(q.get("title", "")), int(vh * 0.032), Color(1.0, 0.92, 0.45),
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	title.theme_type_variation = &"TitleLabel"
	var who: String = _SideQuests.turn_in_name(q) if turn_in else str(q.get("giver_name", ""))
	_UiUtil.make_label(who, int(vh * 0.02), Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var body_text: String = str(q.get("done_text", "")) if turn_in else str(q.get("summary", ""))
	var body := _UiUtil.make_label(body_text, font, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, vbox)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not turn_in:
		for o: Dictionary in _SideQuests.objectives(q):
			_UiUtil.make_label("• %s  (%d)" % [str(o.get("label", "")), int(o.get("count", 1))],
					int(vh * 0.02), Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, vbox)
	_UiUtil.make_label("Reward: " + reward_text(q.get("rewards", {})), int(vh * 0.02),
			Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_LEFT, vbox)

	var row := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_size := Vector2(vh * 0.18, vh * 0.06)
	if turn_in:
		_UiUtil.make_button("Complete", btn_size, font, func() -> void:
			layer.queue_free()
			var rewards: Dictionary = sm.quests.turn_in(id)
			if not rewards.is_empty():
				GameBus.hud_message_requested.emit("Quest complete: %s  (%s)" % [str(q.get("title", "")),
						reward_text(rewards)])
			_world.quest_tracker.refresh(true), row)
	else:
		_UiUtil.make_button("Accept", btn_size, font, func() -> void:
			layer.queue_free()
			if sm.quests.accept(id):
				sm.set_tracked_quest(_QuestLog.SIDE_PREFIX + id)
				GameBus.hud_message_requested.emit("Quest accepted: " + str(q.get("title", "")))
			_world.quest_tracker.refresh(true), row)
		_UiUtil.make_button("Decline", btn_size, font, layer.queue_free, row)
	if str(npc.get("npc_type", "")) != "":
		_UiUtil.make_button("Other business", btn_size, font, func() -> void:
			layer.queue_free()
			interact_service(npc), row)

## "40 XP · 20 coins · 1 card" for a rewards dict.
static func reward_text(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	if int(rewards.get("xp", 0)) > 0:
		parts.append("%d XP" % int(rewards["xp"]))
	if int(rewards.get("coins", 0)) > 0:
		parts.append("%d coins" % int(rewards["coins"]))
	var cards: Array = rewards.get("cards", [])
	if not cards.is_empty():
		parts.append("%d card%s" % [cards.size(), "" if cards.size() == 1 else "s"])
	return " · ".join(parts) if not parts.is_empty() else "their thanks"

## The generic path: a live NPC node picks its line from story flags (and
## setting its flag_key marks the conversation as had); otherwise the map's text.
func _speak(npc: Dictionary) -> void:
	var node: Node3D = _world._valid_node3d(_world._npc_nodes.get(str(npc.get("id", ""))))
	if node == null or not node.has_method("get_dialogue"):
		_world._show_dialogue(str(npc.get("dialogue", "...")))
		return
	var line: String = str(node.call("get_dialogue"))
	var fk: String = str(npc.get("flag_key", ""))
	if fk != "":
		SceneManager.save_manager.set_story_flag(fk)
	_world._show_dialogue(line)

## Chapter 1 ending trigger (GID-108 / TID-405). King Eldar's dialogue is fully
## custom (his npc_type bypasses the generic flag_key path) because it needs
## four states the 2-state MapNpc schema can't express: first meeting / council
## in session / ending trigger / post-ending epilogue.
func _king_eldar(npc: Dictionary) -> void:
	var sm := SceneManager.save_manager
	if sm.get_story_flag("chapter1_complete"):
		# Chapter 2 beat 1 — the council's charge (GID-108 / TID-407): once,
		# the first time he's spoken to after the Chapter 1 ending.
		if not sm.get_story_flag("chapter2_charged"):
			sm.set_story_flag("chapter2_charged")
			_world._show_dialogue("Maiteln, Saimtar — you two ride west. Past Larik, to Lord Marsax. Ride swift, and ride true.")
		else:
			_world._show_dialogue("The realm owes its warning to a servant boy from Larik. Remember that, all of you.")
	elif not sm.get_story_flag("chapter1_temple_council"):
		sm.set_story_flag("chapter1_temple_council")
		_world._show_dialogue(str(npc.get("dialogue", "...")))
	elif sm.get_story_flag("chapter1_spoke_queen") and sm.get_story_flag("chapter1_spoke_scargroth"):
		_trigger_chapter1_ending()
	else:
		_world._show_dialogue("The council has heard the prophecy. We act at dawn.")

## Sets chapter1_complete and shows the three-page ending narration. No scene
## transition — closing the overlay leaves the player in a playable epilogue.
## The flag also hides Maiteln via StoryCast's story-flag hook (TID-403).
func _trigger_chapter1_ending() -> void:
	SceneManager.save_manager.set_story_flag("chapter1_complete")
	var pages: Array[String] = [
		"The council resolves — the old alliance is re-sworn, riders will carry the warning to every lord.",
		"Maiteln, quietly proud, tells Saimtar he has earned his place at his side.",
		"Scargroth pulls Saimtar aside: \"There is a name from Larik in the old registers you should see.\"",
	]
	GameBus.narration_overlay_requested.emit(pages, "", "")

## A duelist's wager offer. Rematches cost half; a champion refuses until the
## town's other duelists (`required_duelist_ids`) are beaten.
func show_duel_offer_panel(npc: Dictionary) -> void:
	var sm := SceneManager.save_manager
	var npc_id: String = str(npc.get("id", ""))
	var enemy_id: String = str(npc.get("duelist_enemy_id", "duelist_novice"))
	var is_rematch: bool = sm.defeated_duelists.has(npc_id)
	var wager: int = int(npc.get("wager_coins", 10))
	if is_rematch:
		wager = maxi(1, wager / 2)
	var gate_remaining: int = 0
	var req_ids: Variant = npc.get("required_duelist_ids")
	if req_ids is PackedStringArray:
		for rid: String in (req_ids as PackedStringArray):
			if not sm.defeated_duelists.has(rid):
				gate_remaining += 1
	var can_duel: bool = gate_remaining == 0 and sm.coins >= wager

	var offer: String = "Care for a friendly duel?\nWager: %d coins." % wager
	if gate_remaining > 0:
		offer = "I only duel proven players. Beat the others in town first. (%d more to go.)" % gate_remaining
	elif sm.coins < wager:
		offer = "Come back when you can cover the wager."
	elif is_rematch:
		offer = "A rematch? Wager: %d coins." % wager

	var modal: Dictionary = _world._build_modal(0.6, 0.38, _DUEL_PANEL_BG, 0.022, 0.03, 0.5)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var font: int = int(vh * 0.028)
	var btn_size := Vector2(vh * 0.18, vh * 0.07)
	var lbl := _UiUtil.make_label(offer, font, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := _UiUtil.make_hbox(int(vh * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if can_duel:
		var duel := func() -> void:
			layer.queue_free()
			GameBus.duel_requested.emit({
				"enemy_type": enemy_id,
				"enemy_deck": EnemyRegistry.get_deck(enemy_id),
				"duel_npc_id": npc_id,
				"champion_reward_card": str(npc.get("champion_reward_card", "")),
			}, wager)
		_UiUtil.make_button("Duel!", btn_size, font, duel, row)
	_UiUtil.make_button("Decline", btn_size, font, layer.queue_free, row)

## GID-141 / TID-590: a trainer's teach panel. Lists every UnlockLadder entry
## `trainer` teaches: learned ones ticked, locked ones greyed with their level,
## and each one the player can learn now in full — its how-to text and a
## "Learn — N gold" button, so the player reads what they are buying. Learning
## rebuilds the panel in place so the row flips to "Learned".
## `service_npc` (a merchant, stable, board…) adds an "Other business" button
## that closes the panel and runs that NPC's usual interaction.
func show_trainer_panel(trainer: String = "combat", service_npc: Dictionary = {}) -> void:
	var sm := SceneManager.save_manager
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var modal: Dictionary = _world._build_modal(0.8, 0.78, _DUEL_PANEL_BG, 0.014, 0.025, 0.5)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	var font: int = int(vh * 0.022)

	var title := _UiUtil.make_label(_UnlockLadder.trainer_name(trainer), int(vh * 0.034), Color(1.0, 0.92, 0.6),
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	title.theme_type_variation = &"TitleLabel"
	_UiUtil.make_label("Coins: %d  ·  Level %d" % [sm.coins, sm.level], int(vh * 0.02),
			Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, vh * 0.52)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := _UiUtil.make_vbox(int(vh * 0.018), scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in _UnlockLadder.for_trainer(trainer):
		list.add_child(_trainer_row(id, trainer, service_npc, sm, layer, font, vh))

	var close_row := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if trainer == "combat" and SkillBar.known_ids(sm.learned_abilities).size() > 1:
		# TID-556: also reachable from the Menu Hub's "Skill Bar" tab at any time.
		_UiUtil.make_button("Skill Bar", Vector2(vh * 0.18, vh * 0.06), font, func() -> void:
			layer.queue_free()
			SceneManager.open_menu_hub("loadout"), close_row)
	if str(service_npc.get("npc_type", "")) != "":
		_UiUtil.make_button("Other business", Vector2(vh * 0.2, vh * 0.06), font, func() -> void:
			layer.queue_free()
			interact_service(service_npc), close_row)
	_UiUtil.make_button("Close", Vector2(vh * 0.18, vh * 0.06), font, layer.queue_free, close_row)

func _trainer_row(id: String, trainer: String, service_npc: Dictionary, sm: SaveManager, layer: CanvasLayer,
		font: int, vh: float) -> Control:
	var row_def: Dictionary = _UnlockLadder.def(id)
	var level_req: int = _UnlockLadder.level_req(id)
	var cost: int = _UnlockLadder.cost(id)
	var learned: bool = sm.learned_abilities.has(id)
	var reached: bool = sm.level >= level_req

	var box := _UiUtil.make_vbox(int(vh * 0.006))
	var head := _UiUtil.make_hbox(int(vh * 0.015), box)
	var name_col: Color = Color.WHITE if reached or learned else Color(0.55, 0.55, 0.6)
	var name_lbl := _UiUtil.make_label("%s  —  Level %d · %d gold" % [str(row_def.get("title", id)), level_req, cost],
			int(vh * 0.024), name_col, HORIZONTAL_ALIGNMENT_LEFT, head)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if learned:
		_UiUtil.make_label("Learned ✓", int(vh * 0.02), Color(0.5, 0.9, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, head)
		return box
	if not reached:
		_UiUtil.make_label("Come back at level %d" % level_req, int(vh * 0.019), Color(0.6, 0.6, 0.65),
				HORIZONTAL_ALIGNMENT_RIGHT, head)
		return box
	var how := _UiUtil.make_label(str(row_def.get("how_to", "")), int(vh * 0.019), Color(0.86, 0.88, 0.95),
			HORIZONTAL_ALIGNMENT_LEFT, box)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var can: bool = _UnlockLadder.can_learn(id, sm.level, sm.coins, sm.learned_abilities)
	var btn_row := _UiUtil.make_hbox(int(vh * 0.01), box)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	if not can:
		_UiUtil.make_label("Need %d more gold" % (cost - sm.coins), int(vh * 0.019), Color(0.95, 0.45, 0.4),
				HORIZONTAL_ALIGNMENT_RIGHT, btn_row)
	var learn_btn := _UiUtil.make_button("Learn — %d gold" % cost, Vector2(vh * 0.24, vh * 0.055), font,
			func() -> void:
				if sm.learn_ability(id, cost):
					layer.queue_free()
					show_trainer_panel(trainer, service_npc), btn_row)
	learn_btn.disabled = not can
	return box

## True when `trainer` has something the player could learn now (level reached,
## not yet learned) — the "!" over them and the reason talking opens the panel.
static func trainer_has_pending(trainer: String) -> bool:
	var sm := SceneManager.save_manager
	for id: String in _UnlockLadder.pending(sm.level, sm.learned_abilities):
		if _UnlockLadder.trainer_for(id) == trainer:
			return true
	return false

## TID-557: interacting with the town training dummy — a free-of-consequence
## real-time practice fight. No deck-size gate, no gambit picker, no coin
## wager and (via EnemyRegistry.is_passive / RealtimeCombat.set_passive) no
## enemy actions at all. GameBus.duel_requested with an empty duel_npc_id
## skips every reward/record path in SceneManager._on_duel_won/_on_duel_lost —
## nothing is ever marked defeated and nothing is granted. Leaving is the
## existing "Flee Battle" pause-menu button, unconditionally available in
## every battle kind. BattleOnboarding.begin(count=false) keeps it from
## advancing SaveManager.realtime_fights.
func _offer_training_dummy_fight() -> void:
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var modal: Dictionary = _world._build_modal(0.6, 0.32, _DUEL_PANEL_BG, 0.022, 0.03, 0.5)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var font: int = int(vh * 0.028)
	var lbl := _UiUtil.make_label(
			"Practice against the dummy? It never fights back — leave any time from the pause menu.",
			font, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := _UiUtil.make_hbox(int(vh * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_size := Vector2(vh * 0.18, vh * 0.07)
	var start := func() -> void:
		layer.queue_free()
		GameBus.duel_requested.emit({
			"enemy_type": _TRAINING_DUMMY_ENEMY_TYPE,
			"enemy_deck": EnemyRegistry.get_deck(_TRAINING_DUMMY_ENEMY_TYPE),
			"is_boss": true,
			"boss_hp": EnemyRegistry.get_boss_hp(_TRAINING_DUMMY_ENEMY_TYPE),
			"duel_npc_id": "",
			"champion_reward_card": "",
		}, 0)
	_UiUtil.make_button("Practice", btn_size, font, start, row)
	_UiUtil.make_button("Not now", btn_size, font, layer.queue_free, row)
