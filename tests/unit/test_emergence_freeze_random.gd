## GID-183 / TID-769: emergence_freeze_random (Displacer) freezes one random enemy
## minion when placed. Reuses the existing "freeze" status; damage is not involved.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")

func _minion(health: int = 5) -> CardInstance:
	return CardInstance.new({
		"id": "unit", "name": "Unit", "cost": 1, "attack": 1, "health": health,
		"card_class": "minion", "description": "",
	})

func _displacer(power: int) -> CardInstance:
	return CardInstance.new({
		"id": "displacer", "name": "Displacer", "cost": 4, "attack": 2, "health": 4,
		"card_class": "minion", "description": "", "magic_type": "rift",
		"magic_branch": "fracture", "emergence_effect": "emergence_freeze_random",
		"emergence_power": power,
	})

func _resolver(gs: GameState) -> SpellEffectResolver:
	var r := SpellEffectResolver.new()
	r.setup(gs)
	return r

func test_freezes_exactly_one_random_enemy_minion() -> void:
	var gs := GameState.new()
	var foes: Array[CardInstance] = [_minion(), _minion(), _minion()]
	for foe: CardInstance in foes:
		gs.players[1].board.add_card(foe)
	_resolver(gs).resolve_emergence(_displacer(1), 0)
	var frozen: int = 0
	for foe: CardInstance in foes:
		if foe.has_status("freeze"):
			frozen += 1
			assert_eq(foe.get_status_value("freeze"), 1)
	assert_eq(frozen, 1, "exactly one enemy minion should be frozen")

func test_freeze_duration_is_the_emergence_power() -> void:
	var gs := GameState.new()
	var foe := _minion()
	gs.players[1].board.add_card(foe)
	_resolver(gs).resolve_emergence(_displacer(2), 0)
	assert_eq(foe.get_status_value("freeze"), 2)

func test_never_freezes_friendly_minions() -> void:
	var gs := GameState.new()
	var mine := _minion()
	gs.players[0].board.add_card(mine)
	_resolver(gs).resolve_emergence(_displacer(1), 0)
	assert_false(mine.has_status("freeze"))

func test_empty_enemy_board_is_a_no_op() -> void:
	var gs := GameState.new()
	var mine := _minion()
	gs.players[0].board.add_card(mine)
	_resolver(gs).resolve_emergence(_displacer(1), 0)
	assert_false(mine.has_status("freeze"))
	assert_eq(gs.players[1].board.get_cards().size(), 0)

func test_rift_allies_registered_with_their_branches() -> void:
	var expected: Dictionary = {
		"flux_skitter": "flux", "flux_blinkfox": "flux",
		"flux_warp_adept": "flux", "flux_temporal_rider": "flux",
		"fracture_shardling": "fracture", "fracture_mirror_wight": "fracture",
		"fracture_displacer": "fracture", "fracture_unmaker": "fracture",
	}
	for id: String in expected.keys():
		var tmpl: Dictionary = CardRegistry.get_template(id)
		assert_false(tmpl.is_empty(), "%s is not registered" % id)
		assert_eq(str(tmpl.get("magic_type", "")), "rift")
		assert_eq(str(tmpl.get("magic_branch", "")), str(expected[id]))
	var displacer: Dictionary = CardRegistry.get_template("fracture_displacer")
	assert_eq(str(displacer.get("emergence_effect", "")), "emergence_freeze_random")
