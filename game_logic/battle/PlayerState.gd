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
var fatigue_counter: int = 0

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
		fatigue_counter += 1
		hero.take_damage(fatigue_counter)
		_emit_fatigue(fatigue_counter)
		return null
	var card := draw_deck.pop_back() as CardInstance
	if card.auto_resolve:
		discard.append(card)
		pending_auto_spells.append(card)
	else:
		hand.append(card)
	return card

func _emit_fatigue(dmg: int) -> void:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		var gb: Node = (ml as SceneTree).root.get_node_or_null("GameBus")
		if gb != null:
			gb.emit_signal("fatigue_damage", player_id, dmg)

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
		"fatigue_counter": fatigue_counter,
		"hero": hero.to_dict(),
		"board": board.to_dict(),
		"hand": hand_arr,
		"draw_deck": deck_arr,
		"discard": discard_arr,
		"pending_auto_spells": auto_arr,
	}

func from_dict(d: Dictionary) -> void:
	is_ai = bool(d.get("is_ai", false))
	bonus_draw = int(d.get("bonus_draw", 0))
	fatigue_counter = int(d.get("fatigue_counter", 0))
	var raw_hero = d.get("hero", {})
	if raw_hero is Dictionary:
		hero.from_dict(raw_hero)
	var raw_board = d.get("board", [])
	if raw_board is Array:
		board.from_dict(raw_board)
	hand.clear()
	for cd in d.get("hand", []):
		if cd is Dictionary:
			var ci := CardInstance.new()
			ci.from_dict(cd)
			hand.append(ci)
	draw_deck.clear()
	for cd in d.get("draw_deck", []):
		if cd is Dictionary:
			var ci := CardInstance.new()
			ci.from_dict(cd)
			draw_deck.append(ci)
	discard.clear()
	for cd in d.get("discard", []):
		if cd is Dictionary:
			var ci := CardInstance.new()
			ci.from_dict(cd)
			discard.append(ci)
	pending_auto_spells.clear()
	for cd in d.get("pending_auto_spells", []):
		if cd is Dictionary:
			var ci := CardInstance.new()
			ci.from_dict(cd)
			pending_auto_spells.append(ci)
