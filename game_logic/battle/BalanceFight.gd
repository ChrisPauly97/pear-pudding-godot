## One headless, seeded real-time fight driven by `BalanceBot` (GID-176). Runs
## the game's own rules: `BattleSetup.build` → per tick `PlayerCaster.tick`,
## `RealtimeCombat.advance`, enemy plays via `SpellEffectResolver.resolve_enemy_play`
## and fight traits via `BattleSetup.enemy_round` — the same calls
## `BattleRealtime._process` makes, minus presentation.
##
## `run(cfg, policy)` (policy: `BalanceBot` knobs, presets via `BalanceBot.preset`) →
## {result: "win"|"loss"|"timeout", seconds, hero_hp,
## hero_hp_frac, plays: {template_id: n}, actions (cards played), actions_10s
## (cards played per 10 s, GID-178), dealt_cards, dealt_auto, interrupts,
## enemy_casts, procs, full_mana_s, crits_dealt, crits_taken (GID-178 / TID-728),
## potions_used, potions_left, well_fed (GID-187 / TID-781: the buff after this fight's charge)}.
##
## `chain(cfg, fights, policy, rest_seconds)` (TID-781): fights in a row, the hero's HP carried from
## one to the next (a loss ends the chain), out-of-combat regen between them (`HeroVitality.regen`
## over `rest_seconds`), and the potions and well-fed charges carried too. Returns how far it got.
extends RefCounted

const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const HeroVitality = preload("res://game_logic/HeroVitality.gd")
const BalanceBot = preload("res://game_logic/battle/BalanceBot.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const FightStats = preload("res://game_logic/battle/FightStats.gd")
const FightConditions = preload("res://game_logic/battle/FightConditions.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")

const DT: float = 0.05
const MAX_SECONDS: float = 300.0

static func run(cfg: Dictionary, policy: Dictionary = {}) -> Dictionary:
	SpellEffectResolver.silent = true
	var built: Dictionary = BattleSetup.build(cfg)
	var state: GameState = built["state"]
	var rt: RealtimeCombat = built["rt"]
	var tier: int = int(built["tier"])
	var enemy_type: String = str(cfg.get("enemy_type", "undead_basic"))
	var weather: String = str(cfg.get("weather", ""))
	var resolver := SpellEffectResolver.new()
	resolver.setup(state)
	var caster := PlayerCaster.new(rt)
	resolver.power_hook = caster.modify_power
	resolver.tune = rt.tune
	var bot := BalanceBot.new(policy)
	bot.stock(built["potion_ids"], built["potion_counts"])
	var stats: Dictionary = {"plays": {}, "dealt_cards": 0, "dealt_auto": 0, "interrupts": 0,
		"enemy_casts": 0, "procs": 0, "full_mana_s": 0.0, "crits_dealt": 0, "crits_taken": 0}
	caster.notify = func(kind: String, data: Dictionary) -> void:
		match kind:
			"resolved":
				stats["dealt_cards"] = int(stats["dealt_cards"]) + int(data.get("dealt", 0))
			"interrupt":
				stats["interrupts"] = int(stats["interrupts"]) + 1
			"proc":
				stats["procs"] = int(stats["procs"]) + 1
			"crit":
				stats["crits_dealt"] = int(stats["crits_dealt"]) + 1
	var me: PlayerState = state.players[RealtimeCombat.PLAYER]
	stats["start_hp_frac"] = float(me.hero.health) / float(maxi(1, me.hero.max_health))
	var rounds: int = 0
	var t: float = 0.0
	var max_seconds: float = float(cfg.get("max_seconds", MAX_SECONDS))
	while t < max_seconds and not state.is_game_over():
		var played: String = bot.act(caster, resolver, DT)
		if played != "":
			var plays: Dictionary = stats["plays"]
			plays[played] = int(plays.get(played, 0)) + 1
		caster.tick(DT)
		var foe_hp: int = FightStats.enemy_health(rt)
		for ev: Dictionary in rt.advance(DT):
			match str(ev.get("type", "")):
				"swing":
					if bool(ev.get("crit", false)):
						var k: String = "crits_dealt" if int(ev.get("side", 0)) == RealtimeCombat.PLAYER else "crits_taken"
						stats[k] = int(stats[k]) + 1
				"enemy_cast":
					stats["enemy_casts"] = int(stats["enemy_casts"]) + 1
					var side: int = int(ev.get("side", RealtimeCombat.ENEMY))
					var played_card: CardInstance = ev["card"] as CardInstance
					resolver.resolve_enemy_play(played_card, side, RealtimeCombat.PLAYER,
							BattleSetup.enemy_spell_scale(rt, side))
					# As BattleRealtime._after_enemy_play: a summoned minion takes the weather.
					if played_card.card_class != "spell":
						FightConditions.apply_summon_weather(played_card, weather, state.turn_number)
				"round":
					if int(ev.get("side", -1)) == RealtimeCombat.ENEMY:
						rounds += 1
						BattleSetup.enemy_round(state, enemy_type, tier, rounds)
				"proc":
					stats["procs"] = int(stats["procs"]) + 1
		stats["dealt_auto"] = int(stats["dealt_auto"]) + maxi(0, foe_hp - FightStats.enemy_health(rt))
		if me.hero.mana >= me.hero.max_mana:
			stats["full_mana_s"] = float(stats["full_mana_s"]) + DT
		t += DT
	var result: String = "timeout"
	if state.is_game_over():
		result = "win" if state.winner() == RealtimeCombat.PLAYER else "loss"
	stats["result"] = result
	stats["seconds"] = t
	var actions: int = 0
	for n: Variant in (stats["plays"] as Dictionary).values():
		actions += int(n)
	stats["actions"] = actions
	stats["actions_10s"] = 10.0 * float(actions) / maxf(DT, t)
	stats["hero_hp"] = me.hero.health
	stats["hero_hp_frac"] = float(me.hero.health) / float(maxi(1, me.hero.max_health))
	stats["potions_used"] = bot.potions_used
	stats["potions_left"] = bot.potions_left()
	stats["well_fed"] = built["well_fed"]
	SpellEffectResolver.silent = false
	return stats

## TID-781: up to `fights` fights in a row (fight i uses seed `cfg.seed + i`). Each fight starts at
## the HP the last one left, after `rest_seconds` of out-of-combat regen (0 = none); potions and the
## well-fed charge carry over. A loss ends the chain. Returns {cleared: wins in a row, fights,
## won_all, results: [run stats...]}.
static func chain(cfg: Dictionary, fights: int, policy: Dictionary = {}, rest_seconds: float = 0.0) -> Dictionary:
	var c: Dictionary = cfg.duplicate()
	var base_seed: int = int(cfg.get("seed", 1))
	var frac: float = float(cfg.get("start_hp_frac", 1.0))
	var potions: Dictionary = (cfg.get("potions", {}) as Dictionary).duplicate()
	var buff: Variant = cfg.get("well_fed", "")
	var level: int = int(cfg.get("player_level", 1))
	var cleared: int = 0
	var results: Array[Dictionary] = []
	for i: int in fights:
		c["seed"] = base_seed + i
		c["start_hp_frac"] = frac
		c["potions"] = potions
		c["well_fed"] = buff
		var r: Dictionary = run(c, policy)
		results.append(r)
		if str(r["result"]) != "win":
			break
		cleared += 1
		frac = float(r["hero_hp_frac"])
		potions = r["potions_left"] as Dictionary
		buff = r["well_fed"]
		if i < fights - 1:
			frac = HeroVitality.regen(frac, rest_seconds, 0.0, HeroVitality.regen_seconds(level))
	return {"cleared": cleared, "fights": fights, "won_all": cleared == fights, "results": results}
