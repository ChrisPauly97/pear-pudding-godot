## Pure-logic helpers for scaling a co-op shared boss by party size (GID-099 / TID-361).
##
## All methods are static and scene-free. Callers:
##   BattleScene._setup_coop_pve_battle() applies scale_boss_hp / scale_boss_tier.
##   Tests in test_coop_battle_state.gd verify monotonicity and bounds.
##
## Scaling formula for HP: base_hp × (0.6·n + 0.4), rounded to nearest int.
##   n=1 → 1.00×   n=2 → 1.60×   n=3 → 2.20×   n=4 → 2.80×
## This ensures the boss is still soloable (1× base) while being a genuine multi-player
## threat at party sizes 2–4.
extends RefCounted

## Minimum and maximum supported party sizes (n = number of allies).
const MIN_PARTY: int = 1
const MAX_PARTY: int = 4

## Scale boss hero HP by party size n.
## n is clamped to [MIN_PARTY, MAX_PARTY]. base_hp must be > 0.
static func scale_boss_hp(base_hp: int, n: int) -> int:
	var clamped_n: int = clampi(n, MIN_PARTY, MAX_PARTY)
	return roundi(float(base_hp) * (0.6 * float(clamped_n) + 0.4))

## Scale boss difficulty tier by party size n.
## Tier steps up by 1 for every 2 extra allies beyond 1 (n=3 → +1, n=4 → +1 more).
## Result is clamped to [base_tier, 4].
static func scale_boss_tier(base_tier: int, n: int) -> int:
	var clamped_n: int = clampi(n, MIN_PARTY, MAX_PARTY)
	var bonus: int = (clamped_n - 1) / 2  # 0 for n=1,2; 1 for n=3,4
	return mini(base_tier + bonus, 4)
