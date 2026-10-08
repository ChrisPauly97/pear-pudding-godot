## Swimming in deep water (GID-172): the sea off the piers and the rivers off the bridges
## (`Rivers.deep_water`). Pure tuning and rules, no autoloads — the `Coastline` world module
## decides when the hero is swimming, `Player` moves and draws the swimmer.
##
## Stamina (TID-697) is a 0..1 fraction: it drains while swimming — faster the farther from shore
## and when swimming against a river's current — and refills on land. At 0 the hero is exhausted
## and washes up on the nearest shore at 1 HP (`WASHED_UP_FRAC`). Not saved: it refills on land.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _Coast = preload("res://game_logic/world/Coast.gd")
const _Rivers = preload("res://game_logic/world/Rivers.gd")

## Swimming speed as a share of walking speed (mounts and ley lines don't help in water).
const SPEED_MULT: float = 0.55
## World units the hero's sprite sinks while swimming: the legs and hips go under the
## surface (the terrain occludes the part of a billboard below it).
const SINK: float = 0.62
## Swim-animation frames that splash a stroke sound (the two arm reaches).
const STROKE_FRAMES: Array[int] = [0, 2]
## Tap-to-move: a deep-water tile costs this many steps, so paths swim only when it saves a long walk.
const PATH_COST: float = 4.0


## Stamina drain per second while swimming near shore, the share of it spent treading water,
## the extra per tile out from the shore / bank, and per unit of current swum straight against.
## Near shore a full meter lasts ~33 s; ~30 tiles out to sea there is no swimming back.
const BASE_DRAIN: float = 0.03
const TREAD_SHARE: float = 0.6
const DEPTH_DRAIN: float = 0.0015
const AGAINST_DRAIN: float = 0.04
## Stamina refilled per second on land.
const REGEN: float = 0.35
## Below this the meter flashes and the hero is warned to head for shore.
const LOW: float = 0.25
## A river's current carries the swimmer this many world units per second per unit of flow.
const CURRENT_PUSH: float = 1.2
## Hero HP (fraction) left after washing up exhausted: 1 HP on the 30-HP base (HeroVitality.hurt's floor).
const WASHED_UP_FRAC: float = 1.0 / 30.0


## Stamina after `delta` seconds. `depth` = tiles out from the shore (`depth_at`), `against` = how
## much current is swum straight into (0 = none or with it).
static func step(stamina: float, delta: float, swimming: bool, depth: float, moving: bool,
		against: float) -> float:
	if not swimming:
		return minf(1.0, stamina + REGEN * delta)
	return maxf(0.0, stamina - drain_rate(depth, moving, against) * delta)


static func drain_rate(depth: float, moving: bool, against: float) -> float:
	var base: float = BASE_DRAIN * (1.0 if moving else TREAD_SHARE)
	return base + DEPTH_DRAIN * maxf(0.0, depth) + AGAINST_DRAIN * maxf(0.0, against)


## How far (tiles) world point (wx, wz) lies out in the water: from the sea's shoreline or a river's bank.
static func depth_at(wx: float, wz: float) -> float:
	var ts: float = IsoConst.TILE_SIZE
	return maxf(_Coast.depth(wx / ts, wz / ts), _Rivers.depth(wx / ts, wz / ts))


## Current swum into: the component of `flow` (a river's current) against the swimmer's heading `dir`.
static func against(dir: Vector2, flow: Vector2) -> float:
	if dir.length_squared() < 0.0001:
		return 0.0
	return maxf(0.0, -dir.normalized().dot(flow))


## Deep water at world point (wx, wz) on the overworld — where the hero (and any co-op avatar) swims.
## Rivers and the sea are fixed geography, so every peer derives a remote avatar's swimming from its
## position alone (TID-698: no wire flag).
static func deep_at(wx: float, wz: float) -> bool:
	var t: Vector2i = IsoConst.world_to_tile(wx, wz)
	return _Rivers.deep_water(t.x, t.y)


## Whether frame `frame` of the swim animation is a stroke (plays the splash).
static func is_stroke(frame: int) -> bool:
	return STROKE_FRAMES.has(frame)
