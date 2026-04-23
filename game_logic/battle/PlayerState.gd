class_name PlayerState
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")

var player_id: int
var hero: HeroState
var hand: Array[CardInstance] = []
var board: ZoneState
var draw_deck: Array[CardInstance] = []
var discard: Array[CardInstance] = []
var pending_auto_spells: Array[CardInstance] = []
var is_ai: bool = false

func _init(pid: int, ai: bool = false) -> void:
	player_id = pid
	is_ai = ai
	hero = HeroState.new(pid)
	board = ZoneState.new()

func build_deck(card_ids: Array[String]) -> void:
	draw_deck.clear()
	discard.clear()
	hand.clear()
	pending_auto_spells.clear()
	for cid in card_ids:
		var tmpl := CardRegistry.get_template(cid)
		if not tmpl.is_empty():
			draw_deck.append(CardInstance.from_template(tmpl))
	draw_deck.shuffle()

func draw_card() -> CardInstance:
	if draw_deck.is_empty():
		# Shuffle discard back
		draw_deck.append_array(discard)
		discard.clear()
		draw_deck.shuffle()
	if draw_deck.is_empty():
		return null
	var card := draw_deck.pop_back() as CardInstance
	if card.auto_resolve:
		discard.append(card)
		pending_auto_spells.append(card)
	else:
		hand.append(card)
	return card

func draw_opening_hand(count: int = 4) -> void:
	for _i in range(count):
		draw_card()

func can_play(card: CardInstance) -> bool:
	if hero.has_status("freeze"):
		return false
	if card.card_class == "spell":
		return hero.mana >= card.cost
	return hero.mana >= card.cost and not board.is_full()

func play_card(card: CardInstance) -> bool:
	if not can_play(card):
		return false
	hand.erase(card)
	hero.spend_mana(card.cost)
	if card.card_class == "spell":
		discard.append(card)
	else:
		board.add_card(card)
		if card.keywords.has(Keywords.SURGE):
			card.summoning_sick = false
	return true

func start_turn(turn_number: int) -> void:
	hero.gain_mana_for_turn(turn_number)
	board.start_turn()
	draw_card()
