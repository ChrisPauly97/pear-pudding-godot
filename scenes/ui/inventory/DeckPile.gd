## The deck side of the deck table (GID-180 / TID-737): header row (deck count,
## Undo, Best deck), a slot for the loadout tabs, and the deck itself as mini
## card tiles. Pure view — InventoryScene owns the deck and wires each tile's
## input through the `decorate` callable passed to `show_deck`.
extends VBoxContainer

signal undo_pressed
signal best_pressed

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardTile = preload("res://scenes/ui/inventory/CardTile.gd")

## Deck tiles are drawn at this fraction of the binder's tile size.
const TILE_SCALE: float = 0.78

var loadout_slot: VBoxContainer
var header: HBoxContainer
var scroll: ScrollContainer
var _count_label: Label
var _undo_btn: Button
var _grid: HFlowContainer
var _ref: float = 0.0


func setup(ref: float, min_scroll_h: float) -> void:
	_ref = ref
	add_theme_constant_override("separation", int(ref * 0.006))
	loadout_slot = _UiUtil.make_vbox(int(ref * 0.005), self)
	header = _UiUtil.make_hbox(int(ref * 0.008), self)
	_count_label = _UiUtil.make_label("", int(ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, header)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bs := Vector2(ref * 0.12, ref * 0.052)
	_undo_btn = _UiUtil.make_button("↶ Undo", bs, int(ref * 0.019), func() -> void: undo_pressed.emit(), header)
	_undo_btn.tooltip_text = "Undo the last deck change (Ctrl+Z)"
	var best := _UiUtil.make_button("★ Best deck", Vector2(ref * 0.16, ref * 0.052), int(ref * 0.019),
			func() -> void: best_pressed.emit(), header)
	best.tooltip_text = "Fill the deck with your strongest cards"
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if min_scroll_h > 0.0:
		scroll.custom_minimum_size = Vector2(0.0, min_scroll_h)
	add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(ref * 0.006))
	_grid.add_theme_constant_override("v_separation", int(ref * 0.006))
	scroll.add_child(_grid)


## Rebuilds the deck tiles. `decorate(tile: Button, inst: Dictionary)` wires input.
func show_deck(insts: Array[Dictionary], template_for: Callable, decorate: Callable, can_undo: bool) -> void:
	var keep: int = scroll.scroll_vertical
	for child in _grid.get_children():
		child.queue_free()
	for inst: Dictionary in insts:
		var tmpl: Dictionary = template_for.call(str(inst.get("template_id", "")))
		var tile: Button = _CardTile.build(inst, tmpl, _ref * TILE_SCALE)
		_grid.add_child(tile)
		decorate.call(tile, inst)
	if insts.is_empty():
		var hint := _UiUtil.make_label("Tap cards above to add them to your deck", int(_ref * 0.019),
				Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _grid)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.disabled = not can_undo
	_count_label.text = "Deck  %d / %d" % [insts.size(), IsoConst.DECK_MAX]
	var ok: bool = insts.size() >= IsoConst.DECK_MIN and insts.size() <= IsoConst.DECK_MAX
	_count_label.modulate = Color.WHITE if ok else Color(1.0, 0.4, 0.4)
	if not ok:
		_count_label.text += "  (need %d+)" % IsoConst.DECK_MIN
	scroll.set_deferred("scroll_vertical", keep)
