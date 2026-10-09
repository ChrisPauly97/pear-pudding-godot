## The vendor counter (GID-180 / TID-745) — the only place cards are sold.
## Bag cards sit below the counter; tap one (or drag it onto the counter) and it
## slides across, the vendor reacts, and coins drop onto the pile. "Sell
## basket" sells every card flagged for sale in the bag in one go.
extends VBoxContainer

signal sold(gold: int)

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardTile = preload("res://scenes/ui/inventory/CardTile.gd")
const _CardJuice = preload("res://scenes/ui/inventory/CardJuice.gd")
const _CoinPile = preload("res://scenes/ui/shop/CoinPile.gd")
const BagOps = preload("res://game_logic/inventory/BagOps.gd")
const DeckInsights = preload("res://game_logic/inventory/DeckInsights.gd")
const VendorReactions = preload("res://game_logic/inventory/VendorReactions.gd")
const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

const _DRAG_KIND := "vendor_card"

## inst -> int sale price (TID-746 adds town preferences). Defaults to the rarity's sell_gold.
var price_for: Callable = func(inst: Dictionary) -> int:
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(str(inst.get("rarity", "common")), {})
	return int(cfg.get("sell_gold", 0))
## inst -> bool: does this vendor favour the card (bonus reaction).
var prefers: Callable = func(_inst: Dictionary) -> bool: return false

var _ref: float = 0.0
var _speech: Label
var _counter: PanelContainer
var _pile: _CoinPile
var _earned_lbl: Label
var _basket_btn: Button
var _grid: HFlowContainer
var _scroll: ScrollContainer
var _earned: int = 0
var _said: int = 0
var _sold_by_tid: Dictionary = {}


func setup(ref: float) -> void:
	_ref = ref
	add_theme_constant_override("separation", int(ref * 0.008))
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_speech = _UiUtil.make_label("\"Got anything for me?\"", int(ref * 0.021), Color(1.0, 0.9, 0.7),
			HORIZONTAL_ALIGNMENT_CENTER, self)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# ---- The counter: drop zone + coin pile + basket ----
	_counter = PanelContainer.new()
	_counter.custom_minimum_size = Vector2(0, ref * 0.13)
	_counter.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.36, 0.22, 0.12), int(ref * 0.01),
			Color(0.6, 0.4, 0.2), 3))
	add_child(_counter)
	_counter.set_drag_forwarding(Callable(), _can_drop, _drop)
	var row := _UiUtil.make_hbox(int(ref * 0.012), _counter)
	var hint := _UiUtil.make_label("Tap a card below, or drag it onto the counter, to sell it", int(ref * 0.018),
			Color(0.95, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER, row)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pile_box := _UiUtil.make_vbox(0, row)
	_pile = _CoinPile.new()
	_pile.custom_minimum_size = Vector2(ref * 0.16, ref * 0.08)
	pile_box.add_child(_pile)
	_earned_lbl = _UiUtil.make_label("", int(ref * 0.018), Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER,
			pile_box)
	_basket_btn = _UiUtil.make_button("", Vector2(ref * 0.22, ref * 0.06), int(ref * 0.019), _sell_basket, self)
	_basket_btn.modulate = Color(1.0, 0.88, 0.4)
	_basket_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# ---- The player's sellable cards ----
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, ref * 0.25)
	add_child(_scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(ref * 0.006))
	_grid.add_theme_constant_override("v_separation", int(ref * 0.006))
	_scroll.add_child(_grid)
	refresh()


## Cards the vendor may buy: in the bag, in no deck, not unique. Flagged first.
func sellable() -> Array[Dictionary]:
	var sm := SceneManager.save_manager
	var membership: Dictionary = BagOps.deck_membership(sm.loadouts, sm.player_deck, sm.active_loadout, "deck")
	var flagged: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for inst: Dictionary in sm.get_owned_instances():
		var uid: String = str(inst.get("uid", ""))
		if membership.has(uid) or bool(CardRegistry.get_template(str(inst.get("template_id", ""))).get(
				"is_unique", false)):
			continue
		(flagged if sm.is_for_sale(uid) else rest).append(inst)
	flagged.append_array(rest)
	return flagged


func refresh() -> void:
	var sm := SceneManager.save_manager
	for c in _grid.get_children():
		c.queue_free()
	var basket_n: int = 0
	var basket_g: int = 0
	var scale: float = 0.8
	for inst: Dictionary in sellable():
		var uid: String = str(inst.get("uid", ""))
		var flagged: bool = sm.is_for_sale(uid)
		if flagged:
			basket_n += 1
			basket_g += int(price_for.call(inst))
		var tmpl: Dictionary = CardRegistry.get_template(str(inst.get("template_id", "")))
		var tile: Button = _CardTile.build(inst, tmpl, _ref * scale, "For sale" if flagged else "")
		_CardTile.add_price(tile, int(price_for.call(inst)), flagged, _ref * scale)
		_grid.add_child(tile)
		_UiUtil.bind_scroll_safe_press(tile, _sell_one.bind(uid, tile), _scroll)
		tile.set_drag_forwarding(func(_at: Vector2) -> Variant:
			tile.set_drag_preview(_CardJuice.drag_preview(inst, tmpl, _ref * scale))
			_CardJuice.sound("pick")
			return {"kind": _DRAG_KIND, "uid": uid}, Callable(), Callable())
	if _grid.get_child_count() == 0:
		_UiUtil.make_label("Nothing to sell — cards in a deck stay with you.", int(_ref * 0.019),
				Color(0.65, 0.65, 0.7), HORIZONTAL_ALIGNMENT_CENTER, _grid)
	_basket_btn.text = "Sell basket: %d card%s  +%dg" % [basket_n, "" if basket_n == 1 else "s", basket_g]
	_basket_btn.disabled = basket_n == 0
	_basket_btn.tooltip_text = "Flag cards \"For sale\" in your bag to fill the basket"
	_earned_lbl.text = "+%dg this visit" % _earned if _earned > 0 else ""


func _can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == _DRAG_KIND


func _drop(_at: Vector2, data: Variant) -> void:
	_sell_one(str((data as Dictionary).get("uid", "")), null)


## Slides the card onto the counter, has the vendor react, then sells it.
func _sell_one(uid: String, tile: Control) -> void:
	var sm := SceneManager.save_manager
	var inst: Dictionary = sm.get_instance_by_uid(uid)
	if inst.is_empty():
		return
	var tid: String = str(inst.get("template_id", ""))
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	var facts: Dictionary = {
		"perfect": DeckInsights.is_perfect_roll(inst),
		"preferred": bool(prefers.call(inst)),
		"veteran": VeterancyUtil.rank_for(int(inst.get("kills", 0)), int(inst.get("battles_survived", 0))) > 0,
		"copies_sold": int(_sold_by_tid.get(tid, 0)),
	}
	_say(VendorReactions.line(VendorReactions.reaction_for(inst, facts), _said, str(tmpl.get("name", tid))))
	if tile != null and tile.is_inside_tree():
		_slide(tile.get_global_rect(), inst, tmpl)
	var gold: int = int(price_for.call(inst))
	_ring_up(uid, gold)
	_sold_by_tid[tid] = int(_sold_by_tid.get(tid, 0)) + 1
	refresh()


func _sell_basket() -> void:
	var sm := SceneManager.save_manager
	var total: int = 0
	var n: int = 0
	for inst: Dictionary in sellable():
		var uid: String = str(inst.get("uid", ""))
		if sm.is_for_sale(uid):
			var gold: int = int(price_for.call(inst))
			_ring_up(uid, gold)
			total += gold
			n += 1
	if n == 0:
		return
	_say(VendorReactions.line("basket", _said))
	_pile.add(n * 2)
	for i in range(mini(n, 6)):
		get_tree().create_timer(0.08 * i).timeout.connect(func() -> void: _CardJuice.sound("place"))
	refresh()


func _ring_up(uid: String, gold: int) -> void:
	SceneManager.save_manager.sell_card_instance(uid, gold)
	_earned += gold
	_pile.add(maxi(1, gold / 10))
	sold.emit(gold)


func _say(text: String) -> void:
	_said += 1
	_speech.text = "\"%s\"" % text
	_CardJuice.pop(_speech, 0.08)


## A copy of the card glides from its tile onto the counter and fades there.
func _slide(from: Rect2, inst: Dictionary, tmpl: Dictionary) -> void:
	var ghost: Button = _CardTile.build(inst, tmpl, _ref * 0.8)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.top_level = true
	ghost.z_index = 30
	add_child(ghost)
	ghost.global_position = from.position
	var dest: Vector2 = _counter.get_global_rect().get_center() - ghost.custom_minimum_size * 0.5
	_CardJuice.sound("place")
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "global_position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.35)
	tw.tween_callback(ghost.queue_free)
