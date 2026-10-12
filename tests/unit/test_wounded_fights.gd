## GID-187 / TID-781: wounded starts, quick-slot potions, well-fed food and fight chains in the
## balance sim. Covers the shared helpers the game also calls (apply_start_hp, apply_well_fed,
## PotionEffects), the bot's potion knob and cooldown, and the chain carry-over.
extends "res://tests/framework/test_case.gd"

const BalanceBot = preload("res://game_logic/battle/BalanceBot.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const FightStart = preload("res://game_logic/battle/FightStart.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const WellFed = preload("res://game_logic/professions/WellFed.gd")

const BASE_CFG: Dictionary = {"seed": 3, "player_level": 4, "enemy_type": "undead_basic", "enemy_level": 4,
	"learned": []}

func _player(f: Dictionary) -> PlayerState:
	var state: GameState = f["state"]
	return state.players[RealtimeCombat.PLAYER]

func _hero_max(cfg: Dictionary) -> int:
	return _player(BattleSetup.build(cfg)).hero.max_health

func test_start_hp_frac_wounds_the_hero_after_max_hp() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["start_hp_frac"] = 0.6
	var me: PlayerState = _player(BattleSetup.build(cfg))
	var max_hp: int = me.hero.max_health
	assert_eq(me.hero.health, ceili(float(max_hp) * 0.6), "60 % of max HP")

func test_default_start_is_full_hp() -> void:
	var me: PlayerState = _player(BattleSetup.build(BASE_CFG))
	assert_eq(me.hero.health, me.hero.max_health, "no start_hp_frac: full HP as before")

func test_apply_start_hp_never_raises_health() -> void:
	var p := PlayerState.new(0)
	p.hero.max_health = 30
	p.hero.health = 5
	FightStart.apply_start_hp(p, 1.0)
	assert_eq(p.hero.health, 5, "a wounded hero stays wounded")
	FightStart.apply_start_hp(p, 0.0)
	assert_eq(p.hero.health, 1, "at least 1 HP")

func test_well_fed_raises_max_and_takes_one_charge() -> void:
	var base: int = _hero_max(BASE_CFG)
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["well_fed"] = "roast_fowl"  # +4 max HP for 3 fights
	var f: Dictionary = BattleSetup.build(cfg)
	var me: PlayerState = _player(f)
	assert_eq(me.hero.max_health, base + 4, "+4 max HP")
	assert_eq(me.hero.health, base + 4, "the bonus is also current HP, as in the game")
	var left: Dictionary = f["well_fed"]
	assert_eq(int(left["fights"]), 2, "one charge spent")

func test_no_food_is_no_change() -> void:
	var f: Dictionary = BattleSetup.build(BASE_CFG)
	var left: Dictionary = f["well_fed"]
	assert_true(left.is_empty(), "no buff")
	assert_true(FightStart.apply_well_fed(PlayerState.new(0), {}).is_empty(), "inactive buff comes back empty")

func test_potion_ids_follow_quick_slots_and_skip_legendary() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["potions"] = {"healing_draught": 2, "pear_pudding": 1}
	cfg["quick_slots"] = ["pear_pudding", "healing_draught"]
	var f: Dictionary = BattleSetup.build(cfg)
	var ids: Array[String] = f["potion_ids"]
	assert_eq(ids, ["healing_draught"], "legendary never leaves the stock")
	var counts: Dictionary = f["potion_counts"]
	assert_eq(int(counts["healing_draught"]), 2)

func test_bot_drinks_when_low_and_respects_the_cooldown() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["potions"] = {"healing_draught": 3}
	var f: Dictionary = BattleSetup.build(cfg)
	var rt: RealtimeCombat = f["rt"]
	var state: GameState = f["state"]
	var me: PlayerState = state.players[RealtimeCombat.PLAYER]
	var caster := PlayerCaster.new(rt)
	var resolver := SpellEffectResolver.new()
	resolver.setup(state)
	var bot := BalanceBot.new({"potion_below": 0.5})
	var ids: Array[String] = f["potion_ids"]
	bot.stock(ids, f["potion_counts"])
	me.hero.health = 3
	bot.act(caster, resolver, 0.05)
	assert_eq(bot.potions_used, 1, "drank at low HP")
	var left: Dictionary = bot.potions_left()
	assert_eq(int(left["healing_draught"]), 2)
	assert_eq(me.hero.health, mini(3 + 8, me.hero.max_health), "the game's healing draught: +8 HP")
	me.hero.health = 3
	bot.act(caster, resolver, 0.05)
	assert_eq(bot.potions_used, 1, "cooldown holds the second drink")
	for _i: int in 420:  # 21 s of fight clock: past potion_cooldown (20 s)
		bot.act(caster, resolver, 0.05)
	me.hero.health = 3
	bot.act(caster, resolver, 0.05)
	assert_eq(bot.potions_used, 2, "ready again after the cooldown")

func test_bot_never_drinks_at_full_hp_or_by_default() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["potions"] = {"healing_draught": 3}
	var f: Dictionary = BattleSetup.build(cfg)
	var rt: RealtimeCombat = f["rt"]
	var state: GameState = f["state"]
	var caster := PlayerCaster.new(rt)
	var resolver := SpellEffectResolver.new()
	resolver.setup(state)
	var ids: Array[String] = f["potion_ids"]
	var counts: Dictionary = f["potion_counts"]
	var bot := BalanceBot.new({"potion_below": 0.5})
	bot.stock(ids, counts)
	bot.act(caster, resolver, 0.05)
	assert_eq(bot.potions_used, 0, "full HP: no drink")
	var off := BalanceBot.new()
	off.stock(ids, counts)
	_player(f).hero.health = 3
	off.act(caster, resolver, 0.05)
	assert_eq(off.potions_used, 0, "potion_below defaults to off")
	assert_eq(float(BalanceBot.DEFAULT_POLICY["potion_below"]), 0.0)

func test_potions_in_stock_leave_a_default_fight_unchanged() -> void:
	var plain: Dictionary = BalanceFight.run(BASE_CFG)
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["potions"] = {"healing_draught": 3, "stoneskin_tonic": 2}
	var kit: Dictionary = BalanceFight.run(cfg)
	assert_eq(str(kit["result"]), str(plain["result"]))
	assert_almost_eq(float(kit["seconds"]), float(plain["seconds"]), 0.0001)
	assert_eq(int(kit["potions_used"]), 0, "the default bot never drinks")

func test_chain_carries_hp_and_stops_at_a_loss() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["player_level"] = 6
	cfg["enemy_level"] = 1
	cfg["start_hp_frac"] = 0.5
	var r: Dictionary = BalanceFight.chain(cfg, 3, {}, 0.0)
	var results: Array = r["results"]
	var cleared: int = int(r["cleared"])
	var expect_n: int = 3 if bool(r["won_all"]) else mini(3, cleared + 1)
	assert_eq(results.size(), expect_n, "a loss ends the chain")
	assert_gte(cleared, 2, "an easy chain wins twice")
	var first: Dictionary = results[0]
	var second: Dictionary = results[1]
	assert_almost_eq(float(second["start_hp_frac"]), float(first["hero_hp_frac"]), 0.05,
		"no rest: fight 2 starts where fight 1 ended")

func test_chain_rest_refills_hp_between_fights() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["player_level"] = 6
	cfg["enemy_level"] = 1
	cfg["start_hp_frac"] = 0.5
	var r: Dictionary = BalanceFight.chain(cfg, 2, {}, 100000.0)
	var results: Array = r["results"]
	assert_gte(results.size(), 2, "an easy chain wins once")
	var second: Dictionary = results[1]
	assert_almost_eq(float(second["start_hp_frac"]), 1.0, 0.0001, "a long rest refills to full")

func test_chain_carries_the_well_fed_charge() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["player_level"] = 6
	cfg["enemy_level"] = 1
	cfg["well_fed"] = "roast_fowl"
	var r: Dictionary = BalanceFight.chain(cfg, 3, {}, 0.0)
	var results: Array = r["results"]
	var first: Dictionary = results[0]
	assert_eq(int((first["well_fed"] as Dictionary)["fights"]), 2, "fight 1 spends a charge")
	assert_gte(results.size(), 2, "an easy chain wins once")
	var buff: Dictionary = first["well_fed"]
	assert_true(WellFed.active(buff), "still well fed for fight 2")

func test_chain_is_deterministic() -> void:
	var cfg: Dictionary = BASE_CFG.duplicate()
	cfg["start_hp_frac"] = 0.6
	var a: Dictionary = BalanceFight.chain(cfg, 3, {}, 30.0)
	var b: Dictionary = BalanceFight.chain(cfg, 3, {}, 30.0)
	assert_eq(str(a["cleared"]), str(b["cleared"]))
