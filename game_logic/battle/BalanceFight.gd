## One headless, seeded real-time fight driven by `BalanceBot` (GID-176). Runs
## the game's own rules: `BattleSetup.build` → per tick `PlayerCaster.tick`,
## `RealtimeCombat.advance`, enemy plays via `SpellEffectResolver.resolve_enemy_play`
## and fight traits via `BattleSetup.enemy_round` — the same calls
## `BattleRealtime._process` makes, minus presentation.
##
## `run(cfg, policy)` → {result: "win"|"loss"|"timeout", seconds, hero_hp,
## hero_hp_frac, plays: {template_id: n}, dealt_cards, dealt_auto, interrupts,
## enemy_casts, procs, full_mana_s}.
extends RefCounted

const BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const BalanceBot = preload("res://game_logic/battle/BalanceBot.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const FightStats = preload("res://game_logic/battle/FightStats.gd")
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
	var resolver := SpellEffectResolver.new()
	resolver.setup(state)
	var caster := PlayerCaster.new(rt)
	var bot := BalanceBot.new(policy)
	var stats: Dictionary = {"plays": {}, "dealt_cards": 0, "dealt_auto": 0, "interrupts": 0,
		"enemy_casts": 0, "procs": 0, "full_mana_s": 0.0}
	caster.notify = func(kind: String, data: Dictionary) -> void:
		match kind:
			"resolved":
				stats["dealt_cards"] = int(stats["dealt_cards"]) + int(data.get("dealt", 0))
			"interrupt":
				stats["interrupts"] = int(stats["interrupts"]) + 1
			"proc":
				stats["procs"] = int(stats["procs"]) + 1
	var me: PlayerState = state.players[RealtimeCombat.PLAYER]
	var rounds: int = 0
	var t: float = 0.0
	var max_seconds: float = float(cfg.get("max_seconds", MAX_SECONDS))
	while t < max_seconds and not state.is_game_over():
		var played: String = bot.act(caster, resolver)
		if played != "":
			var plays: Dictionary = stats["plays"]
			plays[played] = int(plays.get(played, 0)) + 1
		caster.tick(DT)
		var foe_hp: int = FightStats.enemy_health(rt)
		for ev: Dictionary in rt.advance(DT):
			match str(ev.get("type", "")):
				"enemy_cast":
					stats["enemy_casts"] = int(stats["enemy_casts"]) + 1
					resolver.resolve_enemy_play(ev["card"] as CardInstance,
							int(ev.get("side", RealtimeCombat.ENEMY)), RealtimeCombat.PLAYER)
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
	stats["hero_hp"] = me.hero.health
	stats["hero_hp_frac"] = float(me.hero.health) / float(maxi(1, me.hero.max_health))
	SpellEffectResolver.silent = false
	return stats
