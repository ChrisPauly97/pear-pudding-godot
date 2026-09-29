## Items tab of the backpack (GID-148): everything in the bag that isn't a
## card — brewed potions and garden herbs — with a count, what it does and
## where it comes from, so nothing in the bag is a mystery. Potions can be put
## on the Q / E battle quick slots from here (TID-542).
extends VBoxContainer

const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _QuickSlots = preload("res://game_logic/battle/QuickSlots.gd")

var _ref: float = 0.0
var _list: VBoxContainer

func setup(ref: float) -> void:
	_ref = ref
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = _UiUtil.make_vbox(int(_ref * 0.008), scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func refresh() -> void:
	var sm := SceneManager.save_manager
	for child in _list.get_children():
		child.queue_free()

	_header("Potions  ·  drink in battle from the Q / E quick slots (shared cooldown)")
	var slotted: Array[String] = _QuickSlots.resolve(sm.quick_slots, sm.potions)
	for potion_id: String in GardenDefs.POTIONS:
		var info: Dictionary = GardenDefs.POTIONS[potion_id]
		var count: int = int(sm.potions.get(potion_id, 0))
		var row := _row(str(info.get("display_name", potion_id)), count,
				str(info.get("description", "")), Color(0.55, 0.8, 1.0))
		if count <= 0:
			continue
		for i: int in _QuickSlots.SLOTS:
			var on: bool = slotted[i] == potion_id
			var btn := _UiUtil.make_button(("● " if on else "") + _QuickSlots.KEY_LABELS[i],
					Vector2(_ref * 0.07, _ref * 0.05), int(_ref * 0.018), _on_slot.bind(i, potion_id), row)
			btn.tooltip_text = "Put on quick slot %s" % _QuickSlots.KEY_LABELS[i]
			btn.disabled = on

	_header("Herbs  ·  grown in your home garden, brewed on the Craft tab")
	for plant_id: String in GardenDefs.PLANTS:
		var info: Dictionary = GardenDefs.PLANTS[plant_id]
		var used_in: Array[String] = []
		for potion_id: String in GardenDefs.POTION_RECIPES:
			var recipe: Dictionary = GardenDefs.POTION_RECIPES[potion_id]
			var ingredients: Dictionary = recipe.get("ingredients", {})
			if ingredients.has(plant_id):
				used_in.append(str(recipe.get("display_name", potion_id)))
		var text: String = str(info.get("description", ""))
		if not used_in.is_empty():
			text += "  Used in: %s." % ", ".join(used_in)
		_row(str(info.get("display_name", plant_id)), int(sm.plants.get(plant_id, 0)), text, Color(0.6, 0.95, 0.5))

	var hint := _UiUtil.make_label("Gear lives on the Character tab.", int(_ref * 0.017), Color(0.6, 0.6, 0.6),
			HORIZONTAL_ALIGNMENT_CENTER, _list)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _header(text: String) -> void:
	var lbl := _UiUtil.make_label(text, int(_ref * 0.021), Color(0.85, 0.78, 0.55), HORIZONTAL_ALIGNMENT_LEFT, _list)
	lbl.theme_type_variation = &"TitleLabel"

func _row(title: String, count: int, desc: String, tint: Color) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.1, 0.1, 0.14, 0.85), int(_ref * 0.010),
			tint.darkened(0.5) if count > 0 else Color(0.25, 0.25, 0.3), 1))
	panel.modulate = Color.WHITE if count > 0 else Color(0.65, 0.65, 0.65)
	_list.add_child(panel)
	var m: int = int(_ref * 0.008)
	var row := _UiUtil.make_hbox(int(_ref * 0.012), _UiUtil.make_margin(m, m, m, m, panel))

	var badge := _UiUtil.make_label("×%d" % count, int(_ref * 0.024), tint, HORIZONTAL_ALIGNMENT_CENTER, row)
	badge.custom_minimum_size = Vector2(_ref * 0.07, 0.0)
	var info := _UiUtil.make_vbox(0, row)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_UiUtil.make_label(title, int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, info)
	var d := _UiUtil.make_label(desc, int(_ref * 0.017), Color(0.72, 0.72, 0.72), HORIZONTAL_ALIGNMENT_LEFT, info)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return row


func _on_slot(slot: int, potion_id: String) -> void:
	var sm := SceneManager.save_manager
	sm.quick_slots = _QuickSlots.assign(sm.quick_slots, slot, potion_id)
	sm.mark_dirty()
	refresh()
