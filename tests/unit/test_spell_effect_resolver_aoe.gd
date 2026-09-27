## GID-135 / TID-554: AoE spells must hit every living enemy side in an adds/team
## fight (team battle, co-op boss vs. all allies), not just GameState.opponent()'s
## single lowest-HP auto-target. 2-player behaviour is unchanged (enemy_sides()
## is always [opponent()] there).
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")

var _deck: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
	"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]

func _minion(attack: int = 1, health: int = 5) -> CardInstance:
	return CardInstance.new({
		"id": "unit", "name": "Unit", "cost": 1, "attack": attack, "health": health,
		"card_class": "minion", "description": "",
	})

func _spell(effect: String, power: int = 3) -> CardInstance:
	return CardInstance.new({
		"id": "spell", "name": "Spell", "cost": 1, "attack": 0, "health": 0,
		"card_class": "spell", "description": "", "spell_effect": effect, "spell_power": power,
	})

func _team_battle() -> GameState:
	var gs := GameState.new()
	gs.setup_team_battle(
		func(_i: int, ps: PlayerState) -> void: ps.build_deck(_deck),
		func(_i: int, ps: PlayerState) -> void: ps.build_deck(_deck))
	return gs

func _coop_battle(n_allies: int = 2) -> GameState:
	var gs := GameState.new()
	gs.setup_coop_battle(n_allies,
		func(_i: int, ps: PlayerState) -> void: ps.build_deck(_deck),
		func(ps: PlayerState) -> void: ps.build_deck(_deck))
	return gs

func _resolver(gs: GameState) -> SpellEffectResolver:
	var r := SpellEffectResolver.new()
	r.setup(gs)
	return r

# ---------------------------------------------------------------------------
# enemy_sides()
# ---------------------------------------------------------------------------

func test_two_player_enemy_sides_is_just_opponent() -> void:
	var gs := GameState.new()
	assert_eq(gs.enemy_sides(0), [gs.players[1]])
	assert_eq(gs.enemy_sides(1), [gs.players[0]])

func test_team_battle_enemy_sides_is_whole_other_team() -> void:
	var gs := _team_battle()
	# players interleaved [teamA_0, teamB_0, teamA_1, teamB_1].
	var sides: Array[PlayerState] = gs.enemy_sides(0)
	assert_eq(sides.size(), 2)
	assert_true(sides.has(gs.players[1]))
	assert_true(sides.has(gs.players[3]))

func test_team_battle_enemy_sides_excludes_dead_member() -> void:
	var gs := _team_battle()
	gs.players[3].hero.health = 0
	var sides: Array[PlayerState] = gs.enemy_sides(0)
	assert_eq(sides, [gs.players[1]])

func test_coop_boss_turn_enemy_sides_is_every_alive_ally() -> void:
	var gs := _coop_battle(3)
	var boss_idx: int = gs.players.size() - 1
	var sides: Array[PlayerState] = gs.enemy_sides(boss_idx)
	assert_eq(sides.size(), 3)

func test_coop_boss_turn_enemy_sides_excludes_downed_ally() -> void:
	var gs := _coop_battle(3)
	var boss_idx: int = gs.players.size() - 1
	gs.players[1].hero.health = 0
	var sides: Array[PlayerState] = gs.enemy_sides(boss_idx)
	assert_eq(sides.size(), 2)
	assert_false(sides.has(gs.players[1]))

func test_coop_ally_turn_enemy_sides_is_boss_only() -> void:
	var gs := _coop_battle(2)
	var boss_idx: int = gs.players.size() - 1
	assert_eq(gs.enemy_sides(0), [gs.players[boss_idx]])

# ---------------------------------------------------------------------------
# SpellEffectResolver: AoE effects use every enemy side
# ---------------------------------------------------------------------------

func test_deal_damage_all_hits_every_enemy_team_member_board() -> void:
	var gs := _team_battle()
	var foe_a := _minion(1, 10)
	var foe_b := _minion(1, 10)
	gs.players[1].board.add_card(foe_a)
	gs.players[3].board.add_card(foe_b)
	_resolver(gs).resolve_spell(_spell("deal_damage_all", 3), 0)
	assert_eq(foe_a.health, 7)
	assert_eq(foe_b.health, 7)

func test_deal_damage_all_full_hits_every_enemy_hero() -> void:
	var gs := _team_battle()
	var hp1: int = gs.players[1].hero.health
	var hp3: int = gs.players[3].hero.health
	_resolver(gs).resolve_spell(_spell("deal_damage_all_full", 4), 0)
	assert_eq(gs.players[1].hero.health, hp1 - 4)
	assert_eq(gs.players[3].hero.health, hp3 - 4)

func test_apply_poison_all_hits_every_enemy_team_member_board() -> void:
	var gs := _team_battle()
	var foe_a := _minion(1, 10)
	var foe_b := _minion(1, 10)
	gs.players[1].board.add_card(foe_a)
	gs.players[3].board.add_card(foe_b)
	_resolver(gs).resolve_spell(_spell("apply_poison_all", 2), 0)
	assert_eq(foe_a.get_status_value("poison"), 2)
	assert_eq(foe_b.get_status_value("poison"), 2)

func test_freeze_all_hits_every_enemy_team_member_board() -> void:
	var gs := _team_battle()
	var foe_a := _minion(1, 10)
	var foe_b := _minion(1, 10)
	gs.players[1].board.add_card(foe_a)
	gs.players[3].board.add_card(foe_b)
	_resolver(gs).resolve_spell(_spell("freeze_all", 0), 0)
	assert_true(foe_a.has_status("freeze"))
	assert_true(foe_b.has_status("freeze"))

func test_debuff_attack_hits_every_enemy_team_member_board() -> void:
	var gs := _team_battle()
	var foe_a := _minion(5, 10)
	var foe_b := _minion(5, 10)
	gs.players[1].board.add_card(foe_a)
	gs.players[3].board.add_card(foe_b)
	_resolver(gs).resolve_spell(_spell("debuff_attack", 2), 0)
	assert_eq(foe_a.attack, 3)
	assert_eq(foe_b.attack, 3)

func test_destroy_low_hp_hits_every_enemy_team_member_board() -> void:
	var gs := _team_battle()
	var foe_a := _minion(1, 2)
	var foe_b := _minion(1, 2)
	gs.players[1].board.add_card(foe_a)
	gs.players[3].board.add_card(foe_b)
	_resolver(gs).resolve_spell(_spell("destroy_low_hp", 3), 0)
	assert_false(gs.players[1].board.get_cards().has(foe_a))
	assert_false(gs.players[3].board.get_cards().has(foe_b))

func test_coop_boss_aoe_hits_every_ally_not_just_lowest_hp() -> void:
	var gs := _coop_battle(2)
	var boss_idx: int = gs.players.size() - 1
	var foe_a := _minion(1, 10)
	var foe_b := _minion(1, 10)
	gs.players[0].board.add_card(foe_a)
	gs.players[1].board.add_card(foe_b)
	_resolver(gs).resolve_spell(_spell("deal_damage_all", 3), boss_idx)
	assert_eq(foe_a.health, 7, "previously only the lowest-HP ally was hit — same bug, fixed here too")
	assert_eq(foe_b.health, 7)

func test_two_player_aoe_unchanged() -> void:
	var gs := GameState.new()
	var foe := _minion(1, 10)
	gs.players[1].board.add_card(foe)
	_resolver(gs).resolve_spell(_spell("deal_damage_all", 3), 0)
	assert_eq(foe.health, 7)
