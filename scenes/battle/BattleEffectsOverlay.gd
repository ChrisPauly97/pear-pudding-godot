## Lists every modifier active in this battle — battlefield rule, day/night,
## weather, gambit, hero power, passives, equipment, companion, ambush — with
## its description. Opened from the side panel "Effects" button (or by tapping
## the battlefield label / gambit badge), so a banner that faded away can
## always be re-read.
extends "res://scenes/ui/BaseOverlay.gd"

var _entries: Array[Dictionary] = []

## Adds the overlay on top of `host`. Each entry is {title, desc, color}.
func present(host: Node, entries: Array[Dictionary], on_closed: Callable) -> void:
	_entries = entries
	host.add_child(self)
	host.move_child(self, host.get_child_count() - 1)
	closed.connect(on_closed)
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72, true)
	var panel := _build_centered_panel(minf(_vw * 0.7, _vh * 1.1), _vh * 0.78)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())
	var inner := _build_margin_vbox(panel, 0.025, 0.014)
	var title := _UiUtil.make_label("Battle Effects", int(_vh * 0.032), Color(1.0, 0.85, 0.4),
			HORIZONTAL_ALIGNMENT_CENTER, inner)
	title.name = "Title"
	var scroll := _build_scroll(inner)
	var list := _UiUtil.make_vbox(int(_vh * 0.016), scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _entries.is_empty():
		_UiUtil.make_label("No special effects are active.", int(_vh * 0.022), Color(0.8, 0.8, 0.85),
				HORIZONTAL_ALIGNMENT_CENTER, list)
	for e: Dictionary in _entries:
		var row := _UiUtil.make_vbox(int(_vh * 0.002), list)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = e.get("color", Color.WHITE)
		_UiUtil.make_label(str(e.get("title", "")), int(_vh * 0.024), col, HORIZONTAL_ALIGNMENT_LEFT, row)
		var desc := _UiUtil.make_label(str(e.get("desc", "")), int(_vh * 0.02), Color(0.88, 0.9, 0.95),
				HORIZONTAL_ALIGNMENT_LEFT, row)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_row := _UiUtil.make_hbox(0, inner)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_UiUtil.make_button("Close", Vector2(_vh * 0.18, _vh * 0.055), int(_vh * 0.025), _close, btn_row)

func _close() -> void:
	closed.emit()
	queue_free()
