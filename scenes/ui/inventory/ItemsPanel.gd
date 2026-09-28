## Items tab of the backpack (GID-144): everything in the bag that isn't a
## card — brewed potions and garden herbs — with a count, what it does and
## where it comes from, so nothing in the bag is a mystery.
extends VBoxContainer

const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

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

	_header("Potions  ·  one per battle, from the potion button")
	for potion_id: String in GardenDefs.POTIONS:
		var info: Dictionary = GardenDefs.POTIONS[potion_id]
		_row(str(info.get("display_name", potion_id)), int(sm.potions.get(potion_id, 0)),
				str(info.get("description", "")), Color(0.55, 0.8, 1.0))

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

func _row(title: String, count: int, desc: String, tint: Color) -> void:
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
