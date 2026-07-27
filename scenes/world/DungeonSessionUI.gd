extends Node
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

# Manages dungeon-room overlay panels (rest sites, culling, random events)
# and tracks hero HP across dungeon rooms within a single session.

var _hud: CanvasLayer
var _dialogue_cb: Callable  # func(text: String) -> void

var _dungeon_hero_hp: int = 30

func setup(hud: CanvasLayer, dialogue_cb: Callable) -> void:
	_hud = hud
	_dialogue_cb = dialogue_cb

func reset_hero_hp() -> void:
	_dungeon_hero_hp = 30

func _say(text: String) -> void:
	_dialogue_cb.call(text)

# ── Rest site panel ────────────────────────────────────────────────────────

func show_rest_site_panel(npc_data: Dictionary) -> void:
	var room_key: String = str(npc_data.get("after_dialogue", ""))
	if SceneManager.save_manager.is_dungeon_room_used(room_key):
		_say("This rest site has already been used.")
		return

	var vh: float = _hud.get_viewport().get_visible_rect().size.y
	var vw: float = _hud.get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.2, vh * 0.2)
	panel.custom_minimum_size = Vector2(vw * 0.6, vh * 0.5)
	_hud.add_child(panel)

	var vbox := _UiUtil.make_vbox(int(vh * 0.015), panel)

	var title := _UiUtil.make_label("Rest Site", int(vh * 0.05), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var hp_label := _UiUtil.make_label("Hero HP: %d / 30" % _dungeon_hero_hp, int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var rest_btn := _UiUtil.make_button("Rest — Recover 8 HP", Vector2(0, btn_h), int(font_size))
	rest_btn.disabled = _dungeon_hero_hp >= 30
	if rest_btn.disabled:
		rest_btn.tooltip_text = "Already at full health"
	vbox.add_child(rest_btn)

	var cull_btn := _UiUtil.make_button("Cull — Remove a card from deck", Vector2(0, btn_h), int(font_size), Callable(), vbox)
	cull_btn.disabled = SceneManager.save_manager.player_deck.size() < 2

	var leave_btn := _UiUtil.make_button("Leave", Vector2(0, btn_h), int(font_size), Callable(), vbox)

	rest_btn.pressed.connect(func() -> void:
		_dungeon_hero_hp = mini(_dungeon_hero_hp + 8, 30)
		SceneManager.save_manager.mark_dungeon_room_used(room_key)
		panel.queue_free()
		_say("You rest and recover. Hero HP: %d / 30" % _dungeon_hero_hp)
	)
	cull_btn.pressed.connect(func() -> void:
		panel.queue_free()
		SceneManager.save_manager.mark_dungeon_room_used(room_key)
		show_cull_panel()
	)
	leave_btn.pressed.connect(func() -> void: panel.queue_free())

# ── Card culling panel ─────────────────────────────────────────────────────

func show_cull_panel() -> void:
	var vh: float = _hud.get_viewport().get_visible_rect().size.y
	var vw: float = _hud.get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.065

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.1, vh * 0.1)
	panel.custom_minimum_size = Vector2(vw * 0.8, vh * 0.75)
	_hud.add_child(panel)

	var vbox := _UiUtil.make_vbox(int(vh * 0.01), panel)

	var title := _UiUtil.make_label("Choose a card to remove from your deck:", int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, vh * 0.55)
	vbox.add_child(scroll)

	var card_list := _UiUtil.make_vbox(int(vh * 0.008), scroll)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var deck_copy: Array[String] = []
	deck_copy.assign(SceneManager.save_manager.player_deck)

	for ci in range(deck_copy.size()):
		var cid: String = deck_copy[ci]
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(cid)
		var display_name: String = str(inst.get("template_id", cid)).capitalize().replace("_", " ") if not inst.is_empty() else cid.capitalize().replace("_", " ")
		var btn := _UiUtil.make_button(display_name, Vector2(0, btn_h), int(font_size), Callable(), card_list)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			var new_deck: Array[String] = []
			var removed_once: bool = false
			for deck_card: String in SceneManager.save_manager.player_deck:
				if not removed_once and deck_card == cid:
					removed_once = true
				else:
					new_deck.append(deck_card)
			SceneManager.save_manager.set_active_deck(new_deck)
			panel.queue_free()
			_say("Removed %s from your deck." % display_name)
		)

	var cancel_btn := _UiUtil.make_button("Cancel", Vector2(0, btn_h), int(font_size), Callable(), vbox)
	cancel_btn.pressed.connect(func() -> void: panel.queue_free())

# ── Random event panel ─────────────────────────────────────────────────────

func show_event_panel(npc_data: Dictionary) -> void:
	var room_key: String = str(npc_data.get("after_dialogue", ""))
	if SceneManager.save_manager.is_dungeon_room_used(room_key):
		_say("The event here has already passed.")
		return

	var file := FileAccess.open("res://data/dungeon_events.json", FileAccess.READ)
	if not file:
		_say("Nothing of interest here.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Array):
		_say("Nothing of interest here.")
		return
	var events: Array = parsed
	if events.is_empty():
		_say("Nothing of interest here.")
		return

	var event_rng := RandomNumberGenerator.new()
	event_rng.seed = room_key.hash()
	var event_idx: int = event_rng.randi() % events.size()
	var event: Dictionary = events[event_idx]

	var vh: float = _hud.get_viewport().get_visible_rect().size.y
	var vw: float = _hud.get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.1, vh * 0.15)
	panel.custom_minimum_size = Vector2(vw * 0.8, vh * 0.65)
	_hud.add_child(panel)

	var vbox := _UiUtil.make_vbox(int(vh * 0.015), panel)

	var event_text := _UiUtil.make_label(str(event.get("text", "Something happens.")), int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, vbox)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var choices: Array = event.get("choices", [])
	for choice_idx in range(choices.size()):
		var choice: Dictionary = choices[choice_idx]
		if not (choice is Dictionary):
			continue
		var captured: Dictionary = choice
		var btn := _UiUtil.make_button(str(captured.get("label", "Choose")), Vector2(0, btn_h), int(font_size), Callable(), vbox)
		btn.pressed.connect(func() -> void:
			panel.queue_free()
			SceneManager.save_manager.mark_dungeon_room_used(room_key)
			apply_event_outcome(captured)
		)

# ── Event outcome application ──────────────────────────────────────────────

func apply_event_outcome(choice: Dictionary) -> void:
	var outcome_type: String = str(choice.get("outcome_type", "nothing"))
	var outcome_value: int = int(choice.get("outcome_value", 0))
	var outcome_text: String = str(choice.get("outcome_text", ""))
	var card_pool: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]

	match outcome_type:
		"gain_coins":
			SceneManager.save_manager.add_coins(outcome_value)
		"lose_hp":
			_dungeon_hero_hp = maxi(_dungeon_hero_hp - outcome_value, 1)
		"gain_card":
			var picked: String = card_pool[randi() % card_pool.size()]
			var new_cards: Array[String] = [picked]
			SceneManager.save_manager.add_cards_to_deck(new_cards)
			outcome_text += (" (Received: %s)" % picked) if not outcome_text.is_empty() else "Received: %s" % picked
		"lose_card":
			if not SceneManager.save_manager.player_deck.is_empty():
				var removed_uid: String = SceneManager.save_manager.player_deck[-1]
				var removed_inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(removed_uid)
				var removed_name: String = str(removed_inst.get("template_id", removed_uid)).capitalize().replace("_", " ") if not removed_inst.is_empty() else removed_uid
				var trimmed: Array[String] = []
				trimmed.assign(SceneManager.save_manager.player_deck)
				trimmed.pop_back()
				SceneManager.save_manager.set_active_deck(trimmed)
				outcome_text += (" (Lost: %s)" % removed_name) if not outcome_text.is_empty() else "Lost: %s" % removed_name
		"lose_hp_gain_card":
			_dungeon_hero_hp = maxi(_dungeon_hero_hp - outcome_value, 1)
			var picked: String = card_pool[randi() % card_pool.size()]
			var new_cards: Array[String] = [picked]
			SceneManager.save_manager.add_cards_to_deck(new_cards)
			outcome_text += (" (Received: %s)" % picked) if not outcome_text.is_empty() else "Received: %s" % picked
		"gain_coins_lose_hp":
			SceneManager.save_manager.add_coins(outcome_value)
			_dungeon_hero_hp = maxi(_dungeon_hero_hp - 3, 1)
		"lose_coins_gain_card":
			if SceneManager.save_manager.coins >= outcome_value:
				SceneManager.save_manager.add_coins(-outcome_value)
				var picked: String = card_pool[randi() % card_pool.size()]
				var new_cards: Array[String] = [picked]
				SceneManager.save_manager.add_cards_to_deck(new_cards)
				outcome_text += (" (Received: %s)" % picked) if not outcome_text.is_empty() else "Received: %s" % picked
			else:
				outcome_text = "Not enough coins!"

	if not outcome_text.is_empty():
		_say(outcome_text)
