## Rift entrances (GID-142 / TID-600): the panel a rift door opens — which rift,
## your best tier there, a tier picker capped at best + 1, the active quest hint,
## and Enter / Resume. Madrian's Spire door (`target_map "spire"`) is the
## Grasslands rift; biome portals in the wilds carry `target_map "rift:<id>"`
## (InfiniteWorldGen). Created by `WorldScene._ensure_world_modules()` as
## `rift_portals`.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _PANEL_BG := Color(0.06, 0.04, 0.14, 0.96)
const _ACCENT := Color(0.85, 0.50, 1.0)

var _world: _WorldScene = null


## Rift id a door target names ("spire" → the Grasslands rift), or "".
static func rift_for_target(target_map: String) -> String:
	if target_map == "spire":
		return _RiftDefs.DEFAULT_RIFT
	if target_map.begins_with("rift:"):
		var id: String = target_map.trim_prefix("rift:")
		return id if not _RiftDefs.def(id).is_empty() else ""
	return ""

func show_panel(rift_id: String) -> void:
	var sm := SceneManager.save_manager
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var modal: Dictionary = _world._build_modal(0.64, 0.46, _PANEL_BG, 0.02)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var font: int = int(vh * 0.026)
	var title := _UiUtil.make_label(_RiftDefs.rift_name(rift_id), int(vh * 0.038), _ACCENT,
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	title.theme_type_variation = &"TitleLabel"
	var row := _UiUtil.make_hbox(int(vh * 0.03))
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	if not sm.has_learned(_UnlockLadder.FEAT_SPIRE):
		_desc(vbox, "The tear hums, but won't let you in.\n" + _UnlockLadder.locked_message(_UnlockLadder.FEAT_SPIRE),
				vh)
		vbox.add_child(row)
		_UiUtil.make_button("Leave", Vector2(vh * 0.16, vh * 0.07), font, layer.queue_free, row)
		return

	if sm.spire.is_spire_active():
		var run: Dictionary = sm.spire.get_spire_run()
		var run_rift: String = str(run.get("rift", _RiftDefs.DEFAULT_RIFT))
		_desc(vbox, "A run is under way in the %s — tier %d, floor %d." % [_RiftDefs.rift_name(run_rift),
				int(run.get("tier", 1)), int(run.get("floor", 1))], vh)
		vbox.add_child(row)
		_UiUtil.make_button("Resume", Vector2(vh * 0.18, vh * 0.07), font, func() -> void:
			layer.queue_free()
			SceneManager.enter_spire(run_rift), row)
		_UiUtil.make_button("Leave", Vector2(vh * 0.16, vh * 0.07), font, layer.queue_free, row)
		return

	var best: int = sm.spire.best_tier(rift_id)
	var max_tier: int = _RiftDefs.max_start_tier(best)
	_desc(vbox, ("Five floors, your own deck, a guardian at the top. Boons between floors last the run only.\n"
			+ "Best tier cleared here: %s") % (str(best) if best > 0 else "none yet"), vh)
	var tier_row := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var picked: Array[int] = [max_tier]
	var tier_lbl := _UiUtil.make_label("", font, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var info_lbl := _UiUtil.make_label("", int(vh * 0.02), Color(0.75, 0.75, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	var refresh := func() -> void:
		tier_lbl.text = "Tier %d" % picked[0]
		info_lbl.text = "Enemies level %d–%d%s" % [_RiftDefs.enemy_level(picked[0], 1),
				_RiftDefs.enemy_level(picked[0], _RiftDefs.FLOORS_PER_TIER),
				"" if sm.rift_first_clears.has(_RiftDefs.clear_key(rift_id, picked[0]))
				else "  ·  first clear: +%d XP" % _RiftDefs.first_clear_xp(picked[0])]
	_UiUtil.make_button("−", Vector2(vh * 0.06, vh * 0.06), font, func() -> void:
		picked[0] = maxi(1, picked[0] - 1)
		refresh.call(), tier_row)
	tier_row.add_child(tier_lbl)
	_UiUtil.make_button("+", Vector2(vh * 0.06, vh * 0.06), font, func() -> void:
		picked[0] = mini(max_tier, picked[0] + 1)
		refresh.call(), tier_row)
	vbox.add_child(info_lbl)
	refresh.call()
	vbox.add_child(row)
	var enter := _UiUtil.make_button("Enter", Vector2(vh * 0.2, vh * 0.07), font, func() -> void:
		layer.queue_free()
		SceneManager.enter_spire(rift_id, picked[0]), row)
	enter.modulate = _ACCENT
	_UiUtil.make_button("Leave", Vector2(vh * 0.16, vh * 0.07), font, layer.queue_free, row)

func _desc(vbox: VBoxContainer, text: String, vh: float) -> void:
	var lbl := _UiUtil.make_label(text, int(vh * 0.024), Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vbox)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
