extends Control

signal closed

var card_ids: Array = []
var _current_idx: int = 0

@onready var _card_name: Label = $VBox/CardName
@onready var _card_desc: Label = $VBox/CardDesc
@onready var _progress: Label = $VBox/Progress
@onready var _next_btn: Button = $VBox/NextButton
@onready var _card_panel: PanelContainer = $VBox/CardPanel

func _ready() -> void:
	_next_btn.pressed.connect(_on_next)
	_show_card(_current_idx)

func _show_card(idx: int) -> void:
	if idx >= card_ids.size():
		closed.emit()
		return
	var cid: String = card_ids[idx]
	var tmpl := CardRegistry.get_template(cid)
	_card_name.text = tmpl.get("name", cid)
	_card_desc.text = tmpl.get("description", "")
	_progress.text = "%d / %d" % [idx + 1, card_ids.size()]

	# Animate reveal
	_card_panel.modulate.a = 0.0
	_card_panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_card_panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(_card_panel, "scale", Vector2(1.0, 1.0), 0.4)

	_next_btn.text = "Next" if idx < card_ids.size() - 1 else "Claim All"

func _on_next() -> void:
	_current_idx += 1
	_show_card(_current_idx)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_on_next()
