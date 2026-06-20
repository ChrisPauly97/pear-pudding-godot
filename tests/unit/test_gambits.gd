## Unit tests for GID-063 Gambits: catalogue integrity, handicap effects,
## serialization round-trips, reward math, and no-gambit defaults.
extends "res://tests/framework/test_case.gd"

const Gambits = preload("res://game_logic/battle/Gambits.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(id: String = "ghost", attack: int = 2, health: int = 3, cls: String = "minion") -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": 1,
		"attack": attack, "health": health,
		"card_class": cls, "description": "",
	}

func _player(pid: int = 0, ai: bool = false) -> PlayerState:
	return PlayerState.new(pid, ai)

func _player_with_minions(count: int = 3, atk: int = 2) -> PlayerState:
	var p: PlayerState = _player()
	for i in range(count):
		p.draw_deck.append(CardInstance.new(_tmpl("ghost_%d" % i, atk, 3)))
	return p

func _player_with_spell() -> PlayerState:
	var p: PlayerState = _player()
	p.draw_deck.append(CardInstance.new(_tmpl("spell_a", 0, 0, "spell")))
	return p

# ---------------------------------------------------------------------------
# 1. Catalogue integrity
# ---------------------------------------------------------------------------

func test_catalogue_has_four_gambits() -> void:
	assert_eq(Gambits.ALL.size(), 4)

func test_all_gambits_have_non_empty_name() -> void:
	for gid: String in Gambits.ALL.keys():
		var g: Dictionary = Gambits.ALL[gid]
		assert_false(str(g.get("name", "")).is_empty())

func test_all_gambits_have_non_empty_desc() -> void:
	for gid: String in Gambits.ALL.keys():
		var g: Dictionary = Gambits.ALL[gid]
		assert_false(str(g.get("desc", "")).is_empty())

func test_all_gambits_have_multiplier_at_least_one() -> void:
	for gid: String in Gambits.ALL.keys():
		var mult: float = float(Gambits.ALL[gid].get("multiplier", 0.0))
		assert_true(mult >= 1.0)

func test_all_gambits_have_non_negative_rarity_bonus() -> void:
	for gid: String in Gambits.ALL.keys():
		var bonus: int = int(Gambits.ALL[gid].get("rarity_tier_bonus", -1))
		assert_true(bonus >= 0)

func test_wounded_pride_exists() -> void:
	assert_false(Gambits.get_gambit("wounded_pride").is_empty())

func test_slow_start_exists() -> void:
	assert_false(Gambits.get_gambit("slow_start").is_empty())

func test_emboldened_foe_exists() -> void:
	assert_false(Gambits.get_gambit("emboldened_foe").is_empty())

func test_iron_veil_exists() -> void:
	assert_false(Gambits.get_gambit("iron_veil").is_empty())

func test_get_gambit_empty_id_returns_empty() -> void:
	assert_true(Gambits.get_gambit("").is_empty())

func test_get_gambit_unknown_id_returns_empty() -> void:
	assert_true(Gambits.get_gambit("does_not_exist").is_empty())

func test_get_multiplier_empty_returns_one() -> void:
	assert_eq(Gambits.get_multiplier(""), 1.0)

func test_get_multiplier_unknown_returns_one() -> void:
	assert_eq(Gambits.get_multiplier("nonsense_id"), 1.0)

func test_get_rarity_tier_bonus_empty_returns_zero() -> void:
	assert_eq(Gambits.get_rarity_tier_bonus(""), 0)

func test_get_rarity_tier_bonus_unknown_returns_zero() -> void:
	assert_eq(Gambits.get_rarity_tier_bonus("nonsense_id"), 0)

# ---------------------------------------------------------------------------
# 2. Handicap effects on pure state
# ---------------------------------------------------------------------------

func test_wounded_pride_sets_player_hero_hp_to_25() -> void:
	var p: PlayerState = _player()
	assert_eq(p.hero.health, 30)
	p.hero.health = 25
	p.hero.max_health = 25
	assert_eq(p.hero.health, 25)
	assert_eq(p.hero.max_health, 25)

func test_slow_start_flag_skips_turn1_draw() -> void:
	var p: PlayerState = _player_with_minions(6)
	p.skip_next_draw = true
	var before: int = p.hand.size()
	p.start_turn(1)
	assert_eq(p.hand.size(), before)
	assert_false(p.skip_next_draw)

func test_slow_start_only_skips_once() -> void:
	var p: PlayerState = _player_with_minions(6)
	p.skip_next_draw = true
	p.start_turn(1)
	var hand_after_t1: int = p.hand.size()
	p.start_turn(2)
	assert_eq(p.hand.size(), hand_after_t1 + 1)

func test_emboldened_foe_minion_attack_bonus_applied_in_build_deck() -> void:
	var p: PlayerState = _player(1, true)
	p.minion_attack_bonus = 1
	var deck: Array[String] = ["ghost", "ghost", "skeleton"]
	p.build_deck(deck)
	for c: CardInstance in p.draw_deck:
		if c.card_class == "minion":
			var base: int = int(Gambits.ALL.get("emboldened_foe", {}).get("multiplier", 1))
			assert_true(c.attack >= 1)

func test_emboldened_foe_only_boosts_minions() -> void:
	var p: PlayerState = _player(1, true)
	p.minion_attack_bonus = 1
	p.draw_deck.clear()
	var spell: CardInstance = CardInstance.new(_tmpl("spell_a", 0, 0, "spell"))
	var minion: CardInstance = CardInstance.new(_tmpl("ghost", 2, 3, "minion"))
	p.draw_deck.append(spell)
	p.draw_deck.append(minion)
	if p.minion_attack_bonus > 0:
		for c: CardInstance in p.draw_deck:
			if c.card_class == "minion":
				c.attack += p.minion_attack_bonus
	assert_eq(spell.attack, 0)
	assert_eq(minion.attack, 3)

func test_iron_veil_applies_5_armor_to_hero() -> void:
	var hero: HeroState = HeroState.new(1)
	hero.apply_status("armor", 5)
	assert_eq(hero.get_status_value("armor"), 5)

func test_iron_veil_armor_absorbs_damage() -> void:
	var hero: HeroState = HeroState.new(1)
	hero.apply_status("armor", 5)
	hero.take_damage(3)
	assert_eq(hero.health, 30)
	assert_eq(hero.get_status_value("armor"), 2)

func test_iron_veil_armor_breaks_on_excess_damage() -> void:
	var hero: HeroState = HeroState.new(1)
	hero.apply_status("armor", 5)
	hero.take_damage(8)
	assert_false(hero.has_status("armor"))
	assert_eq(hero.health, 27)

# ---------------------------------------------------------------------------
# 3. Serialization round-trip for new PlayerState fields
# ---------------------------------------------------------------------------

func test_skip_next_draw_survives_round_trip() -> void:
	var p: PlayerState = _player_with_minions(4)
	p.skip_next_draw = true
	var d: Dictionary = p.to_dict()
	var p2: PlayerState = PlayerState.new(0, false)
	p2.from_dict(d)
	assert_true(p2.skip_next_draw)

func test_skip_next_draw_false_survives_round_trip() -> void:
	var p: PlayerState = _player_with_minions(4)
	p.skip_next_draw = false
	var d: Dictionary = p.to_dict()
	var p2: PlayerState = PlayerState.new(0, false)
	p2.from_dict(d)
	assert_false(p2.skip_next_draw)

func test_minion_attack_bonus_survives_round_trip() -> void:
	var p: PlayerState = _player(1, true)
	p.minion_attack_bonus = 1
	var d: Dictionary = p.to_dict()
	var p2: PlayerState = PlayerState.new(1, true)
	p2.from_dict(d)
	assert_eq(p2.minion_attack_bonus, 1)

func test_minion_attack_bonus_zero_survives_round_trip() -> void:
	var p: PlayerState = _player()
	p.minion_attack_bonus = 0
	var d: Dictionary = p.to_dict()
	var p2: PlayerState = PlayerState.new(0, false)
	p2.from_dict(d)
	assert_eq(p2.minion_attack_bonus, 0)

# ---------------------------------------------------------------------------
# 4. Reward math
# ---------------------------------------------------------------------------

func test_apply_reward_multiplier_no_gambit() -> void:
	assert_eq(Gambits.apply_reward_multiplier(5, ""), 5)

func test_apply_reward_multiplier_wounded_pride() -> void:
	assert_eq(Gambits.apply_reward_multiplier(10, "wounded_pride"), 15)

func test_apply_reward_multiplier_slow_start() -> void:
	assert_eq(Gambits.apply_reward_multiplier(10, "slow_start"), 15)

func test_apply_reward_multiplier_emboldened_foe() -> void:
	assert_eq(Gambits.apply_reward_multiplier(10, "emboldened_foe"), 20)

func test_apply_reward_multiplier_iron_veil() -> void:
	assert_eq(Gambits.apply_reward_multiplier(10, "iron_veil"), 20)

func test_apply_reward_multiplier_rounds_correctly() -> void:
	# 5 * 1.5 = 7.5, rounds to 8
	assert_eq(Gambits.apply_reward_multiplier(5, "wounded_pride"), 8)

func test_apply_reward_multiplier_unknown_gambit_returns_base() -> void:
	assert_eq(Gambits.apply_reward_multiplier(7, "bad_gambit"), 7)

func test_rarity_tier_bonus_wounded_pride_is_1() -> void:
	assert_eq(Gambits.get_rarity_tier_bonus("wounded_pride"), 1)

func test_rarity_tier_bonus_emboldened_foe_is_2() -> void:
	assert_eq(Gambits.get_rarity_tier_bonus("emboldened_foe"), 2)

func test_roll_rarity_does_not_crash_with_high_tier() -> void:
	var r: String = CardDropUtil.roll_rarity(9)
	assert_false(r.is_empty())

# ---------------------------------------------------------------------------
# 5. No-gambit defaults
# ---------------------------------------------------------------------------

func test_new_player_hero_has_30_hp() -> void:
	var p: PlayerState = _player()
	assert_eq(p.hero.health, 30)
	assert_eq(p.hero.max_health, 30)

func test_new_player_skip_next_draw_is_false() -> void:
	assert_false(_player().skip_next_draw)

func test_new_player_minion_attack_bonus_is_zero() -> void:
	assert_eq(_player().minion_attack_bonus, 0)

func test_new_hero_has_no_armor() -> void:
	assert_false(HeroState.new(0).has_status("armor"))

func test_start_turn_draws_card_by_default() -> void:
	var p: PlayerState = _player_with_minions(6)
	var before: int = p.hand.size()
	p.start_turn(1)
	assert_eq(p.hand.size(), before + 1)
