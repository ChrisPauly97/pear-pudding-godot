## Battle defeat: co-op dungeon downing, siege and Spire losses, and the
## Retry / Respawn / Menu defeat card.
##
## A child of the SceneManager autoload, created in `SceneManager._ensure_modules()`.
## Reach SceneManager state as `_sm.<name>` and write the state only through
## `_sm._transition_to()`. Use `_sm.add_child` rather than a bare `add_child`.
extends Node

const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
# gdlint:ignore = constant-name
const State = _SceneFlow.State
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _sm: Node

var _defeat_overlay: Node = null
var _defeat_pending_enemy_data: Dictionary = {}


func _init(scene_manager: Node) -> void:
	_sm = scene_manager


## Drops the defeat card and the queued Retry, for every world-exit path.
func clear() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	_defeat_pending_enemy_data = {}


func _on_battle_lost() -> void:
	if _sm.current_state() != State.BATTLE:
		return
	_sm._current_battle_enemy_id = ""
	_sm._bump_session_stat("battles_lost", 1)
	# Downed & rescue in shared co-op dungeons (GID-105 / TID-389): a PvE loss inside
	# a shared dungeon crawl leaves the player downed/revivable instead of routing to
	# the single-player defeat screen below. Checked first — siege/spire are solo
	# SaveManager-driven systems that never overlap with an active co-op dungeon crawl.
	if NetworkManager.is_active() and _sm.current_map.begins_with("dungeon_"):
		_sm.save_manager.clear_pending_battle()
		_sm.save_manager.clear_pending_battle_state()
		_sm._dismiss_battle_overlay()
		TransitionManager.transition(func() -> void:
			if _sm._saved_world_scene != null:
				get_tree().root.add_child(_sm._saved_world_scene)
				get_tree().current_scene = _sm._saved_world_scene
				if _sm._saved_world_scene.has_method("enter_downed_state"):
					_sm._saved_world_scene.call("enter_downed_state")
				_sm._saved_world_scene = null)
		_sm._transition_to(State.WORLD)
		return
	# Siege defeat: apply coin penalty, end siege, then show standard game over.
	var _siege_on_lost: Dictionary = _sm.save_manager.get_active_siege()
	if not _siege_on_lost.is_empty():
		var _loss_coins: int = int(_sm.save_manager.coins * 0.10)
		if _loss_coins > 0:
			_sm.save_manager.add_coins(-_loss_coins)
		_sm.save_manager.end_siege_defeat()
		GameBus.siege_defeated.emit(_loss_coins)
	if _sm.save_manager.is_spire_active():
		_sm._restore_spire_entry_point()
		var stats: Dictionary = _sm.save_manager.end_spire_run()
		GameBus.spire_run_ended.emit(stats)
		_sm._finish_battle()
		if _sm._saved_world_scene != null:
			_sm._saved_world_scene.queue_free()
			_sm._saved_world_scene = null
		_sm._exit_world_cleanup()
		var summary: Node = _sm._run_summary_scene_packed.instantiate()
		summary.set("spire_stats", stats)
		get_tree().change_scene_to_node(summary)
		_sm._transition_to(State.RUN_SUMMARY)
		return
	# Regular battle loss: keep world alive and show defeat overlay with Retry/Respawn/Menu.
	_defeat_pending_enemy_data = _sm.save_manager.pending_battle_enemy_data.duplicate()
	_sm.save_manager.clear_pending_battle_state()
	_sm._dismiss_battle_overlay()
	# Restore world to tree without clearing pending_battle (needed for Retry).
	TransitionManager.transition(func() -> void:
		if _sm._saved_world_scene != null:
			get_tree().root.add_child(_sm._saved_world_scene)
			get_tree().current_scene = _sm._saved_world_scene
			_sm._saved_world_scene = null
		_show_defeat_overlay())
	_sm._transition_to(State.GAME_OVER)

func _show_defeat_overlay() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var layer := CanvasLayer.new()
	layer.layer = 190
	get_tree().root.add_child(layer)
	_defeat_overlay = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.58
	var panel_h: float = vh * 0.50
	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.08, 0.04, 0.04, 0.97), 12)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := _UiUtil.make_margin(int(vh * 0.03), int(vh * 0.03), int(vh * 0.03), int(vh * 0.03), panel)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := _UiUtil.make_vbox(int(vh * 0.028), margin)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := _UiUtil.make_label("Defeated", int(vh * 0.055))
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var has_retry: bool = not _defeat_pending_enemy_data.is_empty()
	if has_retry:
		var retry_btn := _UiUtil.make_button("Retry Battle", Vector2(vh * 0.32, vh * 0.07), int(vh * 0.03),
				_on_defeat_retry, vbox)

	var respawn_btn := _UiUtil.make_button("Respawn in World", Vector2(vh * 0.32, vh * 0.07), int(vh * 0.03),
			_on_defeat_respawn, vbox)

	var menu_btn := _UiUtil.make_button("Return to Menu", Vector2(vh * 0.32, vh * 0.07), int(vh * 0.03),
			_on_defeat_menu, vbox)

func _on_defeat_retry() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	var enemy_data: Dictionary = _defeat_pending_enemy_data.duplicate()
	_defeat_pending_enemy_data = {}
	_sm._transition_to(State.WORLD)
	_sm._start_battle(enemy_data)

func _on_defeat_respawn() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	_defeat_pending_enemy_data = {}
	_sm.save_manager.clear_pending_battle()
	_sm.save_manager.save()
	_sm._proximity_engage_blocked = true
	get_tree().create_timer(2.0, false).timeout.connect(
		func() -> void: _sm._proximity_engage_blocked = false)
	_sm._transition_to(State.WORLD)

func _on_defeat_menu() -> void:
	if _defeat_overlay != null:
		_defeat_overlay.queue_free()
		_defeat_overlay = null
	_defeat_pending_enemy_data = {}
	_sm.save_manager.clear_pending_battle()
	_sm.go_to_menu()


