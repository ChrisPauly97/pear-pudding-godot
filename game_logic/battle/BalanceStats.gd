## Aggregates `BalanceFight.run` results for the balance simulator (GID-176 /
## TID-716): win rate with a Wilson 95 % interval, duration percentiles, HP
## left, damage split. Pure, so the numbers are unit-tested.
extends RefCounted

## CSV columns, one row per fight (`csv_row`).
const CSV_HEADER: String = ("label,seed,result,seconds,hero_hp,hero_hp_frac,dealt_cards,dealt_auto,"
	+ "interrupts,enemy_casts,procs,full_mana_s,actions_10s,plays")

## Wilson score interval for `wins` of `n` (z = 1.96) as [low, high].
static func wilson(wins: int, n: int) -> Array[float]:
	if n <= 0:
		return [0.0, 1.0]
	var z: float = 1.96
	var p: float = float(wins) / float(n)
	var denom: float = 1.0 + z * z / n
	var centre: float = (p + z * z / (2.0 * n)) / denom
	var half: float = z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]

## The q-quantile (0..1) of `values` (nearest rank); 0 for an empty list.
static func percentile(values: Array[float], q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var idx: int = clampi(ceili(q * sorted.size()) - 1, 0, sorted.size() - 1)
	return sorted[idx]

## Summary of a batch of fight results.
static func summarize(results: Array[Dictionary]) -> Dictionary:
	var n: int = results.size()
	var wins: int = 0
	var timeouts: int = 0
	var secs: Array[float] = []
	var hp: Array[float] = []
	var cards: int = 0
	var auto: int = 0
	var interrupts: int = 0
	var casts: int = 0
	var full_mana: float = 0.0
	var apt: Array[float] = []
	for r: Dictionary in results:
		match str(r.get("result", "")):
			"win":
				wins += 1
			"timeout":
				timeouts += 1
		secs.append(float(r.get("seconds", 0.0)))
		hp.append(float(r.get("hero_hp_frac", 0.0)))
		cards += int(r.get("dealt_cards", 0))
		auto += int(r.get("dealt_auto", 0))
		interrupts += int(r.get("interrupts", 0))
		casts += int(r.get("enemy_casts", 0))
		full_mana += float(r.get("full_mana_s", 0.0))
		apt.append(float(r.get("actions_10s", 0.0)))
	var ci: Array[float] = wilson(wins, n)
	return {
		"n": n, "wins": wins, "win_rate": float(wins) / float(maxi(1, n)), "ci_low": ci[0], "ci_high": ci[1],
		"timeouts": timeouts, "median_s": percentile(secs, 0.5), "p10_s": percentile(secs, 0.1),
		"p90_s": percentile(secs, 0.9), "median_hp": percentile(hp, 0.5),
		"card_share": float(cards) / float(maxi(1, cards + auto)),
		"interrupts": interrupts, "enemy_casts": casts, "full_mana_s": full_mana / float(maxi(1, n)),
		"actions_10s": percentile(apt, 0.5),
	}

## One fixed-width summary line (pairs with `table_header`).
static func table_row(label: String, s: Dictionary) -> String:
	return "%-28s %5d %6.1f%% [%5.1f-%5.1f] %4d %6.1f %6.1f %6.1f %5.0f%% %5.0f%% %5d/%-5d %6.1f %5.1f" % [
		label.left(28), int(s["n"]), 100.0 * float(s["win_rate"]), 100.0 * float(s["ci_low"]),
		100.0 * float(s["ci_high"]), int(s["timeouts"]), float(s["median_s"]), float(s["p10_s"]),
		float(s["p90_s"]), 100.0 * float(s["median_hp"]), 100.0 * float(s["card_share"]),
		int(s["interrupts"]), int(s["enemy_casts"]), float(s["full_mana_s"]), float(s.get("actions_10s", 0.0))]

static func table_header() -> String:
	return "%-28s %5s %7s %13s %4s %6s %6s %6s %6s %6s %11s %6s %5s" % [
		"case", "n", "win", "95% CI", "t/o", "med s", "p10", "p90", "HP", "cards", "kicks/casts", "fullM", "act10"]

## One CSV line for fight `r` (plays as id:n;id:n).
static func csv_row(label: String, s: int, r: Dictionary) -> String:
	var plays: PackedStringArray = []
	var p: Dictionary = r.get("plays", {})
	var keys: Array = p.keys()
	keys.sort()
	for k: Variant in keys:
		plays.append("%s:%d" % [str(k), int(p[k])])
	return "%s,%d,%s,%.2f,%d,%.3f,%d,%d,%d,%d,%d,%.2f,%.2f,%s" % [label, s, str(r.get("result", "")),
		float(r.get("seconds", 0.0)), int(r.get("hero_hp", 0)), float(r.get("hero_hp_frac", 0.0)),
		int(r.get("dealt_cards", 0)), int(r.get("dealt_auto", 0)), int(r.get("interrupts", 0)),
		int(r.get("enemy_casts", 0)), int(r.get("procs", 0)), float(r.get("full_mana_s", 0.0)),
		float(r.get("actions_10s", 0.0)), ";".join(plays)]
