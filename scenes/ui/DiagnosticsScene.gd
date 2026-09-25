extends "res://scenes/ui/BaseOverlay.gd"

const _LEVEL_COLORS: Dictionary = {
	"INFO":  "green",
	"WARN":  "yellow",
	"ERROR": "red",
}

const _LOG_DIR := "user://logs"
const _LOG_TAIL_LINES: int = 200

var _rich: RichTextLabel
var _showing_prev_log: bool = false

func _ready() -> void:
	super._ready()
	_build_backdrop()

	var panel_w: float = _vw * 0.88
	var panel_h: float = _vh * 0.82
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var vbox := _build_margin_vbox(panel, 0.018, 0.012)

	var title := _UiUtil.make_label("Diagnostics", int(_vh * 0.038), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich.add_theme_font_size_override("normal_font_size", int(_vh * 0.022))
	_rich.scroll_active = false
	scroll.add_child(_rich)

	_populate()

	var hbox := _UiUtil.make_hbox(int(_vh * 0.015), vbox)

	var clear_btn := _UiUtil.make_button("Clear", Vector2(_vh * 0.18, _vh * 0.06), int(_vh * 0.026), _on_clear, hbox)
	# After a crash the engine log of the run that died is the newest rotated
	# file in user://logs — the only way to read it on a phone without adb.
	var prev_btn := _UiUtil.make_button("Last Session Log", Vector2(_vh * 0.3, _vh * 0.06), int(_vh * 0.026),
			Callable(), hbox)
	prev_btn.pressed.connect(func() -> void: _toggle_prev_log(prev_btn))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var close_btn := _UiUtil.make_button("Close", Vector2(_vh * 0.18, _vh * 0.06), int(_vh * 0.026), _close, hbox)

func _populate() -> void:
	_rich.clear()
	var entries: Array[Dictionary] = AppLog.get_entries()
	for entry: Dictionary in entries:
		var ts: float = entry.get("ts", 0.0)
		var level: String = entry.get("level", "INFO")
		var msg: String = entry.get("msg", "")
		var col: String = _LEVEL_COLORS.get(level, "white")
		_rich.append_text(
			"[color=#888888][%.1fs][/color] [color=%s][%s][/color] %s\n" % [ts, col, level, msg]
		)

func _on_clear() -> void:
	AppLog.clear()
	_populate()

func _toggle_prev_log(btn: Button) -> void:
	_showing_prev_log = not _showing_prev_log
	btn.text = "Live Log" if _showing_prev_log else "Last Session Log"
	if not _showing_prev_log:
		_populate()
		return
	_rich.clear()
	var files: PackedStringArray = DirAccess.get_files_at(_LOG_DIR)
	var log_name: String = newest_previous_log(files)
	if log_name == "":
		_rich.append_text("No previous session log found in %s." % _LOG_DIR)
		return
	var text: String = FileAccess.get_file_as_string("%s/%s" % [_LOG_DIR, log_name])
	_rich.append_text("[color=#ffd966]%s[/color]\n" % log_name)
	_rich.add_text(log_tail(text, _LOG_TAIL_LINES))

## Godot rotates `godot.log` (the running session) to `godot<timestamp>.log` on
## startup, so the newest timestamped file is the previous run.
static func newest_previous_log(files: PackedStringArray) -> String:
	var best: String = ""
	for f: String in files:
		if f == "godot.log" or not f.begins_with("godot") or not f.ends_with(".log"):
			continue
		if f > best:
			best = f
	return best

static func log_tail(text: String, max_lines: int) -> String:
	var lines: PackedStringArray = text.split("\n")
	if lines.size() <= max_lines:
		return text
	return "\n".join(lines.slice(lines.size() - max_lines))
