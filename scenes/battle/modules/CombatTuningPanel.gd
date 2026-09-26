## In-battle combat tuning panel (GID-135 / TID-549): every CombatTuning knob
## with − / + buttons, grouped, plus Reset. Edits apply to the running fight
## at once (the clock is paused while the panel is open — it joins the modal
## group) and persist in the "combat_tuning" setting.
##
## Opened from the real-time battle's "Tune" button (or the T key on desktop).
extends "res://scenes/ui/BaseOverlay.gd"

const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _TutorialPopup = preload("res://scenes/ui/TutorialPopup.gd")

var _tune: CombatTuning
## Called after every change (BattleRealtime.save_tuning).
var _on_change: Callable = Callable()
var _value_labels: Dictionary = {}

func setup(tune: CombatTuning, on_change: Callable) -> void:
	_tune = tune
	_on_change = on_change

func _ready() -> void:
	super._ready()
	add_to_group(_TutorialPopup.MODAL_GROUP)
	_build_ui()

func _build_ui() -> void:
	_value_labels.clear()
	_build_backdrop(0.7)
	var panel := _build_centered_panel(_vw * 0.62, _vh * 0.86)
	var vbox := _build_margin_vbox(panel, 0.02, 0.01)
	var title := _UiUtil.make_title_label("Combat Tuning", _vh)
	vbox.add_child(title)
	_UiUtil.make_label("Changes apply to this fight straight away and are saved on this device.",
			int(_vh * 0.018), Color(0.75, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var scroll := _build_scroll(vbox)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := _UiUtil.make_vbox(int(_vh * 0.006), scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group: String = ""
	for row: Array in CombatTuning.DEFS:
		if str(row[6]) != group:
			group = str(row[6])
			_UiUtil.make_label(group, int(_vh * 0.024), Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_LEFT, list)
		_build_row(list, str(row[0]), str(row[1]))
	var buttons := _UiUtil.make_hbox(int(_vh * 0.02), vbox)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var bsize := Vector2(_vh * 0.18, _vh * 0.06)
	_UiUtil.make_button("Reset all", bsize, int(_vh * 0.022), _reset_all, buttons)
	_UiUtil.make_button("Close", bsize, int(_vh * 0.022), _close, buttons)

func _build_row(list: VBoxContainer, key: String, label: String) -> void:
	var h := _UiUtil.make_hbox(int(_vh * 0.01), list)
	var name_lbl := _UiUtil.make_label(label, int(_vh * 0.021), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, h)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sq := Vector2(_vh * 0.06, _vh * 0.055)
	_UiUtil.make_button("−", sq, int(_vh * 0.026), func() -> void: _nudge(key, -1), h)
	var val := _UiUtil.make_label("", int(_vh * 0.022), Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, h)
	val.custom_minimum_size = Vector2(_vh * 0.12, 0.0)
	_value_labels[key] = val
	_UiUtil.make_button("+", sq, int(_vh * 0.026), func() -> void: _nudge(key, 1), h)
	_show(key)

func _nudge(key: String, steps: int) -> void:
	_tune.nudge(key, steps)
	_show(key)
	if _on_change.is_valid():
		_on_change.call()

func _reset_all() -> void:
	_tune.reset()
	for key: Variant in _value_labels.keys():
		_show(str(key))
	if _on_change.is_valid():
		_on_change.call()

## Shows a knob's value; changed knobs are highlighted.
func _show(key: String) -> void:
	var lbl: Label = _value_labels.get(key) as Label
	if lbl == null:
		return
	var row: Array = CombatTuning.row_for(key)
	var step: float = float(row[5])
	var v: float = _tune.get_f(key)
	lbl.text = str(roundi(v)) if is_equal_approx(step, roundf(step)) else "%.2f" % v
	var changed: bool = not is_equal_approx(v, float(row[2]))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4) if changed else Color(0.6, 0.85, 1.0))
