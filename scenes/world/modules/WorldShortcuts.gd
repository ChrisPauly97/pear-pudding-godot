## World keyboard / action shortcuts (BID-055 slice): pause (Esc also closes
## the fast-travel panel), map view, the four menu actions, G / D cantrips and
## the desktop chat-focus Enter. Tap-to-move gets anything left over. Every one
## has a touch equivalent on the HUD (CLAUDE.md "Mobile / Desktop Feature Parity").
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")

const _MENU_ACTIONS: Array[String] = ["inventory", "journal", "character", "skill_tree"]

var _world: _WorldScene = null


## WorldScene._unhandled_input forwards every unhandled event here.
func handle(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Esc closes an open fast-travel panel rather than pausing over it.
		if not _world.named_props.close_fast_travel() and _world._pause_overlay == null:
			_world._open_pause()
		_world.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map_view"):
		_world.tap_move.clear()
		_world._open_map_view()
		_world.get_viewport().set_input_as_handled()
		return
	var menu: String = _pressed_menu_action(event)
	if menu != "":
		_world.tap_move.clear()
		match menu:
			"inventory": GameBus.inventory_requested.emit()
			"journal": GameBus.journal_requested.emit()
			"character": GameBus.character_requested.emit()
			"skill_tree": GameBus.skill_tree_requested.emit()
		_world.get_viewport().set_input_as_handled()
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_G:
		_world.cantrips.activate_ghost_phase()
		_world.get_viewport().set_input_as_handled()
	elif key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_D:
		# D is also move_right: dig only when a mound is in reach, and never
		# consume the event, so walking right stays silent.
		_world.cantrips.activate_skeleton_dig(true)
	elif key_event != null and key_event.pressed \
			and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER) \
			and _world._coop_active and _world._chat_input != null and is_instance_valid(_world._chat_input) \
			and not _world._chat_input.has_focus():
		# Desktop chat-focus shortcut (TID-374). Mobile equivalent is the "Chat"
		# HUD button (_chat_toggle_btn), which also reveals/focuses the input.
		_world._chat_input.grab_focus()
		_world.get_viewport().set_input_as_handled()
	elif _world.tap_move.handle_input(event):
		_world.get_viewport().set_input_as_handled()


static func _pressed_menu_action(event: InputEvent) -> String:
	for action: String in _MENU_ACTIONS:
		if event.is_action_pressed(action):
			return action
	return ""
