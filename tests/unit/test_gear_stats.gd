## GID-187 / TID-788: gear stats are boosts to the cards (GearStats + the combat hooks).
extends "res://tests/framework/test_case.gd"

const GearStats = preload("res://game_logic/items/GearStats.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")

func _spell(magic: String, power: int = 4) -> CardInstance:
	return CardInstance.new({"id": "bolt", "name": "Bolt", "cost": 1, "attack": 0, "health": 0,
		"card_class": "spell", "description": "", "spell_effect": "deal_damage_single", "spell_power": power,
		"magic_type": magic})

func _rt(tune: Dictionary = {}) -> RealtimeCombat:
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.hand.clear()
		p.draw_deck.clear()
	var t: Dictionary = {"swing_mult": 1.0, "swing_damage": 1.0, "swing_spread": 0.0, "enemy_swing_delay": 0.0,
		"crit_chance": 0.0, "enemy_crit_chance": 0.0, "heavy_every": 40.0}
	t.merge(tune, true)
	return RealtimeCombat.new(gs, [1, 1], CombatTuning.new(t))

func _run(rt: RealtimeCombat, seconds: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t: float = 0.0
	while t < seconds:
		out.append_array(rt.advance(0.1))
		t += 0.1
	return out

func test_stat_ids() -> void:
	assert_true(GearStats.is_stat("haste"))
	assert_true(GearStats.is_stat("mastery:dark"))
	assert_true(GearStats.is_stat("resist:physical"))
	assert_false(GearStats.is_stat("mastery:fire"))
	assert_false(GearStats.is_stat("versatility"))

func test_totals_sum_and_drop_unknown() -> void:
	var t: Dictionary = GearStats.totals([{"stats": {"haste": 3, "bogus": 9}}, {"stats": {"haste": 2.0}}, {}])
	assert_almost_eq(float(t["haste"]), 5.0)
	assert_false(t.has("bogus"))

func test_rating_worth_less_with_level_and_capped() -> void:
	var tune := CombatTuning.new()
	var at1: float = GearStats.pct(10.0, 1, tune)
	assert_almost_eq(at1, 10.0 / tune.get_f("stat_rating_base") / 100.0)
	assert_lt(GearStats.pct(10.0, 30, tune), at1, "old gear fades")
	assert_almost_eq(GearStats.pct(100000.0, 1, tune), tune.get_f("stat_pct_cap"))

func test_apply_flat_and_school_stats() -> void:
	var p := PlayerState.new(0, false)
	var hp: int = p.hero.max_health
	GearStats.apply(p, {"stamina": 7, "armor": 3, "intellect": 2, "mastery:dark": 10, "haste": 5}, 1)
	assert_eq(p.hero.max_health, hp + 7)
	assert_eq(p.hero.bonus_mana, 2)
	assert_eq(p.hero.get_status_value("armor"), 3)
	assert_almost_eq(float(p.school_power["dark"]), 0.1)
	assert_almost_eq(p.gear_stat("haste"), 0.05)

func test_build_reads_item_stats_and_resist() -> void:
	var built: Dictionary = BattleSetup.build({"seed": 2, "gear": [{"id": "", "stats": {"resist:dark": 20,
		"stamina": 5}}]})
	var me: PlayerState = (built["state"] as GameState).players[0]
	assert_almost_eq(DamageSchools.resist_of(me.hero.school_resist, "dark"), 0.2)
	assert_almost_eq(me.gear_stat("stamina"), 5.0)

func test_spell_and_attack_power_follow_card_school() -> void:
	var rt := _rt()
	var me: PlayerState = rt.state.players[0]
	me.gear = {"spell_power": 0.5, "attack_power": 0.25}
	var caster := PlayerCaster.new(rt)
	assert_eq(caster.modify_power(_spell("light"), 0, 4), 6, "spell power")
	assert_eq(caster.modify_power(_spell(""), 0, 4), 5, "physical card: attack power")
	assert_eq(caster.modify_power(_spell("light"), 1, 4), 4, "enemy casts unaffected")

func test_spell_and_physical_crit() -> void:
	var rt := _rt()
	var me: PlayerState = rt.state.players[0]
	var caster := PlayerCaster.new(rt)
	me.gear = {"spell_crit": 1.0}
	assert_eq(caster.modify_power(_spell("dark"), 0, 4), 6, "spell crit")
	assert_eq(caster.modify_power(_spell(""), 0, 4), 4, "spell crit never crits a physical card")
	me.gear = {"phys_crit": 1.0}
	assert_eq(caster.modify_power(_spell(""), 0, 4), 6, "physical crit")

func _hero_swing_damage(gear: Dictionary) -> int:
	var rt := _rt()
	rt.state.players[0].gear = gear
	var foe: HeroState = rt.state.players[1].hero
	var before: int = foe.health
	_run(rt, rt.swing_speed(0) + 0.05)
	return before - foe.health

func test_attack_power_and_phys_crit_on_hero_swings() -> void:
	var base: int = _hero_swing_damage({})
	assert_gt(base, 0)
	assert_eq(_hero_swing_damage({"attack_power": 1.0}), base * 2)
	assert_gt(_hero_swing_damage({"phys_crit": 1.0}), base, "always crits")
	assert_eq(_hero_swing_damage({"command": 1.0}), base, "command is Allies only")

func _draws_in(rt: RealtimeCombat, seconds: float) -> int:
	var me: PlayerState = rt.state.players[0]
	for i: int in 6:
		me.draw_deck.append(_spell("light"))
	var n: int = 0
	for ev: Dictionary in _run(rt, seconds):
		if str(ev.get("type", "")) == "draw" and int(ev.get("side", -1)) == 0:
			n += 1
	return n

func test_haste_draws_faster() -> void:
	var interval: float = CombatTuning.new().get_f("draw_interval")
	var plain := _rt()
	assert_eq(_draws_in(plain, interval * 0.6), 0)
	var hasted := _rt()
	hasted.state.players[0].gear = {"haste": 1.0}
	assert_eq(_draws_in(hasted, interval * 0.6), 1)

func test_leech_heals_the_attacker() -> void:
	var a := PlayerState.new(0, false)
	a.hero.max_health = 40
	a.hero.health = 20
	a.gear = {"leech": 0.25}
	var d := PlayerState.new(1, true)
	DamageResolver.deal(d, d.hero, 6, DamageSchools.PHYSICAL, null, a)
	assert_eq(a.hero.health, 21, "6 x 25 % = 1.5: 1 now")
	DamageResolver.deal(d, d.hero, 2, DamageSchools.PHYSICAL, null, a)
	assert_eq(a.hero.health, 22, "the carried half adds up")

func test_block_halves_hits_on_the_hero() -> void:
	var d := PlayerState.new(0, false)
	d.hero.max_health = 40
	d.hero.health = 40
	d.gear = {"block": 1.0}
	DamageResolver.deal(d, d.hero, 10, DamageSchools.PHYSICAL)
	assert_eq(d.hero.health, 35)
