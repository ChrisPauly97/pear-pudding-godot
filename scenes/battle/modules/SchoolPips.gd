## Enemy school pips (GID-181 / TID-752): a row of small chips under an enemy's hero
## strip, one per school its profile tags. Weak = filled in the school's colour,
## Resists = dark with a coloured rim, Immune = thick rim. Hover shows the tooltip on
## desktop; a tap (or click) reports the same line through `on_tap`, so mobile gets it too.
## Only the schools the player has learned show pips (TID-753): `entry` is the enemy's
## bestiary entry, and a defeat reveals the profile (see game_logic/battle/SchoolKnowledge.gd).
extends RefCounted

const _SchoolFeedback = preload("res://game_logic/battle/SchoolFeedback.gd")
const _SchoolKnowledge = preload("res://game_logic/battle/SchoolKnowledge.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _DARK_FILL: Color = Color(0.08, 0.08, 0.12, 0.95)
const _WEAK_TEXT: Color = Color(0.08, 0.06, 0.1)

## The profile whose pips an enemy type shows: its full profile once the player has
## defeated that type (per `entry`, its bestiary entry), else empty.
static func known_profile(enemy_type: String, entry: Dictionary) -> Dictionary:
	return _SchoolKnowledge.known_profile(_EnemyRegistry.get_school_profile(enemy_type), entry)

## Builds the pip row for `enemy_type` into `parent` (empty row for "" or a neutral
## enemy). `entry` is the enemy's bestiary entry. `vh` sizes the chips; `on_tap(text: String)`
## receives the tooltip line.
static func build(enemy_type: String, entry: Dictionary, parent: Control, vh: float,
		on_tap: Callable) -> HBoxContainer:
	var row: HBoxContainer = _UiUtil.make_hbox(int(vh * 0.004), parent)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if enemy_type == "":
		return row
	var chip_px: float = vh * 0.034
	for pip: Dictionary in _SchoolFeedback.pips_for(known_profile(enemy_type, entry)):
		var school: String = str(pip["school"])
		var outcome: String = str(pip["outcome"])
		var line: String = _SchoolFeedback.pip_tooltip(school, outcome)
		var tint: Color = _SchoolFeedback.school_color(school)
		# make_button adds the chip to `row` itself.
		var chip: Button = _UiUtil.make_button(school.substr(0, 1).to_upper(), Vector2(chip_px, chip_px),
				int(vh * 0.02), func() -> void: on_tap.call(line), row)
		chip.tooltip_text = line
		chip.focus_mode = Control.FOCUS_NONE
		_style_chip(chip, outcome, tint, vh)
	return row

static func _style_chip(chip: Button, outcome: String, tint: Color, vh: float) -> void:
	var fill: Color = tint if outcome == "weak" else _DARK_FILL
	var rim: int = maxi(1, int(vh * 0.003)) if outcome != "immune" else maxi(2, int(vh * 0.006))
	var box := _UiUtil.make_style(fill, 4, tint, rim)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		chip.add_theme_stylebox_override(state, box)
	var text_col: Color = _WEAK_TEXT if outcome == "weak" else tint
	chip.add_theme_color_override("font_color", text_col)
	chip.add_theme_color_override("font_hover_color", text_col)
	chip.add_theme_color_override("font_pressed_color", text_col)
