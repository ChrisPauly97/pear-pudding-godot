## Stat comparison between a bag card and its deck twin (GID-180 / TID-741):
## "⚔ ▲+1  ♥ ▼-2  mana =  tier =", green when better (mana: lower is better).
## `rows()` is shared with the card detail popup; an instance floats over a
## deck tile while a twin is dragged onto it.
extends PanelContainer

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")

## [label, compare key, +1 when higher is better / -1 when lower is better]
const STATS: Array = [["⚔", "attack", 1], ["♥", "health", 1], ["mana", "cost", -1], ["tier", "rarity", 1]]
const BETTER := Color(0.45, 1.0, 0.5)
const WORSE := Color(1.0, 0.45, 0.45)
const SAME := Color(0.7, 0.7, 0.7)


static func rows(a: Dictionary, b: Dictionary, heading: String, ref: float) -> VBoxContainer:
	var vb := _UiUtil.make_vbox(int(ref * 0.004))
	_UiUtil.make_label(heading, int(ref * 0.017), Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT, vb)
	var row := _UiUtil.make_hbox(int(ref * 0.012), vb)
	var d: Dictionary = _DeckInsights.compare(a, b)
	for spec: Array in STATS:
		var v: int = int(d[str(spec[1])])
		var good: bool = v * int(spec[2]) > 0
		var text: String = "%s =" % str(spec[0]) if v == 0 \
				else "%s %s%+d" % [str(spec[0]), "▲" if good else "▼", v]
		_UiUtil.make_label(text, int(ref * 0.019), SAME if v == 0 else (BETTER if good else WORSE),
				HORIZONTAL_ALIGNMENT_LEFT, row)
	return vb


func show_over(tile: Control, held: Dictionary, deck_inst: Dictionary, ref: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.06, 0.06, 0.1, 0.95), int(ref * 0.01),
			Color(1.0, 0.85, 0.3), 2))
	for c in get_children():
		c.queue_free()
	add_child(rows(held, deck_inst, "Swap in?", ref))
	reset_size()
	var r: Rect2 = tile.get_global_rect()
	global_position = Vector2(r.position.x, r.position.y - get_combined_minimum_size().y - ref * 0.01)
