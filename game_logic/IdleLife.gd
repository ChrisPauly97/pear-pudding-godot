extends RefCounted
## Idle life for world billboards (GID-132 / TID-511) — pure pose rules plus
## registration; `scenes/world/modules/CharacterPresence.gd` applies them each
## frame to every registered sprite near the player.
##
## Styles: BREATHE (townsfolk, merchants: slow squash-and-stretch), BOB (enemies:
## small bounce), FLOAT (spectres: slow hover, no squash). An enemy that is
## chasing bobs faster (META_FAST); `hop()` adds one quick jump (enemy notices
## you). Squash keeps the feet planted: the sprite's base position is its half
## height, so y = base × scale_y + bob.

const GROUP := "idle_life"
const META_BASE := "idle_base_pos"
const META_STYLE := "idle_style"
const META_PHASE := "idle_phase"
const META_FAST := "idle_fast"
const META_HOP := "idle_hop_start"

const STYLE_BREATHE := 0
const STYLE_BOB := 1
const STYLE_FLOAT := 2

## Per style: [cycle speed (rad/s), bob height, squash amount].
const STYLES: Array = [
	[2.2, 0.0, 0.035],
	[3.4, 0.05, 0.03],
	[1.6, 0.12, 0.0],
]
const FAST_SPEED_MULT: float = 2.6
const HOP_TIME: float = 0.35
const HOP_HEIGHT: float = 0.35
const HERO_STEP_LIFT: float = 0.06
const HERO_BREATH_LIFT: float = 0.03
## Beyond this distance from the player sprites are left alone (no cost).
const MAX_DISTANCE: float = 32.0


## Registers `sprite` (whose current position is its rest pose).
static func register(sprite: Node3D, style: int) -> void:
	sprite.add_to_group(GROUP)
	sprite.set_meta(META_BASE, sprite.position)
	sprite.set_meta(META_STYLE, style)
	sprite.set_meta(META_PHASE, float(sprite.get_instance_id() % 997) * 0.37)


## Wall-clock seconds used for hop timing (entities have no module clock).
static func now() -> float:
	return float(Time.get_ticks_msec()) * 0.001


## Starts one quick hop on a registered sprite.
static func hop(sprite: Node3D) -> void:
	sprite.set_meta(META_HOP, now())


## Returns Vector2(bob_y, squash) for a style at time `t` with `phase`.
## squash > 0 stretches tall/thin, < 0 squats wide/short.
static func pose(style: int, t: float, phase: float, fast: bool, hop_age: float) -> Vector2:
	var st: Array = STYLES[clampi(style, 0, STYLES.size() - 1)]
	var speed: float = float(st[0]) * (FAST_SPEED_MULT if fast else 1.0)
	var s: float = sin(t * speed + phase)
	var bob: float = float(st[1]) * (0.5 + 0.5 * s)
	var squash: float = float(st[2]) * s
	if hop_age >= 0.0 and hop_age < HOP_TIME:
		var k: float = hop_age / HOP_TIME
		bob += HOP_HEIGHT * 4.0 * k * (1.0 - k)
		squash += 0.08 * (1.0 - k)
	return Vector2(bob, squash)


## Hero bob (GID-134 / TID-526), world units up: a one-step lift on the walk
## cycle's passing frames (1 and 3) and, standing still, a brief breath every
## few seconds. Stepped rather than smooth so it stays on whole pixels.
static func hero_bob(walking: bool, frame: int, t: float) -> float:
	if walking:
		return HERO_STEP_LIFT if frame % 2 == 1 else 0.0
	return HERO_BREATH_LIFT if sin(t * 2.0) > 0.75 else 0.0


## Applies a pose to `sprite` given its rest position.
static func apply(sprite: Node3D, base: Vector3, p: Vector2) -> void:
	var sy: float = 1.0 + p.y
	var sx: float = 1.0 - p.y * 0.6
	sprite.scale = Vector3(sx, sy, 1.0)
	sprite.position = Vector3(base.x, base.y * sy + p.x, base.z)
