extends "res://scenes/ui/BaseOverlay.gd"

## Placeholder overlay (TID-412) — proves the GameBus.mailbox_requested ->
## SceneManager._on_mailbox_requested -> _open_overlay signal chain end to end.
## TID-413 replaces this file's contents with the real claim/sell/scrap UI.

func _ready() -> void:
	super._ready()
	_build_backdrop(0.78, true)
	var panel := _build_centered_panel(_vw * 0.6, _vh * 0.5)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())
	var vbox := _build_margin_vbox(panel)

	var title := Label.new()
	title.text = "Mailbox"
	title.add_theme_font_size_override("font_size", int(_ref * 0.03))
	vbox.add_child(title)

	var body := Label.new()
	body.text = "Overflow cards will appear here."
	vbox.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)
