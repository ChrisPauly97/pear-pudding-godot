## Craft tab of the backpack (GID-144; split out of InventoryScene). Each
## recipe row shows what the card actually is — cost gem, class, rolled-base
## stats, rules text and how many you already own — with the essence price on
## the Craft button itself. Potion rows show have/need per ingredient.
extends VBoxContainer

## Fired after anything is crafted, so the owner can refresh its wallet line.
signal crafted

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const CraftingRegistry = preload("res://autoloads/CraftingRegistry.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const BagOps = preload("res://game_logic/inventory/BagOps.gd")
const _CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const _CraftingRecipe = preload("res://data/CraftingRecipe.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _ESSENCE := Color(0.5, 0.85, 1.0)
const _GOOD := Color(0.55, 1.0, 0.6)
const _BAD := Color(1.0, 0.45, 0.45)

var _ref: float = 0.0
var _rarity: String = "common"
var _query: String = ""
var _status: Label
var _rarity_row: HBoxContainer
var _list: VBoxContainer

func setup(ref: float) -> void:
	_ref = ref
	add_theme_constant_override("separation", int(_ref * 0.008))
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var top := _UiUtil.make_hbox(int(_ref * 0.010), self)
	_rarity_row = _UiUtil.make_hbox(int(_ref * 0.004), top)
	var search := LineEdit.new()
	search.placeholder_text = "Search recipes…"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size = Vector2(_ref * 0.2, _ref * 0.055)
	search.add_theme_font_size_override("font_size", int(_ref * 0.020))
	search.text_changed.connect(func(t: String) -> void:
		_query = t
		refresh())
	top.add_child(search)

	_status = _UiUtil.make_label("", int(_ref * 0.020), _GOOD, HORIZONTAL_ALIGNMENT_CENTER, self)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = _UiUtil.make_vbox(int(_ref * 0.006), scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func refresh() -> void:
	var sm := SceneManager.save_manager
	for child in _list.get_children():
		child.queue_free()
	for child in _rarity_row.get_children():
		child.queue_free()
	for rarity: String in IsoConst.RARITY_ORDER:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var btn := _UiUtil.make_button("%s %de" % [rarity.capitalize(), int(cfg.get("craft_essence", 0))],
				Vector2(_ref * 0.15, _ref * 0.055), int(_ref * 0.018), _select_rarity.bind(rarity), _rarity_row)
		btn.modulate = _UiUtil.rarity_color(rarity) if rarity == _rarity else Color(0.5, 0.5, 0.5)

	var owned: Dictionary = {}   # template_id -> count
	for inst: Dictionary in sm.get_owned_instances():
		var tid: String = str(inst.get("template_id", ""))
		owned[tid] = int(owned.get(tid, 0)) + 1

	var recipes: Array[_CraftingRecipe] = []
	for recipe: _CraftingRecipe in CraftingRegistry.get_all_recipes():
		if str(recipe.rarity) == _rarity \
				and BagOps.matches_search(CardRegistry.get_template(str(recipe.template_id)), _query):
			recipes.append(recipe)
	recipes.sort_custom(func(a: _CraftingRecipe, b: _CraftingRecipe) -> bool:
		var ta: Dictionary = CardRegistry.get_template(str(a.template_id))
		var tb: Dictionary = CardRegistry.get_template(str(b.template_id))
		if int(ta.get("cost", 0)) != int(tb.get("cost", 0)):
			return int(ta.get("cost", 0)) < int(tb.get("cost", 0))
		return str(ta.get("name", "")) < str(tb.get("name", "")))

	_header("Cards  ·  crafted cards land in your bag")
	var bag_full: bool = sm.is_bag_full()
	for recipe: _CraftingRecipe in recipes:
		_list.add_child(_card_row(recipe, sm.essence, int(owned.get(str(recipe.template_id), 0)), bag_full))
	if recipes.is_empty():
		_UiUtil.make_label("No recipes match", int(_ref * 0.020), Color(0.6, 0.6, 0.6),
				HORIZONTAL_ALIGNMENT_CENTER, _list)

	_header("Potions  ·  brewed from garden herbs")
	for potion_id: String in GardenDefs.POTION_RECIPES:
		var data: Dictionary = GardenDefs.POTION_RECIPES[potion_id]
		if _query == "" or str(data.get("display_name", "")).to_lower().contains(_query.strip_edges().to_lower()):
			_list.add_child(_potion_row(potion_id, data, sm.essence))

func _select_rarity(rarity: String) -> void:
	_rarity = rarity
	refresh()

func _header(text: String) -> void:
	var lbl := _UiUtil.make_label(text, int(_ref * 0.021), Color(0.85, 0.78, 0.55), HORIZONTAL_ALIGNMENT_LEFT, _list)
	lbl.theme_type_variation = &"TitleLabel"

func _row_panel() -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.1, 0.1, 0.14, 0.85), int(_ref * 0.010),
			Color(0.3, 0.3, 0.38), 1))
	var m: int = int(_ref * 0.008)
	var margin := _UiUtil.make_margin(m, m, m, m, panel)
	var row := _UiUtil.make_hbox(int(_ref * 0.012), margin)
	return [panel, row]

func _card_row(recipe: _CraftingRecipe, essence: int, owned: int, bag_full: bool) -> Control:
	var tid: String = str(recipe.template_id)
	var rarity: String = str(recipe.rarity)
	var cost: int = int(recipe.essence_cost)
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	var parts: Array = _row_panel()
	var row: HBoxContainer = parts[1]

	var gem := _UiUtil.make_label(str(int(tmpl.get("cost", 0))), int(_ref * 0.022), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, row)
	gem.custom_minimum_size = Vector2(_ref * 0.045, _ref * 0.045)
	gem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem.add_theme_stylebox_override("normal", _UiUtil.make_style(Color(0.2, 0.4, 0.8), int(_ref * 0.0225),
			tmpl.get("color", Color.GRAY), 2))

	var info := _UiUtil.make_vbox(0, row)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := _UiUtil.make_hbox(int(_ref * 0.008), info)
	_UiUtil.make_label(str(tmpl.get("name", tid)), int(_ref * 0.022), _UiUtil.rarity_color(rarity),
			HORIZONTAL_ALIGNMENT_LEFT, head)
	var is_spell: bool = str(tmpl.get("card_class", "minion")) == "spell"
	var kind: String = "Spell" if is_spell else "Minion  ⚔%d ♥%d" % [int(tmpl.get("attack", 0)),
			int(tmpl.get("health", 0))]
	_UiUtil.make_label(kind, int(_ref * 0.018), Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_LEFT, head)
	var desc := _UiUtil.make_label(str(tmpl.get("description", "")), int(_ref * 0.017), Color(0.7, 0.7, 0.7),
			HORIZONTAL_ALIGNMENT_LEFT, info)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_UiUtil.make_label("Owned ×%d" % owned, int(_ref * 0.017), Color(0.8, 0.8, 0.8) if owned > 0 else Color(0.5, 0.5,
			0.5), HORIZONTAL_ALIGNMENT_RIGHT, row)
	var btn := _UiUtil.make_button("Craft  %de" % cost, Vector2(_ref * 0.15, _ref * 0.06), int(_ref * 0.020),
			_do_craft.bind(tid, rarity, cost), row)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.disabled = essence < cost or bag_full
	btn.tooltip_text = "Bag is full" if bag_full else ("Need %d more essence" % (cost - essence) if essence < cost
			else "Crafts a fresh %s copy with rolled stats" % rarity)
	return parts[0]

func _do_craft(template_id: String, rarity: String, cost: int) -> void:
	var sm := SceneManager.save_manager
	# Check the bag before spending: add_card_instance refuses on a full bag and
	# the essence would otherwise be gone with nothing to show for it.
	if sm.is_bag_full():
		_flash("Bag is full — free a slot first", _BAD)
		return
	if not sm.spend_essence(cost):
		return
	var stats: Dictionary = _CardDropUtil.roll_stats(template_id, rarity)
	var uid: String = sm.add_card_instance(template_id, rarity, int(stats.get("attack", -1)),
			int(stats.get("health", -1)), int(stats.get("cost", -1)))
	if uid == "":
		sm.essence += cost
		GameBus.essence_changed.emit(sm.essence)
		_flash("Bag is full — free a slot first", _BAD)
		return
	var nm: String = str(CardRegistry.get_template(template_id).get("name", template_id))
	_flash("Crafted %s (%s)" % [nm, rarity.capitalize()], _GOOD)
	crafted.emit()
	refresh()

func _potion_row(potion_id: String, data: Dictionary, essence: int) -> Control:
	var sm := SceneManager.save_manager
	var ess_cost: int = int(data.get("essence_cost", 0))
	var ingredients: Dictionary = data.get("ingredients", {})
	var parts: Array = _row_panel()
	var row: HBoxContainer = parts[1]

	var info := _UiUtil.make_vbox(0, row)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pinfo: Dictionary = GardenDefs.POTIONS.get(potion_id, {})
	_UiUtil.make_label("%s   (have %d)" % [str(data.get("display_name", potion_id)), int(sm.potions.get(potion_id, 0))],
			int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, info)
	_UiUtil.make_label(str(pinfo.get("description", "")), int(_ref * 0.017), Color(0.7, 0.7, 0.7),
			HORIZONTAL_ALIGNMENT_LEFT, info)
	var needs := _UiUtil.make_hbox(int(_ref * 0.010), info)
	var have_all: bool = true
	for ing: String in ingredients:
		var need: int = int(ingredients[ing])
		var have: int = int(sm.plants.get(ing, 0))
		have_all = have_all and have >= need
		var nm: String = str((GardenDefs.PLANTS.get(ing, {}) as Dictionary).get("display_name", ing))
		_UiUtil.make_label("%s %d/%d" % [nm, have, need], int(_ref * 0.018), _GOOD if have >= need else _BAD,
				HORIZONTAL_ALIGNMENT_LEFT, needs)

	var btn := _UiUtil.make_button("Brew  %de" % ess_cost, Vector2(_ref * 0.15, _ref * 0.06), int(_ref * 0.020),
			_do_craft_potion.bind(potion_id, ess_cost, ingredients), row)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.disabled = not have_all or essence < ess_cost
	return parts[0]

func _do_craft_potion(potion_id: String, ess_cost: int, ingredients: Dictionary) -> void:
	var sm := SceneManager.save_manager
	for ing: String in ingredients:
		if not sm.garden.remove_plants(ing, int(ingredients[ing])):
			return
	if not sm.spend_essence(ess_cost):
		for ing: String in ingredients:
			sm.garden.add_plants(ing, int(ingredients[ing]))
		return
	sm.garden.add_potions(potion_id, 1)
	GameBus.potion_crafted.emit(potion_id)
	var pdata: Dictionary = GardenDefs.POTION_RECIPES.get(potion_id, {})
	_flash("Brewed %s" % str(pdata.get("display_name", potion_id)), _GOOD)
	crafted.emit()
	refresh()

func _flash(text: String, tint: Color) -> void:
	_status.text = text
	_status.modulate = tint
