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
## potions_used, potions_left, well_fed (GID-187 / TID-781: the buff after this fight's charge), joins
## (joiners that arrived), phase2 (1 when a boss swapped to phase 2), taken (HP the hero lost, before
## heals), hero_max_hp (GID-187 / TID-787: for the power / gear-share measurement)}.
##
## `chain(cfg, fights, policy, rest_seconds)` (TID-781): fights in a row, the hero's HP carried from
## one to the next (a loss ends the chain), out-of-combat regen between them (`HeroVitality.regen`
## over `rest_seconds`), and the potions and well-fed charges carried too. Returns how far it got.
##
## cfg `party: [hero cfg, ...]` (GID-187 / TID-786): co-op heroes on your side, each played by its own
## `BalanceBot`; the boss scales with the party (`BattleSetup.build`). The result is the party's.
##
## cfg `joiner: {enemy_type, enemy_level, at_seconds}` (GID-187 / TID-782) adds a second enemy
## to the fight once, at `at_seconds`, through `EncounterSetup.make_joiner` (the game's
## `BattleRealtime.join_enemy` setup). `is_boss` fights swap to phase 2 at half HP
## (`EncounterSetup.boss_phase2_due` / `enter_boss_phase2`, shared with `BattleScene`); `boss_phase2: false`
## turns the swap off (measurement only).
extends RefCounted

const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const EncounterSetup = preload("res://game_logic/battle/EncounterSetup.gd")
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
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

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
	resolver.tune = rt.tune
	var bot := BalanceBot.new(policy)
	bot.stock(built["potion_ids"], built["potion_counts"])
	# TID-786: co-op heroes, each with its own caster and bot (same policy, no potions).
	var party_casters: Array[PlayerCaster] = []
	var party_bots: Array[BalanceBot] = []
	for pc: Variant in cfg.get("party", []) as Array:
		var side: int = EncounterSetup.make_party_member(rt, pc as Dictionary)
		party_casters.append(PlayerCaster.new(rt, side))
		party_bots.append(BalanceBot.new(policy))
	if party_casters.is_empty():
		resolver.power_hook = caster.modify_power
	else:
		var by_side: Dictionary = {RealtimeCombat.PLAYER: caster}
		for pc: PlayerCaster in party_casters:
			by_side[pc.side] = pc
		resolver.power_hook = func(card: CardInstance, pid: int, power: int) -> int:
			var c: PlayerCaster = by_side.get(pid, null) as PlayerCaster
			return c.modify_power(card, pid, power) if c != null else power
	var stats: Dictionary = {"plays": {}, "dealt_cards": 0, "dealt_auto": 0, "interrupts": 0,
		"enemy_casts": 0, "procs": 0, "full_mana_s": 0.0, "crits_dealt": 0, "crits_taken": 0,
		"joins": 0, "phase2": 0}
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
	var joiner: Dictionary = cfg.get("joiner", {}) as Dictionary
	var joiner_at: float = float(joiner.get("at_seconds", INF))
	var joined: bool = joiner.is_empty()
	var is_boss: bool = bool(cfg.get("is_boss", false))
	var p2_deck: Array = EnemyRegistry.get_phase2_deck(enemy_type) if bool(cfg.get("boss_phase2", true)) else []
	var foe: PlayerState = state.players[RealtimeCombat.ENEMY]
	while t < max_seconds and not state.is_game_over():
		var hp_before: int = me.hero.health
		if not joined and t >= joiner_at:
			joined = true
			if EncounterSetup.make_joiner(rt, joiner) >= 0:
				stats["joins"] = int(stats["joins"]) + 1
		var played: String = bot.act(caster, resolver, DT) if rt.is_alive(RealtimeCombat.PLAYER) else ""
		if played != "":
			var plays: Dictionary = stats["plays"]
			plays[played] = int(plays.get(played, 0)) + 1
		caster.tick(DT)
		for k: int in party_casters.size():
			if rt.is_alive(party_casters[k].side):
				party_bots[k].act(party_casters[k], resolver, DT)
			party_casters[k].tick(DT)
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
					resolver.resolve_enemy_play(played_card, side, rt.enemy_target(side),  # TID-786: a party hero
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
		# As BattleScene._check_game_over after each batch of events: a boss swaps at half HP, once.
		if int(stats["phase2"]) == 0 and EncounterSetup.boss_phase2_due(foe, is_boss, p2_deck):
			EncounterSetup.enter_boss_phase2(foe, enemy_type, p2_deck)
			stats["phase2"] = 1
		if me.hero.mana >= me.hero.max_mana:
			stats["full_mana_s"] = float(stats["full_mana_s"]) + DT
		stats["taken"] = int(stats.get("taken", 0)) + maxi(0, hp_before - me.hero.health)
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
	stats["hero_max_hp"] = me.hero.max_health
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
