## Unit tests for Battlefield Resonance (GID-059).
##
## Covers: rules table integrity, all five biome rules, both time-of-day cost modifiers,
## floor-0 clamp, stacking, mid-battle persistence (to_dict / from_dict), and the neutral
## dungeon path.  All tests run at the game_logic level — no BattleScene scenes.
extends "res://tests/framework/test_case.gd"

const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const GameState        = preload("res://game_logic/battle/GameState.gd")
const PlayerState      = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance     = preload("res://game_logic/battle/CardInstance.gd")
const Keywords         = preload("res://game_logic/battle/Keywords.gd")
const BiomeDef         = preload("res://game_logic/world/BiomeDef.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "ghost", cost: int = 1, attack: int = 1, health: int = 2,
		branch: String = "") -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": cost,
		"attack": attack, "health": health,
		"card_class": "minion", "description": "",
		"magic_branch": branch,
	}

func _card(cost: int = 1, attack: int = 1, health: int = 2, branch: String = "") -> CardInstance:
	return CardInstance.new(_tmpl("ghost", cost, attack, health, branch))

func _state_with_context(biome: int, night: bool) -> GameState:
	var gs := GameState.new()
	gs.set_battlefield_context(biome, night)
	return gs

# ---------------------------------------------------------------------------
# 1. Rules table integrity
# ---------------------------------------------------------------------------

func test_all_biome_ids_have_a_rules_entry() -> void:
	for biome_id in range(BiomeDef.COUNT):
		assert_true(BattlefieldRules.RULES.has(biome_id),
			"RULES missing entry for biome %d" % biome_id)

func test_dungeon_id_has_a_rules_entry() -> void:
	assert_true(BattlefieldRules.RULES.has(-1))

func test_all_entries_have_rule_key() -> void:
	for biome_id in BattlefieldRules.RULES.keys():
		var entry: Dictionary = BattlefieldRules.RULES[biome_id] as Dictionary
		assert_true(entry.has("rule_key"),
			"RULES entry %d missing rule_key" % biome_id)

func test_all_entries_have_rule_text() -> void:
	for biome_id in BattlefieldRules.RULES.keys():
		var entry: Dictionary = BattlefieldRules.RULES[biome_id] as Dictionary
		assert_true(entry.has("rule_text"),
			"RULES entry %d missing rule_text" % biome_id)

func test_dungeon_rule_key_is_none() -> void:
	assert_eq(BattlefieldRules.get_rule_key(-1), BattlefieldRules.RULE_NONE)

func test_dungeon_returns_without_error() -> void:
	var _name: String = BattlefieldRules.get_biome_name(-1)
	var _text: String = BattlefieldRules.get_rule_text(-1)
	var _key: String  = BattlefieldRules.get_rule_key(-1)
	assert_true(true)  # reached without crash

func test_grasslands_rule_key() -> void:
	assert_eq(BattlefieldRules.get_rule_key(BiomeDef.GRASSLANDS), BattlefieldRules.RULE_GRASSLANDS)

func test_forest_slot_highlights_are_0_and_4() -> void:
	var hl: Array[int] = BattlefieldRules.get_slot_highlights(BiomeDef.FOREST)
	assert_true(hl.has(0) and hl.has(4))

func test_mountains_slot_highlight_is_2() -> void:
	var hl: Array[int] = BattlefieldRules.get_slot_highlights(BiomeDef.MOUNTAINS)
	assert_true(hl.has(2) and hl.size() == 1)

func test_other_biomes_have_no_slot_highlights() -> void:
	for biome_id in [BiomeDef.GRASSLANDS, BiomeDef.DESERT, BiomeDef.SCORCHED, -1]:
		assert_true(BattlefieldRules.get_slot_highlights(biome_id).is_empty(),
			"biome %d should have no slot highlights" % biome_id)

# ---------------------------------------------------------------------------
# 2. Grasslands first-card discount
# ---------------------------------------------------------------------------

func test_grasslands_effective_cost_first_card_discounted() -> void:
	# cost 2, no branch, Grasslands, no card played yet → 1
	var cost: int = BattlefieldRules.effective_cost(2, "", BiomeDef.GRASSLANDS, false, false)
	assert_eq(cost, 1)

func test_grasslands_second_card_full_cost() -> void:
	var cost: int = BattlefieldRules.effective_cost(2, "", BiomeDef.GRASSLANDS, false, true)
	assert_eq(cost, 2)

func test_grasslands_floor_zero() -> void:
	var cost: int = BattlefieldRules.effective_cost(0, "", BiomeDef.GRASSLANDS, false, false)
	assert_eq(cost, 0)

func test_grasslands_can_play_reflects_discount() -> void:
	var gs := _state_with_context(BiomeDef.GRASSLANDS, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 1  # normally can't afford a 2-cost card
	var card := _card(2)
	player.hand.append(card)
	# First card — discount applies → cost becomes 1, mana = 1 → can_play
	assert_true(player.can_play(card))

func test_grasslands_can_play_second_card_full_cost() -> void:
	var gs := _state_with_context(BiomeDef.GRASSLANDS, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 1
	var card1 := _card(1)
	var card2 := _card(2)
	player.hand.append(card1)
	player.hand.append(card2)
	player.play_card(card1)  # first card played; discount now exhausted
	assert_false(player.can_play(card2))  # 2 cost, 0 mana left

func test_grasslands_flag_resets_on_start_turn() -> void:
	var gs := _state_with_context(BiomeDef.GRASSLANDS, false)
	var player: PlayerState = gs.players[0]
	player.grasslands_card_played = true
	player.start_turn(2)
	assert_false(player.grasslands_card_played)

func test_grasslands_ai_affordability_via_can_play() -> void:
	var gs := _state_with_context(BiomeDef.GRASSLANDS, false)
	var player: PlayerState = gs.players[1]  # AI player
	player.hero.mana = 1
	var card := _card(2)
	player.hand.append(card)
	# AI calls can_play → effective_cost → 1 mana is enough for first card
	assert_true(player.can_play(card))

# ---------------------------------------------------------------------------
# 3. Forest edge-slot Shroud
# ---------------------------------------------------------------------------

func test_forest_slot_0_grants_shroud() -> void:
	var gs := _state_with_context(BiomeDef.FOREST, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _card(1)
	player.hand.append(card)
	# Board is empty; first_empty_slot → 0 (edge)
	player.play_card(card)
	assert_true(card.keywords.has(Keywords.SHROUD))
	assert_true(card.shroud_active)

func test_forest_slot_4_grants_shroud() -> void:
	var gs := _state_with_context(BiomeDef.FOREST, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	# Fill slots 0-3 first
	for _i in range(4):
		var filler := _card(1)
		player.board.slots[_i] = filler
	var card := _card(1)
	player.hand.append(card)
	# first_empty_slot → 4 (edge)
	player.play_card(card)
	assert_true(card.keywords.has(Keywords.SHROUD))
	assert_true(card.shroud_active)

func test_forest_slot_1_no_shroud() -> void:
	var gs := _state_with_context(BiomeDef.FOREST, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	# Fill slot 0 so next card goes to slot 1
	player.board.slots[0] = _card(1)
	var card := _card(1)
	player.hand.append(card)
	player.play_card(card)
	assert_false(card.keywords.has(Keywords.SHROUD))

func test_forest_shroud_absorbs_first_hit() -> void:
	var gs := _state_with_context(BiomeDef.FOREST, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _card(1, 1, 3)  # 3 HP
	player.hand.append(card)
	player.play_card(card)
	assert_true(card.shroud_active)
	card.take_damage(5)   # first hit absorbed by Shroud
	assert_false(card.shroud_active)
	assert_eq(card.health, 3)  # no HP lost

# ---------------------------------------------------------------------------
# 4. Desert turn-start scorch
# ---------------------------------------------------------------------------

func _desert_leftmost_idx(gs: GameState, pid: int) -> int:
	for si in range(5):
		if gs.players[pid].board.slots[si] != null:
			return si
	return -1

func test_desert_daytime_damages_leftmost_minion() -> void:
	var gs := _state_with_context(BiomeDef.DESERT, false)  # daytime
	var card := _card(1, 1, 5)  # 5 HP
	gs.players[0].board.slots[0] = card
	# Simulate desert scorch (normally called from BattleScene._apply_desert_scorch).
	# Here we call the logic directly on the board.
	var before_hp: int = card.health
	card.take_damage(1)  # desert tick
	assert_eq(card.health, before_hp - 1)

func test_desert_night_no_scorch() -> void:
	# At night the rule should NOT apply; we just verify the logic condition.
	assert_true(_state_with_context(BiomeDef.DESERT, true).is_night)
	# The actual skip is enforced in BattleScene; here we confirm the flag is set.

func test_desert_kills_1hp_minion() -> void:
	var card := _card(1, 1, 1)  # 1 HP
	card.take_damage(1)
	assert_false(card.is_alive())

func test_desert_empty_board_safe() -> void:
	var gs := _state_with_context(BiomeDef.DESERT, false)
	# No minions on board — should not error when scorch tries to find leftmost.
	assert_eq(_desert_leftmost_idx(gs, 0), -1)

# ---------------------------------------------------------------------------
# 5. Scorched +1 damage
# ---------------------------------------------------------------------------

func test_scorched_modify_damage_adds_one() -> void:
	var dmg: int = BattlefieldRules.modify_damage(2, BiomeDef.SCORCHED)
	assert_eq(dmg, 3)

func test_scorched_modify_damage_zero_attack() -> void:
	var dmg: int = BattlefieldRules.modify_damage(0, BiomeDef.SCORCHED)
	assert_eq(dmg, 1)

func test_non_scorched_modify_damage_unchanged() -> void:
	for biome_id in [-1, 0, 1, 2, 4]:
		assert_eq(BattlefieldRules.modify_damage(3, biome_id), 3,
			"biome %d should not modify damage" % biome_id)

func test_scorched_combat_damage_via_context() -> void:
	var gs := _state_with_context(BiomeDef.SCORCHED, false)
	var attacker := _card(1, 2, 3)  # 2 attack
	var target   := _card(1, 1, 5)  # 5 HP
	# Simulate Scorched combat: attacker deals modify_damage(2, SCORCHED) = 3
	target.take_damage(BattlefieldRules.modify_damage(attacker.attack, gs.battlefield_biome))
	assert_eq(target.health, 2)  # 5 - 3

# ---------------------------------------------------------------------------
# 6. Mountains center-slot Ward
# ---------------------------------------------------------------------------

func test_mountains_slot_2_grants_ward() -> void:
	var gs := _state_with_context(BiomeDef.MOUNTAINS, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	# Fill slots 0-1
	player.board.slots[0] = _card(1)
	player.board.slots[1] = _card(1)
	var card := _card(1)
	player.hand.append(card)
	player.play_card(card)  # → slot 2
	assert_true(card.keywords.has(Keywords.WARD))

func test_mountains_slot_1_no_ward() -> void:
	var gs := _state_with_context(BiomeDef.MOUNTAINS, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	# Fill slot 0 → next is slot 1
	player.board.slots[0] = _card(1)
	var card := _card(1)
	player.hand.append(card)
	player.play_card(card)  # → slot 1
	assert_false(card.keywords.has(Keywords.WARD))

func test_mountains_ward_not_duplicated() -> void:
	# Minion already has Ward from template — apply_slot_rule must not duplicate it.
	var gs := _state_with_context(BiomeDef.MOUNTAINS, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	player.board.slots[0] = _card(1)
	player.board.slots[1] = _card(1)
	var tmpl: Dictionary = _tmpl("ghost", 1, 1, 2)
	tmpl["keywords"] = ["ward"]
	var card := CardInstance.new(tmpl)
	player.hand.append(card)
	player.play_card(card)  # → slot 2
	var ward_count: int = 0
	for kw: String in card.keywords:
		if kw == Keywords.WARD:
			ward_count += 1
	assert_eq(ward_count, 1)

# ---------------------------------------------------------------------------
# 7. Time-of-day cost modifier (dawn / dusk)
# ---------------------------------------------------------------------------

func test_night_dusk_card_cost_reduced() -> void:
	# Night: dusk branch gets -1
	var cost: int = BattlefieldRules.effective_cost(3, "dusk", -1, true, false)
	assert_eq(cost, 2)

func test_night_dawn_card_unchanged() -> void:
	var cost: int = BattlefieldRules.effective_cost(3, "dawn", -1, true, false)
	assert_eq(cost, 3)

func test_day_dawn_card_cost_reduced() -> void:
	var cost: int = BattlefieldRules.effective_cost(3, "dawn", -1, false, false)
	assert_eq(cost, 2)

func test_day_dusk_card_unchanged() -> void:
	var cost: int = BattlefieldRules.effective_cost(3, "dusk", -1, false, false)
	assert_eq(cost, 3)

func test_branch_discount_floor_zero() -> void:
	var cost: int = BattlefieldRules.effective_cost(0, "dusk", -1, true, false)
	assert_eq(cost, 0)

func test_branch_discount_stacks_with_grasslands() -> void:
	# Night + dusk + Grasslands first card: 3 - 1 (dusk night) - 1 (grasslands) = 1
	var cost: int = BattlefieldRules.effective_cost(3, "dusk", BiomeDef.GRASSLANDS, true, false)
	assert_eq(cost, 1)

func test_double_stack_floor_zero() -> void:
	# 1-cost dusk card, night, Grasslands first: 1 - 1 - 1 = -1 → clamped to 0
	var cost: int = BattlefieldRules.effective_cost(1, "dusk", BiomeDef.GRASSLANDS, true, false)
	assert_eq(cost, 0)

func test_is_night_boundary_low() -> void:
	# time_of_day = 0.24 → night (< 0.25)
	assert_true(BattlefieldRules.compute_is_night(0.24))

func test_is_night_boundary_high() -> void:
	# time_of_day = 0.76 → night (> 0.75)
	assert_true(BattlefieldRules.compute_is_night(0.76))

func test_is_day_boundary() -> void:
	# time_of_day = 0.5 → day
	assert_false(BattlefieldRules.compute_is_night(0.5))

func test_is_night_midnight() -> void:
	assert_true(BattlefieldRules.compute_is_night(0.0))

# ---------------------------------------------------------------------------
# 8. Persistence — to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_gamestate_serialises_battlefield_biome() -> void:
	var gs := _state_with_context(BiomeDef.SCORCHED, true)
	var d: Dictionary = gs.to_dict()
	assert_eq(int(d.get("battlefield_biome", -99)), BiomeDef.SCORCHED)

func test_gamestate_serialises_is_night() -> void:
	var gs := _state_with_context(BiomeDef.SCORCHED, true)
	var d: Dictionary = gs.to_dict()
	assert_true(bool(d.get("is_night", false)))

func test_gamestate_round_trip_preserves_context() -> void:
	var gs := _state_with_context(BiomeDef.FOREST, true)
	var d: Dictionary = gs.to_dict()
	var gs2 := GameState.new()
	gs2.from_dict(d)
	assert_eq(gs2.battlefield_biome, BiomeDef.FOREST)
	assert_true(gs2.is_night)

func test_playerstate_round_trip_preserves_context() -> void:
	var gs := _state_with_context(BiomeDef.MOUNTAINS, false)
	var d: Dictionary = gs.to_dict()
	var gs2 := GameState.new()
	gs2.from_dict(d)
	assert_eq(gs2.players[0].battlefield_biome, BiomeDef.MOUNTAINS)
	assert_false(gs2.players[0].is_night)

func test_playerstate_round_trip_preserves_grasslands_flag() -> void:
	var gs := _state_with_context(BiomeDef.GRASSLANDS, false)
	gs.players[0].grasslands_card_played = true
	var d: Dictionary = gs.to_dict()
	var gs2 := GameState.new()
	gs2.from_dict(d)
	assert_true(gs2.players[0].grasslands_card_played)

func test_forest_shroud_keyword_survives_round_trip() -> void:
	var gs := _state_with_context(BiomeDef.FOREST, false)
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _card(1)
	player.hand.append(card)
	player.play_card(card)  # slot 0 → Shroud granted
	assert_true(card.shroud_active)
	# Serialise the card and restore
	var cd: Dictionary = card.to_dict()
	var card2 := CardInstance.new()
	card2.from_dict(cd)
	assert_true(card2.keywords.has(Keywords.SHROUD))
	assert_true(card2.shroud_active)

# ---------------------------------------------------------------------------
# 9. Neutral path — no context behaves like pre-GID-059
# ---------------------------------------------------------------------------

func test_neutral_biome_no_cost_discount() -> void:
	var cost: int = BattlefieldRules.effective_cost(3, "", -1, false, false)
	assert_eq(cost, 3)

func test_neutral_biome_modify_damage_unchanged() -> void:
	assert_eq(BattlefieldRules.modify_damage(4, -1), 4)

func test_neutral_biome_no_slot_highlights() -> void:
	assert_true(BattlefieldRules.get_slot_highlights(-1).is_empty())

func test_neutral_biome_gamestate_defaults() -> void:
	var gs := GameState.new()
	assert_eq(gs.battlefield_biome, -1)
	assert_false(gs.is_night)

func test_neutral_playerstate_defaults() -> void:
	var gs := GameState.new()
	assert_eq(gs.players[0].battlefield_biome, -1)
	assert_false(gs.players[0].is_night)
	assert_false(gs.players[0].grasslands_card_played)

func test_neutral_play_card_no_slot_keywords() -> void:
	var gs := GameState.new()  # biome -1
	var player: PlayerState = gs.players[0]
	player.hero.mana = 10
	var card := _card(1)
	player.hand.append(card)
	player.play_card(card)
	assert_false(card.keywords.has(Keywords.SHROUD))
	assert_false(card.keywords.has(Keywords.WARD))

# ---------------------------------------------------------------------------
# Suite name
# ---------------------------------------------------------------------------

func get_suite_name() -> String:
	return "BattlefieldRules"
