## Deck identity row (GID-180 / TID-740): a crest, the generated deck name and
## the mana-curve skyline. The name re-rolls as cards change, so experimenting
## is visible at a glance.
extends HBoxContainer

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")
const _CardJuice = preload("res://scenes/ui/inventory/CardJuice.gd")
const _CurveSkyline = preload("res://scenes/ui/inventory/CurveSkyline.gd")

const GLYPHS: Dictionary = {
	"swarm": "❖", "tempo": "»", "titans": "♜", "grimoire": "✎", "bulwark": "◈", "rush": "⚡", "host": "✦",
}

var _crest: PanelContainer
var _glyph: Label
var _name: Label
var _skyline: _CurveSkyline
var _ref: float = 0.0
var _last_name: String = ""


func setup(ref: float) -> void:
	_ref = ref
	add_theme_constant_override("separation", int(ref * 0.01))
	_crest = PanelContainer.new()
	_crest.custom_minimum_size = Vector2(ref * 0.06, ref * 0.06)
	add_child(_crest)
	_glyph = _UiUtil.make_label("", int(ref * 0.03), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, _crest)
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name = _UiUtil.make_label("", int(ref * 0.026), Color(1.0, 0.9, 0.65), HORIZONTAL_ALIGNMENT_LEFT, self)
	_name.theme_type_variation = &"TitleLabel"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_skyline = _CurveSkyline.new()
	_skyline.custom_minimum_size = Vector2(ref * 0.2, ref * 0.06)
	add_child(_skyline)


func update(insts: Array[Dictionary]) -> void:
	var deck_name: String = _DeckInsights.deck_name(insts)
	var crest: Dictionary = _DeckInsights.crest(insts)
	var col: Color = crest["color"]
	_crest.add_theme_stylebox_override("panel", _UiUtil.make_style(col.darkened(0.55), int(_ref * 0.03),
			_UiUtil.rarity_color(str(crest["rarity"])), maxi(2, int(_ref * 0.004))))
	_glyph.text = str(GLYPHS.get(str(crest["glyph"]), "✦"))
	_glyph.modulate = col.lightened(0.3)
	_name.text = deck_name
	_name.tooltip_text = "Your deck's name changes with what's in it"
	_skyline.tint = col.lerp(Color(0.85, 0.75, 0.45), 0.4)
	_skyline.set_curve(_DeckInsights.mana_curve(insts))
	if _last_name != "" and deck_name != _last_name:
		_CardJuice.pop(_crest, 0.3)
		_CardJuice.sparkle(_crest, str(crest["rarity"]), _ref)
	_last_name = deck_name
