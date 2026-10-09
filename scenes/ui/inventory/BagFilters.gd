## Binder filters (GID-180, split out of InventoryScene): class / cost / rarity
## toggles plus the active binder page. Holds the state, builds the toggle row,
## and answers whether a card passes.
extends RefCounted

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const BinderOps = preload("res://game_logic/inventory/BinderOps.gd")

## [label, kind, value] per toggle button, in row order.
const SPECS: Array = [
	["All", "class", ""], ["Ally", "class", "minion"], ["Spell", "class", "spell"],
	["0-2", "cost", "low"], ["3-5", "cost", "mid"], ["6+", "cost", "high"],
	["C", "rarity", "common"], ["R", "rarity", "rare"], ["E", "rarity", "epic"], ["L", "rarity", "legendary"],
]

var card_class: String = ""   # "" = all, "minion", "spell"
var cost: String = ""         # "" = all, "low" (0-2), "mid" (3-5), "high" (6+)
var rarity: String = ""       # "" = all, or a rarity
var page: String = "all"      # BinderOps.PAGES
var _btns: Array[Button] = []
var _on_change: Callable


## Builds the toggle buttons into `row`; `on_change` runs after every toggle.
func build(row: HBoxContainer, ref: float, on_change: Callable) -> void:
	_on_change = on_change
	_btns.clear()
	for spec: Array in SPECS:
		var btn := _UiUtil.make_button(str(spec[0]), Vector2(0.0, ref * 0.048), int(ref * 0.018), Callable(), row)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_toggle.bind(str(spec[1]), str(spec[2])))
		_btns.append(btn)
	_paint()


func any_active() -> bool:
	return card_class != "" or cost != "" or rarity != ""


func _toggle(kind: String, val: String) -> void:
	match kind:
		"class":
			card_class = "" if card_class == val else val
		"cost":
			cost = "" if cost == val else val
		"rarity":
			rarity = "" if rarity == val else val
	_paint()
	if _on_change.is_valid():
		_on_change.call()


func _paint() -> void:
	for i in range(mini(SPECS.size(), _btns.size())):
		var kind: String = str(SPECS[i][1])
		var val: String = str(SPECS[i][2])
		var on: bool
		match kind:
			"class": on = card_class == val
			"cost": on = cost == val
			_: on = rarity == val
		_btns[i].modulate = Color(1.0, 0.85, 0.3) if on else Color.WHITE


## True when a card of this template/rarity shows under the current filters and page.
func passes(tmpl: Dictionary, card_rarity: String) -> bool:
	if not BinderOps.on_page(tmpl, page) or (rarity != "" and card_rarity != rarity):
		return false
	if card_class != "" and str(tmpl.get("card_class", "minion")) != card_class:
		return false
	return cost_matches(int(tmpl.get("cost", 0)))


func cost_matches(c: int) -> bool:
	match cost:
		"low":
			return c <= 2
		"mid":
			return c >= 3 and c <= 5
		"high":
			return c >= 6
	return true
