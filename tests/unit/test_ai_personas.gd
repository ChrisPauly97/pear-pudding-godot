## Unit tests for the GID-112 AI persona layer in BasicAI.
##
## `test_basic_ai.gd` covers the mechanics shared by every persona (action
## Callables, damage, board cleanup, summoning sickness). This suite covers only
## what personas and the lethal check *change*, and is written as contrast
## pairs wherever possible: the same board driven by two personas must produce
## different outcomes. A persona test that passes under every persona is not
## testing the persona.
##
## GameState requires the CardRegistry autoload, so run via:
##   godot --headless --path . -s tests/runner.gd
extends "res://tests/framework/test_case.gd"

const BasicAI = preload("res://ai/BasicAI.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tmpl(
	id: String, cost: int, attack: int, health: int, card_class: String = "minion"
) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "cost": cost,
		"attack": attack, "health": health,
		"card_class": card_class, "description": "",
	}


func _card(id: String, cost: int, attack: int, health: int) -> CardInstance:
	return CardInstance.new(_tmpl(id, cost, attack, health))


func _spell(id: String, cost: int) -> CardInstance:
	return CardInstance.new(_tmpl(id, cost, 0, 0, "spell"))


func _ward_card(id: String, cost: int, attack: int, health: int) -> CardInstance:
	var tmpl := _tmpl(id, cost, attack, health)
	tmpl["keywords"] = ["ward"]
	return CardInstance.new(tmpl)


## GameState with player 1 (the AI) to act and an empty AI hand, so hand plays
## never interfere with attack-targeting assertions.
func _ai_turn_state() -> GameState:
	var gs := GameState.new()
	gs.end_turn()  # player 0 ends -> player 1 (AI) acts
	gs.current_player().hand.clear()
	gs.opponent().board.slots.fill(null)
	return gs


func _place(player: PlayerState, card: CardInstance) -> void:
	card.summoning_sick = false
	player.board.add_card(card)


func _run(gs: GameState, persona: String) -> void:
	for a in BasicAI.decide_turn(gs, persona):
		a.call()


# ---------------------------------------------------------------------------
# Persona changes attack targeting — contrast pairs on an identical board
# ---------------------------------------------------------------------------

func test_basic_attacks_minion_rather_than_hero() -> void:
	var gs := _ai_turn_state()
	var attacker := _card("attacker", 1, 2, 4)
	_place(gs.current_player(), attacker)
	var blocker := _card("blocker", 1, 1, 5)
	_place(gs.opponent(), blocker)
	var hero_hp: int = gs.opponent().hero.health

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_eq(gs.opponent().hero.health, hero_hp, "basic should not hit the hero past a minion")
	assert_eq(blocker.health, 3, "blocker should have taken the 2 damage")


func test_aggro_ignores_minion_and_hits_hero() -> void:
	# Identical board to the basic case above — only the persona differs.
	var gs := _ai_turn_state()
	var attacker := _card("attacker", 1, 2, 4)
	_place(gs.current_player(), attacker)
	var blocker := _card("blocker", 1, 1, 5)
	_place(gs.opponent(), blocker)
	var hero_hp: int = gs.opponent().hero.health

	_run(gs, BasicAI.PERSONA_AGGRO)

	assert_eq(gs.opponent().hero.health, hero_hp - 2, "aggro should race the hero")
	assert_eq(blocker.health, 5, "aggro should have left the minion alone")


func test_default_persona_matches_basic() -> void:
	# Back-compat: callers that never pass a persona must get the old behaviour.
	var gs := _ai_turn_state()
	_place(gs.current_player(), _card("attacker", 1, 2, 4))
	var blocker := _card("blocker", 1, 1, 5)
	_place(gs.opponent(), blocker)
	var hero_hp: int = gs.opponent().hero.health

	for a in BasicAI.decide_turn(gs):
		a.call()

	assert_eq(gs.opponent().hero.health, hero_hp)
	assert_eq(blocker.health, 3)


# ---------------------------------------------------------------------------
# Control: trades only when the trade is worth it
# ---------------------------------------------------------------------------

func test_control_takes_a_favorable_trade() -> void:
	# 5 attack kills a 3-health target, and 1 return damage does not kill a
	# 5-health attacker — strictly favorable, so control should take it.
	var gs := _ai_turn_state()
	var attacker := _card("attacker", 1, 5, 5)
	_place(gs.current_player(), attacker)
	var target := _card("target", 1, 1, 3)
	_place(gs.opponent(), target)
	var hero_hp: int = gs.opponent().hero.health

	_run(gs, BasicAI.PERSONA_CONTROL)

	assert_does_not_have(gs.opponent().board.get_cards(), target, "target should be dead")
	assert_eq(gs.opponent().hero.health, hero_hp, "control should not have gone face")
	assert_eq(attacker.health, 4, "attacker takes 1 return damage")


func test_control_skips_an_unfavorable_trade_and_hits_hero() -> void:
	# 2 attack cannot kill a 10-health target, so it is not a trade at all.
	var gs := _ai_turn_state()
	_place(gs.current_player(), _card("attacker", 1, 2, 5))
	var target := _card("target", 1, 1, 10)
	_place(gs.opponent(), target)
	var hero_hp: int = gs.opponent().hero.health

	_run(gs, BasicAI.PERSONA_CONTROL)

	assert_eq(target.health, 10, "target should be untouched")
	assert_eq(gs.opponent().hero.health, hero_hp - 2, "control should pressure the hero instead")


func test_control_trades_down_into_a_bigger_threat() -> void:
	# Attacker dies doing it, but removes a strictly bigger attacker — the
	# `worth_trading_down` branch. Both minions should leave the board.
	var gs := _ai_turn_state()
	var attacker := _card("attacker", 1, 5, 2)
	_place(gs.current_player(), attacker)
	var threat := _card("threat", 1, 6, 5)
	_place(gs.opponent(), threat)

	_run(gs, BasicAI.PERSONA_CONTROL)

	assert_does_not_have(gs.opponent().board.get_cards(), threat, "bigger threat should be dead")
	assert_does_not_have(gs.current_player().board.get_cards(), attacker, "attacker trades down")


# ---------------------------------------------------------------------------
# Lethal check — the behaviour the goal says was missing entirely
# ---------------------------------------------------------------------------

func test_lethal_goes_face_even_when_a_minion_is_available() -> void:
	# Basic would normally trade with the minion. With lethal on board it must
	# ignore the minion and kill the hero instead.
	var gs := _ai_turn_state()
	gs.opponent().hero.health = 3
	_place(gs.current_player(), _card("attacker", 1, 5, 5))
	var blocker := _card("blocker", 1, 1, 5)
	_place(gs.opponent(), blocker)

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_lte(gs.opponent().hero.health, 0, "AI should have taken the kill")
	assert_eq(blocker.health, 5, "AI should not have wasted the attack on a minion")


func test_no_lethal_when_damage_is_one_short() -> void:
	# Boundary: 4 damage into 5 health is not lethal, so basic trades as usual.
	var gs := _ai_turn_state()
	gs.opponent().hero.health = 5
	_place(gs.current_player(), _card("attacker", 1, 4, 5))
	var blocker := _card("blocker", 1, 1, 9)
	_place(gs.opponent(), blocker)

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_eq(gs.opponent().hero.health, 5, "hero should be untouched")
	assert_eq(blocker.health, 5, "basic should have traded with the minion")


func test_lethal_counts_damage_across_several_attackers() -> void:
	# Neither attacker is lethal alone; together they are.
	var gs := _ai_turn_state()
	gs.opponent().hero.health = 6
	_place(gs.current_player(), _card("a1", 1, 3, 5))
	_place(gs.current_player(), _card("a2", 1, 3, 5))
	var blocker := _card("blocker", 1, 1, 9)
	_place(gs.opponent(), blocker)

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_lte(gs.opponent().hero.health, 0, "both attackers should have gone face")
	assert_eq(blocker.health, 9, "neither should have traded")


func test_lethal_respects_armor() -> void:
	# 5 damage into 3 health is lethal, but not through 4 armor.
	var gs := _ai_turn_state()
	gs.opponent().hero.health = 3
	gs.opponent().hero.status_effects["armor"] = 4
	_place(gs.current_player(), _card("attacker", 1, 5, 5))
	var blocker := _card("blocker", 1, 1, 9)
	_place(gs.opponent(), blocker)

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_gt(gs.opponent().hero.health, 0, "armor should have denied the lethal line")
	assert_eq(blocker.health, 4, "AI should have traded instead")


# ---------------------------------------------------------------------------
# Ward is mandatory and outranks both persona and lethal
# ---------------------------------------------------------------------------

func test_ward_blocks_a_lethal_line() -> void:
	var gs := _ai_turn_state()
	gs.opponent().hero.health = 3
	_place(gs.current_player(), _card("attacker", 1, 5, 5))
	var warden := _ward_card("warden", 1, 1, 9)
	_place(gs.opponent(), warden)

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_eq(gs.opponent().hero.health, 3, "hero is not a legal target behind Ward")
	assert_eq(warden.health, 4, "Ward minion should have absorbed the attack")


func test_aggro_still_respects_ward() -> void:
	var gs := _ai_turn_state()
	_place(gs.current_player(), _card("attacker", 1, 3, 5))
	var warden := _ward_card("warden", 1, 1, 9)
	_place(gs.opponent(), warden)
	var hero_hp: int = gs.opponent().hero.health

	_run(gs, BasicAI.PERSONA_AGGRO)

	assert_eq(gs.opponent().hero.health, hero_hp, "aggro cannot ignore Ward")
	assert_eq(warden.health, 6)


func test_ward_is_taken_over_a_softer_non_ward_target() -> void:
	var gs := _ai_turn_state()
	_place(gs.current_player(), _card("attacker", 1, 3, 5))
	var soft := _card("soft", 1, 1, 3)
	_place(gs.opponent(), soft)
	var warden := _ward_card("warden", 1, 1, 9)
	_place(gs.opponent(), warden)

	_run(gs, BasicAI.PERSONA_CONTROL)

	assert_eq(soft.health, 3, "non-Ward minion is not a legal target")
	assert_eq(warden.health, 6)


# ---------------------------------------------------------------------------
# Persona changes hand play order
# ---------------------------------------------------------------------------

func test_aggro_plays_the_highest_attack_card_first() -> void:
	# Both cost 3 with only 3 mana, so exactly one gets played — whichever the
	# persona ordered first.
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(3)
	var weak := _card("weak", 3, 1, 2)
	var strong := _card("strong", 3, 5, 2)
	ai.hand.assign([weak, strong] as Array[CardInstance])

	_run(gs, BasicAI.PERSONA_AGGRO)

	assert_has(ai.board.get_cards(), strong, "aggro should field the bigger body")
	assert_does_not_have(ai.board.get_cards(), weak)


func test_basic_plays_in_raw_hand_order() -> void:
	# Same hand as above; basic must preserve pre-goal behaviour.
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(3)
	var weak := _card("weak", 3, 1, 2)
	var strong := _card("strong", 3, 5, 2)
	ai.hand.assign([weak, strong] as Array[CardInstance])

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_has(ai.board.get_cards(), weak, "basic takes the hand in order")
	assert_does_not_have(ai.board.get_cards(), strong)


func test_control_develops_the_board_before_spending_on_a_spell() -> void:
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(2)
	var spell := _spell("hex", 2)
	var minion := _card("body", 2, 2, 2)
	ai.hand.assign([spell, minion] as Array[CardInstance])

	_run(gs, BasicAI.PERSONA_CONTROL)

	assert_has(ai.board.get_cards(), minion, "control develops first")
	assert_has(ai.hand, spell, "the spell should have been held, not cast")


func test_basic_casts_the_spell_first_from_the_same_hand() -> void:
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(2)
	var spell := _spell("hex", 2)
	var minion := _card("body", 2, 2, 2)
	ai.hand.assign([spell, minion] as Array[CardInstance])

	_run(gs, BasicAI.PERSONA_BASIC)

	assert_does_not_have(ai.hand, spell, "basic casts in hand order")
	assert_does_not_have(ai.board.get_cards(), minion, "no mana left for the body")


# ---------------------------------------------------------------------------
# Intent banner: tier gates specificity but must never contradict the plan
# ---------------------------------------------------------------------------

func test_tier1_banner_names_the_card() -> void:
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(3)
	ai.hand.assign([_card("ghoul", 1, 2, 2)] as Array[CardInstance])

	var text: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_BASIC, 1)

	assert_true(text.contains("Ghoul"), "tier 1 should keep its teaching value, got: %s" % text)


func test_higher_tier_banner_hides_the_card_name() -> void:
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(3)
	ai.hand.assign([_card("ghoul", 1, 2, 2)] as Array[CardInstance])

	for tier: int in [2, 3, 4]:
		var text: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_AGGRO, tier)
		assert_false(text.contains("Ghoul"), "tier %d leaked the card name: %s" % [tier, text])
		assert_gt(text.length(), 0, "tier %d produced an empty banner" % tier)


func test_higher_tier_banner_is_persona_flavored() -> void:
	var gs := _ai_turn_state()
	var ai := gs.current_player()
	ai.hero.gain_mana_for_turn(3)
	ai.hand.assign([_card("ghoul", 1, 2, 2)] as Array[CardInstance])

	var aggro: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_AGGRO, 3)
	var control: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_CONTROL, 3)

	assert_ne(aggro, control, "personas should read differently at higher tiers")


func test_tier1_banner_names_the_target_the_ai_actually_attacks() -> void:
	# The banner must not lie: control takes the favorable trade, so the banner
	# must name that same minion rather than the hero.
	var gs := _ai_turn_state()
	_place(gs.current_player(), _card("attacker", 1, 5, 5))
	_place(gs.opponent(), _card("target", 1, 1, 3))

	var text: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_CONTROL, 1)

	assert_true(text.contains("Target"), "banner should name the traded minion, got: %s" % text)
	assert_false(text.contains("hero"), "banner should not claim a hero attack, got: %s" % text)


func test_banner_reports_hero_attack_when_aggro_goes_face() -> void:
	var gs := _ai_turn_state()
	_place(gs.current_player(), _card("attacker", 1, 2, 4))
	_place(gs.opponent(), _card("blocker", 1, 1, 5))

	var text: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_AGGRO, 1)

	assert_true(text.contains("hero"), "aggro banner should say hero, got: %s" % text)
	assert_false(text.contains("Blocker"), "aggro is not attacking the blocker, got: %s" % text)


func test_banner_falls_back_when_nothing_can_act() -> void:
	var gs := _ai_turn_state()
	gs.current_player().hero.mana = 0

	var text: String = BasicAI.describe_turn(gs, BasicAI.PERSONA_CONTROL, 1)

	assert_eq(text, "Enemy is thinking...")
