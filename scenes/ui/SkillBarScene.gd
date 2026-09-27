## GID-136 / TID-556: the skill-bar loadout picker. Tap a slot, then tap an
## ability to fill it — if that ability is already in another slot, the two
## slots swap. Reachable from the Menu Hub's "Skill Bar" tab (always
## available) and from the trainer panel's "Loadout" button
## (`NpcInteractions.show_trainer_panel`).
##
## Every change writes straight to `SaveManager.set_skill_bar()` — there is no
## separate Save step, so leaving the screen never loses a pick.
extends "res://scenes/ui/BaseOverlay.gd"

const SkillBar = preload("res://game_logic/battle/SkillBar.gd")

var hub_mode: bool = false

var _bar: Array[String] = []
var _selected_slot: int = 0
var _slot_buttons: Array[Button] = []
var _ability_grid: GridContainer

func _ready() -> void:
	super._ready()
	var sm := SceneManager.save_manager
	_bar = SkillBar.resolved_bar(sm.skill_bar, sm.learned_abilities)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var root_vbox: VBoxContainer
	if hub_mode:
		var m: int = int(_ref * 0.02)
		var margin := _UiUtil.make_margin(m, m, m, m, self)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_vbox = _UiUtil.make_vbox(int(_ref * 0.02), margin)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.9
		var panel_h: float = _vh * 0.8
		var outer := _build_centered_panel(panel_w, panel_h)
		root_vbox = _build_margin_vbox(outer, 0.03, 0.02)

	var header := _UiUtil.make_hbox(int(_vw * 0.02), root_vbox)
	var title_lbl := _UiUtil.make_label("Skill Bar", int(_ref * 0.032), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, header)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not hub_mode:
		_UiUtil.make_button("Close", Vector2(_ref * 0.16, _ref * 0.06), int(_ref * 0.02),
				func() -> void: closed.emit(), header)

	_UiUtil.make_label("Tap a slot, then tap an ability to fill it.", int(_ref * 0.02), Color(0.75, 0.75, 0.8),
			HORIZONTAL_ALIGNMENT_LEFT, root_vbox)

	var slot_row := _UiUtil.make_hbox(int(_vw * 0.02), root_vbox)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_buttons.clear()
	for i in SkillBar.SLOTS:
		var btn := _UiUtil.make_button("", Vector2(_ref * 0.24, _ref * 0.11), int(_ref * 0.02),
				_on_slot_pressed.bind(i), slot_row)
		_slot_buttons.append(btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_ability_grid = GridContainer.new()
	_ability_grid.columns = 2 if _vw < _vh else 3
	_ability_grid.add_theme_constant_override("h_separation", int(_vw * 0.02))
	_ability_grid.add_theme_constant_override("v_separation", int(_ref * 0.015))
	scroll.add_child(_ability_grid)

func _on_slot_pressed(slot: int) -> void:
	_selected_slot = slot
	_refresh()

## Assigning an already-slotted ability swaps the two slots instead of
## duplicating it — the bar has no room for the same ability twice.
func _on_ability_pressed(id: String) -> void:
	var existing: int = _bar.find(id)
	if existing == _selected_slot:
		return
	if existing >= 0:
		_bar[existing] = _bar[_selected_slot]
	_bar[_selected_slot] = id
	SceneManager.save_manager.set_skill_bar(_bar)
	_refresh()

func _refresh() -> void:
	var sm := SceneManager.save_manager
	for i in _slot_buttons.size():
		var a: Dictionary = SkillBar.def(_bar[i])
		_slot_buttons[i].text = "Slot %d\n%s" % [i + 1, str(a.get("name", "—"))]
		_slot_buttons[i].modulate = Color(1.0, 0.85, 0.3) if i == _selected_slot else Color.WHITE

	for child: Node in _ability_grid.get_children():
		child.queue_free()
	for id: String in SkillBar.known_ids(sm.learned_abilities):
		_ability_grid.add_child(_make_ability_button(id))

func _make_ability_button(id: String) -> Control:
	var a: Dictionary = SkillBar.def(id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_ref * 0.4, 0)
	var vbox := _UiUtil.make_vbox(int(_ref * 0.006), panel)
	var name_lbl := _UiUtil.make_label(str(a.get("name", id)), int(_ref * 0.022), Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, vbox)
	var desc_lbl := _UiUtil.make_label(str(a.get("desc", "")), int(_ref * 0.016), Color(0.75, 0.75, 0.8),
			HORIZONTAL_ALIGNMENT_LEFT, vbox)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var slot_here: int = _bar.find(id)
	var btn := _UiUtil.make_button("On the bar" if slot_here >= 0 else "Slot it", Vector2(0, _ref * 0.05),
			int(_ref * 0.018), _on_ability_pressed.bind(id), vbox)
	if slot_here == _selected_slot:
		btn.disabled = true
	return panel
