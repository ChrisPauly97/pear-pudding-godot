## New Game step between slot select and world select (GID-137 / TID-562):
## pick the hero's skin tone and hair colour from PaperDoll's presets, with a
## live preview. The choice goes to `SaveManager.pending_appearance`, which
## `new_game()` moves into the persisted `hero_appearance`.
##
## Every swatch is a Button, so mouse, touch and keyboard focus all work.
extends Control

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")

const _ROW_LABELS: Dictionary = {"skin": "Skin", "hair": "Hair"}

var _choice: Dictionary = {"skin": 0, "hair": 0}
var _preview: TextureRect = null
var _swatches: Dictionary = {}  # key → Array of swatch Buttons, in preset order
var _ref: float = 0.0


func _ready() -> void:
	_choice = SaveManager.pending_appearance.duplicate()
	for key: String in _PaperDoll.LOOK_OPTIONS:
		_choice[key] = _PaperDoll.look_index(_choice, key)
	_build_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and _preview != null:
		for c: Node in get_children():
			remove_child(c)
			c.queue_free()
		_build_ui()


func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_ref = minf(vp.x, vp.y)
	_swatches.clear()

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.10)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var root := _UiUtil.make_vbox(int(_ref * 0.025), center)

	var title := _UiUtil.make_title_label("Your Hero", _ref)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_preview = TextureRect.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(_ref * 0.32, _ref * 0.28)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_preview)

	for key: String in _PaperDoll.LOOK_OPTIONS:
		_build_row(key, root)

	var buttons := _UiUtil.make_hbox(int(_ref * 0.03), root)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_size := Vector2(_ref * 0.18, _ref * 0.065)
	_UiUtil.make_button("Back", btn_size, int(_ref * 0.026), _on_back, buttons)
	var go := _UiUtil.make_button("Continue", btn_size, int(_ref * 0.026), _on_continue, buttons)
	go.grab_focus.call_deferred()
	_refresh()


func _build_row(key: String, parent: Node) -> void:
	var row := _UiUtil.make_hbox(int(_ref * 0.015), parent)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := _UiUtil.make_label(str(_ROW_LABELS.get(key, key.capitalize())), int(_ref * 0.026), Color.WHITE,
			HORIZONTAL_ALIGNMENT_RIGHT, row)
	lbl.custom_minimum_size = Vector2(_ref * 0.10, 0)
	var opts: Array = _PaperDoll.LOOK_OPTIONS[key]
	var btns: Array[Button] = []
	for i: int in opts.size():
		var btn := _UiUtil.make_button("", Vector2(_ref * 0.06, _ref * 0.06), 0, _on_pick.bind(key, i), row)
		btn.tooltip_text = "%s %d" % [str(_ROW_LABELS.get(key, key)), i + 1]
		btns.append(btn)
	_swatches[key] = btns


## Restyles the swatches (selected one ringed) and redraws the preview.
func _refresh() -> void:
	var r: int = int(_ref * 0.012)
	var ring: int = maxi(2, int(_ref * 0.006))
	for key: String in _swatches:
		var opts: Array = _PaperDoll.LOOK_OPTIONS[key]
		var btns: Array[Button] = []
		btns.assign(_swatches[key])
		for i: int in btns.size():
			var col: Color = opts[i]
			var picked: bool = i == int(_choice.get(key, 0))
			var border: Color = Color(1.0, 0.85, 0.35) if picked else Color(1, 1, 1, 0.2)
			var normal := _UiUtil.make_style(col, r, border, ring if picked else 1)
			var hover := _UiUtil.make_style(col.lightened(0.1), r, Color(1, 1, 1, 0.8), ring)
			for state: String in ["normal", "pressed", "disabled"]:
				btns[i].add_theme_stylebox_override(state, normal)
			btns[i].add_theme_stylebox_override("hover", hover)
			btns[i].add_theme_stylebox_override("focus", hover)
	_preview.texture = _PaperDoll.idle_texture({}, _PaperDoll.appearance_from(_choice))


func _on_pick(key: String, index: int) -> void:
	_choice[key] = index
	_refresh()


func _on_continue() -> void:
	SaveManager.pending_appearance = _choice.duplicate()
	get_tree().change_scene_to_file("res://scenes/ui/BiomeSelectionScene.tscn")


func _on_back() -> void:
	SaveManager.pending_appearance = {}
	get_tree().change_scene_to_file("res://scenes/ui/SlotSelectScene.tscn")
