## Crafting station panel (GID-182 / TID-762): one overlay for every profession,
## opened from a station in the world (modules/CraftingStations.gd). Header with the
## profession's level and XP bar; then each recipe with its difficulty colour
## (orange / yellow / green / grey, or red when locked), its inputs with owned
## counts, and Craft x1 / Craft x All. A recipe whose skill or inputs are missing is
## greyed and its buttons disabled. Esc or Close dismisses it.
##
## `setup(profession, save)` before it enters the tree. Crafting goes through
## `craft_recipe()`, which drives SaveProfessions.craft(). Headless callers (tests)
## call `_build_ui()` directly, since the unit runner never enters the tree.
extends "res://scenes/ui/BaseOverlay.gd"

const _ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const _SaveManager = preload("res://autoloads/SaveManager.gd")

const PANEL_W_FRAC: float = 0.7
const PANEL_H_FRAC: float = 0.8
const PANEL_BG := Color(0.06, 0.07, 0.1, 0.97)
## Upper bound on Craft x All, so a malformed recipe can never loop forever.
const MAX_CRAFT_ALL: int = 999
## Headless fallback viewport, used only while the panel is outside the tree.
const _HEADLESS_VIEW := Vector2(1280.0, 720.0)

var _profession: String = ""
var _save: _SaveManager = null


func setup(profession: String, save: _SaveManager) -> void:
	_profession = profession
	_save = save


func _ready() -> void:
	super._ready()
	_build_ui()


func _refresh_metrics() -> void:
	if is_inside_tree():
		super._refresh_metrics()
		return
	_vw = _HEADLESS_VIEW.x
	_vh = _HEADLESS_VIEW.y
	_ref = minf(_vh, _vw)


func _build_ui() -> void:
	_build_backdrop(0.72, true)
	var panel: PanelContainer = _UiUtil.make_centered_panel(_vw * PANEL_W_FRAC, _vh * PANEL_H_FRAC, _vw, _vh, self)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(PANEL_BG, 12, Color(0.4, 0.4, 0.6, 0.7), 2))
	var vbox: VBoxContainer = _build_margin_vbox(panel, 0.025, 0.01)
	var font_body: int = int(_vh * 0.026)
	var btn_h: float = _vh * 0.058

	var prof: Dictionary = _ProfessionDefs.PROFESSIONS.get(_profession, {})
	_build_header(vbox, prof, font_body)

	var scroll: ScrollContainer = _build_scroll(vbox)
	var list: VBoxContainer = _UiUtil.make_vbox(int(_vh * 0.012), scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in _ProfessionDefs.recipes_for(_profession):
		_build_recipe_row(id, list, font_body, btn_h)

	vbox.add_child(_UiUtil.make_close_button(_vh, _close))


## Profession name, level line and the XP bar to the next level.
func _build_header(vbox: VBoxContainer, prof: Dictionary, font_body: int) -> void:
	var tint: Color = prof.get("color", Color.WHITE) as Color
	var title: Label = _UiUtil.make_title_label(str(prof.get("display_name", _profession)), _vh)
	title.modulate = tint
	vbox.add_child(title)
	var lv: int = _level()
	var xp: int = _save.professions.xp(_profession) if _save != null else 0
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, _vh * 0.025)
	if lv >= _ProfessionDefs.MAX_LEVEL:
		vbox.add_child(_UiUtil.make_label("Level %d (max)" % lv, font_body, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = 1.0
	else:
		var lo: int = _ProfessionDefs.xp_for_level(lv)
		var hi: int = _ProfessionDefs.xp_for_level(lv + 1)
		vbox.add_child(_UiUtil.make_label("Level %d  -  XP %d / %d" % [lv, xp, hi], font_body))
		bar.min_value = 0.0
		bar.max_value = float(hi - lo)
		bar.value = float(xp - lo)
	vbox.add_child(bar)


func _build_recipe_row(id: String, list: VBoxContainer, font_body: int, btn_h: float) -> void:
	var r: Dictionary = _ProfessionDefs.def(id)
	var lv: int = _level()
	var band: String = _ProfessionDefs.band(id, lv)
	var reason: String = _save.professions.craft_block(id) if _save != null else "unknown"
	var row := _UiUtil.make_vbox(int(_vh * 0.005), list)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if reason == "skill" or reason == "inputs" or reason == "unknown" or reason == "unsupported":
		row.modulate = Color(1.0, 1.0, 1.0, 0.5)

	var gained: int = _ProfessionDefs.recipe_xp(id, lv)
	var band_col: Color = _ProfessionDefs.BAND_COLORS.get(band, Color.WHITE) as Color
	_UiUtil.make_label("%s   (skill %d, +%d XP)" % [str(r.get("display_name", id)), int(r.get("skill_req", 1)),
		gained], font_body, band_col, HORIZONTAL_ALIGNMENT_LEFT, row)

	var inputs_row := _UiUtil.make_hbox(int(_vh * 0.02), row)
	var inputs: Dictionary = _save.professions.inputs_for(id) if _save != null else r.get("inputs", {})
	for input_id: String in inputs:
		var need: int = int(inputs[input_id])
		var have: int = _save.professions.count(input_id) if _save != null else 0
		var short: bool = have < need
		var tint: Color = Color(0.95, 0.4, 0.4) if short else Color(0.85, 0.9, 0.85)
		_UiUtil.make_label("%s %d/%d" % [_ProfessionDefs.input_name(input_id), have, need], font_body, tint,
			HORIZONTAL_ALIGNMENT_LEFT, inputs_row)

	var btns := _UiUtil.make_hbox(int(_vh * 0.015), row)
	var btn_w: float = _vh * 0.2
	var one: Button = _UiUtil.make_button("Craft x1", Vector2(btn_w, btn_h), font_body,
		func() -> void: craft_recipe(id, false), btns)
	var all: Button = _UiUtil.make_button("Craft x All", Vector2(btn_w, btn_h), font_body,
		func() -> void: craft_recipe(id, true), btns)
	one.disabled = reason != ""
	all.disabled = reason != ""


## Crafts `recipe_id` once, or as often as the inputs allow when `all`. Returns the
## number of crafts made, reports the outcome on the HUD and rebuilds the panel.
func craft_recipe(recipe_id: String, all: bool) -> int:
	if _save == null:
		return 0
	var made: int = 0
	var limit: int = MAX_CRAFT_ALL if all else 1
	var output_name: String = str(_ProfessionDefs.def(recipe_id).get("display_name", recipe_id))
	while made < limit:
		var res: Dictionary = _save.professions.craft(recipe_id)
		if not bool(res.get("ok", false)):
			if made == 0:
				GameBus.hud_message_requested.emit(_block_text(str(res.get("reason", ""))))
			break
		made += 1
	if made > 0:
		GameBus.hud_message_requested.emit("Crafted %d x %s." % [made, output_name])
	if is_inside_tree():
		_rebuild_ui()
	return made


func _block_text(reason: String) -> String:
	match reason:
		"skill":
			return "Your %s skill is too low for that." % _ProfessionDefs.PROFESSIONS[_profession]["display_name"]
		"inputs":
			return "You are missing ingredients."
	return "That cannot be crafted."


func _level() -> int:
	return _save.professions.level(_profession) if _save != null else 1
