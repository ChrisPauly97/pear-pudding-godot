## The XP curve (GID-177 / TID-721): how much XP each level takes. Built from
## the pacing targets, not picked by hand:
##
##   minutes at level L   = MINUTES_L1 + MINUTES_STEP × (L − 1)   (10, 15, 20 … 50 at L9)
##   XP / minute at L     = XP_PER_MIN_L1 × (1 + 0.1 × (L − 1))  (kill XP grows 10 %/level,
##                                                                  ZoneLevels.scaled_xp)
##   XP from L to L + 1   = minutes × XP / minute, rounded to 10
##
## XP_PER_MIN_L1 is the modelled XP a level-1 player earns per minute (about a
## kill a minute plus their share of quest XP). TID-723 re-tunes quest and kill
## XP so real play lands on it. Pure static, no autoloads.
extends RefCounted

const MINUTES_L1: float = 10.0
const MINUTES_STEP: float = 5.0
const XP_PER_MIN_L1: float = 30.0
const MAX_LEVEL: int = 60

## Planned minutes of play to go from `level` to the next.
static func minutes_for(level: int) -> float:
	return MINUTES_L1 + MINUTES_STEP * float(maxi(0, level - 1))

## Modelled XP per minute at `level`.
static func xp_per_minute(level: int) -> float:
	return XP_PER_MIN_L1 * (1.0 + 0.1 * float(maxi(0, level - 1)))

## XP needed to go from `level` to `level + 1`.
static func step(level: int) -> int:
	return roundi(minutes_for(level) * xp_per_minute(level) / 10.0) * 10

## Total XP at which `level` is reached (0 for level 1).
static func xp_to_reach(level: int) -> int:
	var total: int = 0
	for l: int in range(1, mini(level, MAX_LEVEL)):
		total += step(l)
	return total

## The level a total of `xp` gives (1 … MAX_LEVEL).
static func level_for(xp: int) -> int:
	var lvl: int = 1
	var need: int = step(1)
	while lvl < MAX_LEVEL and xp >= need:
		lvl += 1
		need += step(lvl)
	return lvl

## The pre-GID-177 curve: total XP to reach `level` was level² × 50.
static func legacy_xp_to_reach(level: int) -> int:
	return 0 if level <= 1 else level * level * 50

static func legacy_level_for(xp: int) -> int:
	var lvl: int = 1
	while lvl < MAX_LEVEL and xp >= legacy_xp_to_reach(lvl + 1):
		lvl += 1
	return lvl

## Converts a legacy XP total: same level, same fraction of the way to the next.
static func migrate_xp(old_xp: int) -> int:
	var lvl: int = legacy_level_for(old_xp)
	var lo: int = legacy_xp_to_reach(lvl)
	var span: int = maxi(1, legacy_xp_to_reach(lvl + 1) - lo)
	var frac: float = clampf(float(old_xp - lo) / float(span), 0.0, 0.999)
	return xp_to_reach(lvl) + floori(frac * float(step(lvl)))
