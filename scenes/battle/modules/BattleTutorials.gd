## First-battle tutorial card and the scripted-battle tutorial steps.
##
## A child of BattleScene (`BattleScene.tutorials`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const ScriptedBattleData = preload("res://game_logic/battle/ScriptedBattleData.gd")
const _TutorialPopupScript = preload("res://scenes/ui/TutorialPopup.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


func _show_battle_tutorial() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = _battle._font(0.025)
	var panel_w: float = vp.x * 0.65
	var panel_h: float = _battle._vh * 0.32

	var layer := CanvasLayer.new()
	layer.layer = 150
	_battle.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.08, 0.08, 0.18, 0.95), 10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := _UiUtil.make_margin(int(panel_w * 0.06), int(panel_h * 0.08), int(panel_w * 0.06),
			int(panel_h * 0.08), panel)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := _UiUtil.make_vbox(int(_battle._vh * 0.02), margin)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var label := _UiUtil.make_label(
			"Tap a card, then tap a green slot to play it.\nTap your minion, then tap an enemy to attack.\nHold any "
				+ "card to see its details. (Dragging works too.)",
			int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)

	var btn := _UiUtil.make_button("Got it", Vector2(_battle._vh * 0.14, _battle._vh * 0.06), int(font_size),
			_dismiss_battle_tutorial,
			vbox)

	_battle._tutorial_overlay = layer
	get_tree().create_timer(_battle.TUTORIAL_DURATION, false).timeout.connect(_dismiss_battle_tutorial)

func _dismiss_battle_tutorial() -> void:
	if _battle._tutorial_overlay != null and is_instance_valid(_battle._tutorial_overlay):
		_battle._tutorial_overlay.queue_free()
		_battle._tutorial_overlay = null
	SceneManager.save_manager.set_story_flag("tutorial_battle_tip")

## Scripted story battles (GID-108): shows the Maiteln guidance line authored for
## the player's Nth turn, if any. Direct TutorialPopup instantiation — deliberately
## NOT routed through GameBus.tutorial_popup_requested / TutorialRegistry, which
## gate on a global "seen once ever" flag keyed to static tutorial ids and are the
## wrong fit for one-off, per-battle scripted content. Dedupes per turn number so
## a re-entrant call (e.g. _ready() and _on_turn_ended both covering turn 1) never
## shows the same step twice.
func _maybe_show_scripted_tutorial_step(player_turn_number: int) -> void:
	if _battle._scripted_data_ref == null:
		return
	if _battle._scripted_tutorial_turns_shown.has(player_turn_number):
		return
	var sdata: ScriptedBattleData = _battle._scripted_data_ref as ScriptedBattleData
	if sdata == null:
		return
	for step: String in sdata.tutorial_steps:
		var parts: PackedStringArray = step.split(":", true, 1)
		if parts.size() != 2 or not parts[0].is_valid_int():
			continue
		if int(parts[0]) != player_turn_number:
			continue
		_battle._scripted_tutorial_turns_shown[player_turn_number] = true
		var popup := _TutorialPopupScript.new()
		popup.setup(sdata.title, parts[1])
		popup.set_anchors_preset(Control.PRESET_FULL_RECT)
		var layer := CanvasLayer.new()
		layer.layer = 999
		layer.add_child(popup)
		_battle.add_child(layer)
		# BaseOverlay._close() only emits `closed` — the caller must free the
		# wrapper (see SceneManager._on_tutorial_popup_requested for the precedent).
		popup.closed.connect(func() -> void: layer.queue_free())
		return
