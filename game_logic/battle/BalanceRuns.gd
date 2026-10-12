## Runs (GID-187 / TID-783): multi-fight sims with the hero's HP carried between fights, the way the game
## carries it (`BattleModifiers._apply_persistent_hp` / `record_persistent_hp`: a fraction, plus the breather
## `RiftDefs.after_floor` / `SiegeDefs.after_wave`).
##
## - **Rift ladder** (`rift_run`): one tier of a rift, `RiftDefs.FLOORS_PER_TIER` floors, each floor's enemy and
##   level from `RiftDefs` (the guardian floor fights as a boss). After each non-guardian floor the run drafts
##   the game's offer (`SpireDraft.generate_picks` seeded run seed + floor, the third pick a boon, as
##   `SpireDraftScene`); the bot always takes the boon (`RiftDefs.apply_boons`, Vigor's heal on the carried HP).
## - **Siege gauntlet** (`siege_run`): the three waves `martarquas_raider_1..3` at `SiegeDefs.stage_level`.
##
## The player is the typical profile (`BalanceProfiles`) of a level, its magic type rotating with the run.
## `BalanceCoverage` section `runs`. Pure except the fights.
extends RefCounted

const BalanceProfiles = preload("res://game_logic/battle/BalanceProfiles.gd")
const BalanceFight = preload("res://game_logic/battle/BalanceFight.gd")
const RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
const MagicTypes = preload("res://game_logic/MagicTypes.gd")

## Player levels the rift ladder is measured at; each climbs from its own tier (`own_tier`) up.
const RIFT_LEVELS: Array[int] = [16, 26, 40, 54]
## Tiers above the player's own measured per level (0 = own tier).
const RIFT_TIERS_ABOVE: Array[int] = [0, 1, 2, 3]
const RIFT_RUNS: int = 20
## Siege: player levels and runs per level.
const SIEGE_LEVELS: Array[int] = [12, 20, 32, 48]
const SIEGE_RUNS: int = 24
## Gates (measured first; `docs/agent/balance-sim.md` → Runs).
## The player's own tier is cleared at least this often (pooled over the rifts).
const RIFT_OWN_MIN: float = 0.5
## Clear rate never rises with the tier by more than this (one 20-run cell moves in 5 pp steps).
const RIFT_SLACK: float = 0.1
## Between two adjacent tiers the clear rate falls by at most this (smooth, no cliff). Measured max 60 pp
## (level 16, +0.5 → +1 level: the low end, where the gear curve is thinnest); before half-level tiers, 95.
const RIFT_STEP_MAX: float = 0.65
## A level-appropriate siege (all three waves, HP carried) is cleared at least this often.
const SIEGE_MIN: float = 0.5

## The tier whose first floor fights at about `level` (rifts open at level 15).
static func own_tier(level: int) -> int:
	return clampi((level - RiftDefs.BASE_LEVEL) * RiftDefs.TIERS_PER_LEVEL + 1, 1, RiftDefs.MAX_TIER)

## One rift run: {cleared: floors won, won: all floors}. `run_seed` seeds the fights (seed + floor) and the
## draft (as the game's spire_run.seed + floor).
static func rift_run(rift_id: String, tier: int, level: int, magic_type: String, run_seed: int,
		tune: Dictionary = {}) -> Dictionary:
	var frac: float = 1.0
	var boons: Array = []
	var cleared: int = 0
	for floor: int in range(1, RiftDefs.FLOORS_PER_TIER + 1):
		var c: Dictionary = BalanceProfiles.cfg(level, magic_type, "typical")
		c.merge({"seed": run_seed * 10 + floor, "enemy_type": RiftDefs.enemy_type(rift_id, floor),
			"enemy_level": RiftDefs.enemy_level(tier, floor), "is_boss": RiftDefs.is_guardian_floor(floor),
			"enemy_hp_mult": RiftDefs.hp_mult(tier),
			"start_hp_frac": frac, "boons": boons.duplicate()}, true)
		if not tune.is_empty():
			c["tuning"] = tune
		var r: Dictionary = BalanceFight.run(c)
		if str(r["result"]) != "win":
			break
		cleared += 1
		frac = RiftDefs.after_floor(float(r["hero_hp_frac"]))
		if not RiftDefs.is_guardian_floor(floor):
			var boon: String = draft_boon(run_seed, floor)
			boons.append(boon)
			if str((RiftDefs.BOONS[boon] as Dictionary)["effect"]) == "max_hp_pct":
				frac = RiftDefs.vigor_heal(frac, int((RiftDefs.BOONS[boon] as Dictionary)["value"]))
	return {"cleared": cleared, "won": cleared == RiftDefs.FLOORS_PER_TIER}

## The boon the draft offers after `floor` of a run seeded `run_seed` (`SpireDraftScene`: an rng seeded
## run seed + floor, the boon drawn after the card picks; here the boon draw alone, same distribution).
static func draft_boon(run_seed: int, floor: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + floor
	var ids: Array = RiftDefs.BOONS.keys()
	return str(ids[rng.randi_range(0, ids.size() - 1)])

## One siege: {cleared: waves won, won}.
static func siege_run(level: int, magic_type: String, run_seed: int, tune: Dictionary = {}) -> Dictionary:
	var frac: float = 1.0
	var cleared: int = 0
	for stage: int in 3:
		var c: Dictionary = BalanceProfiles.cfg(level, magic_type, "typical")
		c.merge({"seed": run_seed * 10 + stage, "enemy_type": "martarquas_raider_%d" % (stage + 1),
			"enemy_level": SiegeDefs.stage_level(level, stage), "start_hp_frac": frac}, true)
		if not tune.is_empty():
			c["tuning"] = tune
		var r: Dictionary = BalanceFight.run(c)
		if str(r["result"]) != "win":
			break
		cleared += 1
		frac = SiegeDefs.after_wave(float(r["hero_hp_frac"]))
	return {"cleared": cleared, "won": cleared == 3}

## {"rift@<level>+<above>": {kind: "rift", level, above, rate}, "siege@<level>": {kind: "siege", level, rate}}.
static func measure(tune: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var types: Array[String] = MagicTypes.all_types()
	var rifts: Array[Dictionary] = RiftDefs.all()
	for lv: int in RIFT_LEVELS:
		for above: int in RIFT_TIERS_ABOVE:
			var won: int = 0
			for i: int in RIFT_RUNS:
				var rift: String = str(rifts[i % rifts.size()]["id"])
				if bool(rift_run(rift, own_tier(lv) + above, lv, types[i % types.size()], 1 + i, tune)["won"]):
					won += 1
			out["rift@%d+%d" % [lv, above]] = {"kind": "rift", "level": lv, "above": above,
				"rate": float(won) / float(RIFT_RUNS)}
	for lv: int in SIEGE_LEVELS:
		var won: int = 0
		for i: int in SIEGE_RUNS:
			if bool(siege_run(lv, types[i % types.size()], 1 + i, tune)["won"]):
				won += 1
		out["siege@%d" % lv] = {"kind": "siege", "level": lv, "rate": float(won) / float(SIEGE_RUNS)}
	return out

## Failures of a `runs` measurement (empty = pass).
static func check(measured: Dictionary) -> Array[String]:
	var fails: Array[String] = []
	for k: String in measured:
		var m: Dictionary = measured[k]
		var rate: float = float(m["rate"])
		if str(m["kind"]) == "siege":
			if rate < SIEGE_MIN - 0.001:
				fails.append("runs %s: a level-appropriate siege cleared %.0f%% < %.0f%%" % [k, 100.0 * rate,
					100.0 * SIEGE_MIN])
			continue
		var above: int = int(m["above"])
		if above == 0 and rate < RIFT_OWN_MIN - 0.001:
			fails.append("runs %s: own tier cleared %.0f%% < %.0f%%" % [k, 100.0 * rate, 100.0 * RIFT_OWN_MIN])
		var next: String = "rift@%d+%d" % [int(m["level"]), above + 1]
		if measured.has(next):
			var nr: float = float((measured[next] as Dictionary)["rate"])
			if nr > rate + RIFT_SLACK + 0.001:
				fails.append("runs %s: the next tier clears more (%.0f%% vs %.0f%%)" % [k, 100.0 * nr, 100.0 * rate])
			if rate - nr > RIFT_STEP_MAX + 0.001:
				fails.append("runs %s: clear rate falls %.0f pp to the next tier (a cliff)" % [k, 100.0 * (rate - nr)])
	return fails
