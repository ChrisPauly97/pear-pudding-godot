## Keyword integration tests — Ward, Surge, Shroud (TID-307 / GID-085).
##
## Tests how keywords interact with the game-logic layer (PlayerState / ZoneState /
## CardInstance / GameState) without instantiating BattleScene.
## Note: hero freeze and stun were dead code paths (no card ever applied them to a
## hero); they have been removed in this task (see Changes Made in TID-307).
extends "res://tests/framework/test_case.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState  = preload("res://game_logic/battle/PlayerState.gd")
const GameState    = preload("res://game_logic/battle/GameState.gd")
const Keywords     = preload("res://game_logic/battle/Keywords.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "test", cost: int = 1, attack: int = 1, health: int = 3,
		keywords_list: Array = []) -> Dictionary:
	var t: Dictionary = {
		"id": id, "name": id.capitalize(), "cost": cost,
		"attack": attack, "health": health,
		"card_class": "minion", "description": "",
	}
	if not keywords_list.is_empty():
		t["keywords"] = keywords_list
	return t

func _surge_card() -> CardInstance:
	return CardInstance.new(_tmpl("surge_test", 1, 2, 3, [Keywords.SURGE]))

func _ward_card(atk: int = 1, hp: int = 3) -> CardInstance:
	return CardInstance.new(_tmpl("ward_test", 1, atk, hp, [Keywords.WARD]))

func _shroud_card() -> CardInstance:
	return CardInstance.new(_tmpl("shroud_test", 1, 1, 3, [Keywords.SHROUD]))

func _plain_card(atk: int = 1, hp: int = 3) -> CardInstance:
	return CardInstance.new(_tmpl("plain_test", 1, atk, hp))

## Replicate the Ward valid-target filter from CardViewBuilder for pure-logic tests.
func _ward_valid_targets(cards: Array[CardInstance]) -> Array[CardInstance]:
	var ward_cards: Array[CardInstance] = []
	for c: CardInstance in cards:
		if c.keywords.has(Keywords.WARD):
			ward_cards.append(c)
	return ward_cards if not ward_cards.is_empty() else cards

# ---------------------------------------------------------------------------
# Surge — no summoning sickness after play
# ---------------------------------------------------------------------------

func test_surge_card_has_no_summoning_sickness_after_play() -> void:
	var gs := GameState.new()
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _surge_card()
	player.hand.append(card)
	player.play_card(card)
	assert_false(card.summoning_sick)

func test_non_surge_card_has_summoning_sickness_after_play() -> void:
	var gs := GameState.new()
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _plain_card()
	player.hand.append(card)
	player.play_card(card)
	assert_true(card.summoning_sick)

func test_surge_card_can_attack_immediately() -> void:
	var gs := GameState.new()
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _surge_card()
	player.hand.append(card)
	player.play_card(card)
	assert_true(card.can_attack())

func test_non_surge_card_cannot_attack_same_turn() -> void:
	var gs := GameState.new()
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _plain_card()
	player.hand.append(card)
	player.play_card(card)
	assert_false(card.can_attack())

func test_surge_card_keyword_preserved_after_round_trip() -> void:
	var card := _surge_card()
	var d: Dictionary = card.to_dict()
	var card2 := CardInstance.new()
	card2.from_dict(d)
	assert_true(card2.keywords.has(Keywords.SURGE))

func test_non_surge_card_cannot_attack_after_start_turn_if_summoning_sick_still_set() -> void:
	# Summoning sick is cleared by start_turn; this ensures after a full turn cycle both work.
	var gs := GameState.new()
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _plain_card()
	player.hand.append(card)
	player.play_card(card)
	# Next turn clears summoning sickness
	card.start_turn()
	assert_true(card.can_attack())

# ---------------------------------------------------------------------------
# Ward — targeting constraint
# ---------------------------------------------------------------------------

func test_ward_valid_targets_all_cards_when_no_ward() -> void:
	var cards: Array[CardInstance] = [_plain_card(), _plain_card()]
	var valid := _ward_valid_targets(cards)
	assert_eq(valid.size(), 2)

func test_ward_valid_targets_only_ward_cards_when_ward_present() -> void:
	var plain := _plain_card()
	var ward  := _ward_card()
	var cards: Array[CardInstance] = [plain, ward]
	var valid := _ward_valid_targets(cards)
	assert_eq(valid.size(), 1)
	assert_eq(valid[0], ward)

func test_ward_valid_targets_excludes_non_ward_minion() -> void:
	var plain := _plain_card()
	var ward  := _ward_card()
	var cards: Array[CardInstance] = [plain, ward]
	var valid := _ward_valid_targets(cards)
	assert_false(valid.has(plain))

func test_ward_valid_targets_multiple_ward_cards() -> void:
	var ward1 := _ward_card()
	var ward2 := _ward_card()
	var plain := _plain_card()
	var cards: Array[CardInstance] = [plain, ward1, ward2]
	var valid := _ward_valid_targets(cards)
	assert_eq(valid.size(), 2)
	assert_true(valid.has(ward1))
	assert_true(valid.has(ward2))

func test_ward_card_itself_has_keyword() -> void:
	var card := _ward_card()
	assert_true(card.keywords.has(Keywords.WARD))

func test_ward_keyword_preserved_after_round_trip() -> void:
	var card := _ward_card()
	var d: Dictionary = card.to_dict()
	var card2 := CardInstance.new()
	card2.from_dict(d)
	assert_true(card2.keywords.has(Keywords.WARD))

# ---------------------------------------------------------------------------
# Shroud — absorbs first hit
# ---------------------------------------------------------------------------

func test_shroud_card_has_shroud_active_on_creation() -> void:
	var card := _shroud_card()
	assert_true(card.shroud_active)

func test_shroud_absorbs_first_hit_no_hp_lost() -> void:
	var card := _shroud_card()
	card.take_damage(5)
	assert_eq(card.health, 3)  # no damage taken

func test_shroud_active_becomes_false_after_first_hit() -> void:
	var card := _shroud_card()
	card.take_damage(5)
	assert_false(card.shroud_active)

func test_shroud_second_hit_deals_damage() -> void:
	var card := _shroud_card()
	card.take_damage(1)  # consumed by shroud
	card.take_damage(2)  # real damage
	assert_eq(card.health, 1)

func test_shroud_not_active_on_non_shroud_card() -> void:
	var card := _plain_card()
	assert_false(card.shroud_active)

func test_shroud_active_state_preserved_in_round_trip() -> void:
	var card := _shroud_card()
	# Consume shroud
	card.take_damage(1)
	assert_false(card.shroud_active)
	var d: Dictionary = card.to_dict()
	var card2 := CardInstance.new()
	card2.from_dict(d)
	assert_false(card2.shroud_active)

func test_shroud_unconsummed_preserved_in_round_trip() -> void:
	var card := _shroud_card()
	var d: Dictionary = card.to_dict()
	var card2 := CardInstance.new()
	card2.from_dict(d)
	assert_true(card2.shroud_active)
	card2.take_damage(3)
	assert_eq(card2.health, 3)  # shroud still absorbed it

# ---------------------------------------------------------------------------
# Hero freeze dead-code removal — verify can_play is NOT gated by hero freeze
# (BattleFx still ticks hero poison/armor; freeze/stun check removed as dead code)
# ---------------------------------------------------------------------------

func test_hero_freeze_does_not_block_can_play() -> void:
	var gs := GameState.new()
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	player.hero.apply_status("freeze", 2)
	var card := _plain_card()
	player.hand.append(card)
	# After dead-code removal, hero freeze must NOT prevent playing
	assert_true(player.can_play(card))

func get_suite_name() -> String:
	return "KeywordIntegration"
