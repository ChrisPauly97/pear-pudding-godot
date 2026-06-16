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
var bonus_draw: int = 0

func _init(pid: int, ai: bool = false) -> void:
	player_id = pid
	is_ai = ai
	hero = HeroState.new(pid)
	board = ZoneState.new()

func build_deck(card_ids: Array[String], difficulty_tier: int = 0) -> void:
	draw_deck.clear()
	discard.clear()
	hand.clear()
	pending_auto_spells.clear()
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	for cid in card_ids:
		var tmpl: Dictionary = CardRegistry.get_template(cid)
		if tmpl.is_empty():
			continue
		if difficulty_tier > 0:
			var scaled: Dictionary = CardDropUtil.enemy_card_stats(cid, difficulty_tier)
			tmpl = tmpl.duplicate()
			tmpl["attack"] = scaled.get("attack", tmpl.get("attack", 0))
			tmpl["health"] = scaled.get("health", tmpl.get("health", 0))
		draw_deck.append(CardInstance.new(tmpl))
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
	for _i in range(bonus_draw):
		draw_card()

func to_dict() -> Dictionary:
	var hand_arr: Array = []
	for c: CardInstance in hand:
		hand_arr.append(c.to_dict())
	var deck_arr: Array = []
	for c: CardInstance in draw_deck:
		deck_arr.append(c.to_dict())
	var discard_arr: Array = []
	for c: CardInstance in discard:
		discard_arr.append(c.to_dict())
	var auto_arr: Array = []
	for c: CardInstance in pending_auto_spells:
		auto_arr.append(c.to_dict())
	return {
		"player_id": player_id,
		"is_ai": is_ai,
		"bonus_draw": bonus_draw,
		"hero": hero.to_dict(),
		"board": board.to_dict(),
		"hand": hand_arr,
		"draw_deck": deck_arr,
		"discard": discard_arr,
		"pending_auto_spells": auto_arr,
	}

static func from_dict(d: Dictionary) -> PlayerState:
	var pid: int = int(d.get("player_id", 0))
	var ai: bool = bool(d.get("is_ai", false))
	var ps := PlayerState.new(pid, ai)
	ps.bonus_draw = int(d.get("bonus_draw", 0))
	ps.hero = HeroState.from_dict(d.get("hero", {}))
	ps.board = ZoneState.from_dict(d.get("board", []))
	ps.hand.clear()
	for cd in d.get("hand", []):
		if cd is Dictionary:
			ps.hand.append(CardInstance.from_dict(cd))
	ps.draw_deck.clear()
	for cd in d.get("draw_deck", []):
		if cd is Dictionary:
			ps.draw_deck.append(CardInstance.from_dict(cd))
	ps.discard.clear()
	for cd in d.get("discard", []):
		if cd is Dictionary:
			ps.discard.append(CardInstance.from_dict(cd))
	ps.pending_auto_spells.clear()
	for cd in d.get("pending_auto_spells", []):
		if cd is Dictionary:
			ps.pending_auto_spells.append(CardInstance.from_dict(cd))
	return ps
