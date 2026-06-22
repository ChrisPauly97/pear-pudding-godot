class_name PlayerState
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

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
var skip_next_draw: bool = false
var minion_attack_bonus: int = 0

# Battlefield Resonance context (GID-059) — set by GameState.set_battlefield_context().
var battlefield_biome: int = -1
var is_night: bool = false
var grasslands_card_played: bool = false  # resets at start_turn(); tracks first-card discount

func _init(pid: int, ai: bool = false) -> void:
	player_id = pid
	is_ai = ai
	hero = HeroState.new(pid)
	board = ZoneState.new()

func build_deck(card_ids: Array[String], difficulty_tier: int = 0, dark_aligned: bool = false) -> void:
	draw_deck.clear()
	discard.clear()
	hand.clear()
	pending_auto_spells.clear()
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	var face: String = "dark" if dark_aligned else "light"
	for cid in card_ids:
		var tmpl: Dictionary = CardRegistry.get_template_for_face(cid, face)
		if tmpl.is_empty():
			continue
		if difficulty_tier > 0:
			var scaled: Dictionary = CardDropUtil.enemy_card_stats(cid, difficulty_tier)
			tmpl = tmpl.duplicate()
			tmpl["attack"] = scaled.get("attack", tmpl.get("attack", 0))
			tmpl["health"] = scaled.get("health", tmpl.get("health", 0))
		draw_deck.append(CardInstance.new(tmpl))
	draw_deck.shuffle()
	if minion_attack_bonus > 0:
		for c: CardInstance in draw_deck:
			if c.card_class == "minion":
				c.attack += minion_attack_bonus

## Builds the player draw deck from collection instances (GID-060).
## Applies per-instance rolled stats and veterancy rank HP/ATK bonuses.
## Sets collection_uid on each CardInstance for post-battle attribution.
func build_deck_from_instances(insts: Array[Dictionary]) -> void:
	draw_deck.clear()
	discard.clear()
	hand.clear()
	pending_auto_spells.clear()
	var face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	for inst: Dictionary in insts:
		var tid: String = str(inst.get("template_id", ""))
		if tid == "":
			continue
		var tmpl: Dictionary = CardRegistry.get_template_for_face(tid, face)
		if tmpl.is_empty():
			continue
		tmpl = tmpl.duplicate()
		tmpl["attack"] = int(inst.get("attack", tmpl.get("attack", 0)))
		tmpl["health"] = int(inst.get("health", tmpl.get("health", 0)))
		tmpl["cost"]   = int(inst.get("cost",   tmpl.get("cost",   1)))
		var kills: int = int(inst.get("kills", 0))
		var survived: int = int(inst.get("battles_survived", 0))
		var rank: int = VeterancyUtil.rank_for(kills, survived)
		tmpl["attack"] += VeterancyUtil.atk_bonus_for(rank)
		tmpl["health"] += VeterancyUtil.hp_bonus_for(rank)
		var ci := CardInstance.new(tmpl)
		ci.collection_uid = str(inst.get("uid", ""))
		ci.name = VeterancyUtil.display_name(inst, str(tmpl.get("name", tid)))
		draw_deck.append(ci)
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

## Returns the effective mana cost of a card, applying biome and time-of-day rules.
func effective_cost(card: CardInstance) -> int:
	return BattlefieldRules.effective_cost(
		card.cost, card.magic_branch, battlefield_biome, is_night, grasslands_card_played)

func can_play(card: CardInstance) -> bool:
	if hero.has_status("freeze"):
		return false
	var cost: int = effective_cost(card)
	if card.card_class == "spell":
		return hero.mana >= cost
	return hero.mana >= cost and not board.is_full()

func play_card(card: CardInstance) -> bool:
	if not can_play(card):
		return false
	var cost: int = effective_cost(card)
	hand.erase(card)
	hero.spend_mana(cost)
	if card.card_class == "spell":
		discard.append(card)
	else:
		board.add_card(card)
		var slot_idx: int = board.slots.find(card)
		var enh: Dictionary = board.consume_slot_enhancement(slot_idx)
		_apply_enhancement_to_card(card, enh)
		BattlefieldRules.apply_slot_rule(card, slot_idx, battlefield_biome)
		if card.keywords.has(Keywords.SURGE):
			card.summoning_sick = false
	grasslands_card_played = true
	return true

func play_card_at_slot(card: CardInstance, slot_idx: int) -> bool:
	if not can_play(card):
		return false
	if not board.add_card_at_slot(card, slot_idx):
		return false
	var cost: int = effective_cost(card)
	hand.erase(card)
	hero.spend_mana(cost)
	if card.card_class == "spell":
		discard.append(card)
	else:
		var enh: Dictionary = board.consume_slot_enhancement(slot_idx)
		_apply_enhancement_to_card(card, enh)
		BattlefieldRules.apply_slot_rule(card, slot_idx, battlefield_biome)
		card.summoning_sick = true
		if card.keywords.has(Keywords.SURGE):
			card.summoning_sick = false
	grasslands_card_played = true
	return true

func _apply_enhancement_to_card(card: CardInstance, enh: Dictionary) -> void:
	match enh.get("type", ""):
		"atk_bonus":
			card.attack += int(enh.get("value", 0))
		"shroud":
			card.shroud_active = true

func start_turn(turn_number: int) -> void:
	grasslands_card_played = false
	hero.gain_mana_for_turn(turn_number)
	board.start_turn()
	if skip_next_draw:
		skip_next_draw = false
	else:
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
		"skip_next_draw": skip_next_draw,
		"minion_attack_bonus": minion_attack_bonus,
		"hero": hero.to_dict(),
		"board": board.to_dict(),
		"board_enhancements": board.enhancements_to_dict(),
		"hand": hand_arr,
		"draw_deck": deck_arr,
		"discard": discard_arr,
		"pending_auto_spells": auto_arr,
		"battlefield_biome": battlefield_biome,
		"is_night": is_night,
		"grasslands_card_played": grasslands_card_played,
	}

func from_dict(d: Dictionary) -> void:
	is_ai = bool(d.get("is_ai", false))
	bonus_draw = int(d.get("bonus_draw", 0))
	fatigue_counter = int(d.get("fatigue_counter", 0))
	skip_next_draw = bool(d.get("skip_next_draw", false))
	minion_attack_bonus = int(d.get("minion_attack_bonus", 0))
	battlefield_biome = int(d.get("battlefield_biome", -1))
	is_night = bool(d.get("is_night", false))
	grasslands_card_played = bool(d.get("grasslands_card_played", false))
	var raw_hero = d.get("hero", {})
	if raw_hero is Dictionary:
		hero.from_dict(raw_hero)
	var raw_board = d.get("board", [])
	if raw_board is Array:
		board.from_dict(raw_board)
	var raw_enhancements = d.get("board_enhancements", [])
	if raw_enhancements is Array:
		board.enhancements_from_dict(raw_enhancements)
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
