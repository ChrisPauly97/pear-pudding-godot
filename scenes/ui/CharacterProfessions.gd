## Professions block of the Character screen (GID-182 / TID-766). One card per
## profession: name in its colour, level and XP bar to the next level, and how many
## of its recipes are known (any recipe the level has reached, locked ones excluded).
## A profession not yet learned from the Master Artisan shows where to learn it
## instead. `build()` adds the block to `parent` and returns it; no scene tree needed
## beyond that. Pure reads of SaveProfessions and ProfessionDefs.
extends RefCounted

const _ProfessionDefs = preload("res://game_logic/professions/ProfessionDefs.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _SaveManager = preload("res://autoloads/SaveManager.gd")


static func build(parent: Control, save: _SaveManager, vh: float) -> VBoxContainer:
	var box: VBoxContainer = _UiUtil.make_vbox(int(vh * 0.008), parent)
	_UiUtil.make_label("Professions", int(vh * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, box)
	for prof: String in _ProfessionDefs.PROFESSIONS:
		_add_card(prof, save, vh, box)
	return box


static func _add_card(prof: String, save: _SaveManager, vh: float, box: VBoxContainer) -> void:
	var info: Dictionary = _ProfessionDefs.PROFESSIONS[prof]
	var tint: Color = info.get("color", Color.WHITE) as Color
	var font: int = int(vh * 0.02)
	var name_lbl: Label = _UiUtil.make_label(str(info.get("display_name", prof)), int(vh * 0.022), tint,
			HORIZONTAL_ALIGNMENT_LEFT, box)
	name_lbl.theme_type_variation = &"TitleLabel"
	var feature: String = _UnlockLadder.profession_feature(prof)
	if feature != "" and not save.has_learned(feature):
		var hint: Label = _UiUtil.make_label(_UnlockLadder.station_block(prof, save.learned_abilities), font,
				Color(0.6, 0.6, 0.65), HORIZONTAL_ALIGNMENT_LEFT, box)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var lv: int = save.professions.level(prof)
	var xp: int = save.professions.xp(prof)
	if lv >= _ProfessionDefs.MAX_LEVEL:
		_UiUtil.make_label("Level %d (max)" % lv, font, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, box)
	else:
		var lo: int = _ProfessionDefs.xp_for_level(lv)
		var hi: int = _ProfessionDefs.xp_for_level(lv + 1)
		_UiUtil.make_label("Level %d  -  XP %d / %d" % [lv, xp, hi], font, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, box)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, vh * 0.018)
		bar.min_value = float(lo)
		bar.max_value = float(hi)
		bar.value = float(xp)
		box.add_child(bar)
	var known: int = 0
	var total: int = 0
	for id: String in _ProfessionDefs.recipes_for(prof):
		total += 1
		if _ProfessionDefs.band(id, lv) != "locked":
			known += 1
	_UiUtil.make_label("Recipes known: %d / %d" % [known, total], font, Color(0.8, 0.8, 0.85),
			HORIZONTAL_ALIGNMENT_LEFT, box)
