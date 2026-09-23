## What happens when the player talks to an NPC: shop / service types open their
## panel, King Eldar runs his custom Chapter 1 states, duelists offer a wagered
## duel, and everyone else speaks their (flag-aware) dialogue line.
extends Node

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _DUEL_PANEL_BG := Color(0.08, 0.08, 0.18, 0.96)

var _world: Node = null

## Runs the interaction for whichever NPC type the player is standing at.
func interact(npc: Dictionary) -> void:
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

## The generic path: a live NPC node picks its line from story flags (and
## setting its flag_key marks the conversation as had); otherwise the map's text.
func _speak(npc: Dictionary) -> void:
	var node: Node3D = _world._valid_node3d(_world._npc_nodes.get(str(npc.get("id", ""))))
	if node == null or not node.has_method("get_dialogue"):
		_world._show_dialogue(str(npc.get("dialogue", "...")))
		return
	var line: String = node.get_dialogue()
	var fk: String = str(npc.get("flag_key", ""))
	if fk != "":
		SceneManager.save_manager.set_story_flag(fk)
	_world._show_dialogue(line)

## Chapter 1 ending trigger (GID-108 / TID-405). King Eldar's dialogue is fully
## custom (his npc_type bypasses the generic flag_key path) because it needs
## four states the 2-state MapNpc schema can't express: first meeting / council
## in session / ending trigger / post-ending epilogue.
func _king_eldar(npc: Dictionary) -> void:
	var sm: Node = SceneManager.save_manager
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
	var sm: Node = SceneManager.save_manager
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
