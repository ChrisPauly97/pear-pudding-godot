## Swimming in deep water (GID-172): the sea off the piers and the rivers off the bridges
## (`Rivers.deep_water`). Pure tuning and rules, no autoloads — the `Coastline` world module
## decides when the hero is swimming, `Player` moves and draws the swimmer.
extends RefCounted

## Swimming speed as a share of walking speed (mounts and ley lines don't help in water).
const SPEED_MULT: float = 0.55
## World units the hero's sprite sinks while swimming: the legs and hips go under the
## surface (the terrain occludes the part of a billboard below it).
const SINK: float = 0.62
## Swim-animation frames that splash a stroke sound (the two arm reaches).
const STROKE_FRAMES: Array[int] = [0, 2]
## Tap-to-move: a deep-water tile costs this many steps, so paths swim only when it saves a long walk.
const PATH_COST: float = 4.0


## Whether frame `frame` of the swim animation is a stroke (plays the splash).
static func is_stroke(frame: int) -> bool:
	return STROKE_FRAMES.has(frame)
