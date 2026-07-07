# TID-420: Real Pursuit Movement for Tracking Enemies

**Goal:** GID-113
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation task for the whole goal. Tracking enemies currently never move —
they're a static `CharacterBody3D` with a proximity `Area3D` sphere that
force-engages on contact. This task gives them actual chase movement and an
"awareness" state that TID-421/422/423 all key off of.

## Research Notes

- `scenes/world/entities/EnemyNPC.gd` current structure:
  - `_ready()` (lines 13-27): builds the `Sprite3D`, sets scale for boss/roaming
    boss, calls `_setup_proximity_area()` only `if _tracking`.
  - `_setup_proximity_area()` (lines 63-75): `Area3D` with `SphereShape3D` radius
    `IsoConst.AUTO_BATTLE_RANGE` (1.5), `body_entered` → `_on_body_entered`.
  - `_on_body_entered()` (lines 77-89): guards (`_alive`, `_tracking`,
    `engage_cooldown`, `SceneManager.can_proximity_engage()`,
    `SaveManager.is_enemy_defeated`), then calls `engage()` directly — no
    movement happens before this.
  - `_process(delta)` (lines 29-31): currently only ticks `engage_cooldown`.
  - `init_from_data(data)` (lines 33-41): sets `_tracking` from spawn data
    *before* `_ready()` runs (this ordering must be preserved — it's called by
    `TerrainMath.spawn_entity()` before `add_child()`).
- `IsoConst.gd` (autoloads/IsoConst.gd) constants already present:
  - `AUTO_BATTLE_RANGE: float = 1.5` (line 37) — keep as the actual
    contact/engage distance.
  - `INTERACT_RANGE: float = 1.5` (line 38) — unrelated (wanderer interact).
  - `TRACKING_SPEED: float = 2.5` (line 39) — declared, currently **unused**
    anywhere in the codebase (confirmed via repo-wide grep). This is the exact
    reserved constant to consume here.
- New "awareness radius" needed — larger than `AUTO_BATTLE_RANGE` so the enemy
  notices the player before contact and has room to visibly close the distance.
  Add a new `IsoConst` constant (e.g. `ENEMY_AWARENESS_RANGE: float = 6.0`,
  finalize value during Plan by playtesting feel) rather than hardcoding it in
  `EnemyNPC.gd`, matching the existing pattern of all tunable ranges living in
  `IsoConst`.
- Movement pattern to reuse: `game_logic/Pathfinder.gd` —
  `static func find_path(tile_lookup: Callable, from: Vector2i, to: Vector2i,
  max_radius: int) -> Array[Vector2i]` (pure A*, no scene dependency, already
  used by both named maps and the infinite world). Existing consumer for the
  path-following *pattern* (not pathfinding itself, since this is open terrain
  and a straight move-toward-player is likely sufficient — evaluate during Plan
  whether full A* is even necessary vs. simple direct-vector movement, since
  `TRACKING_SPEED`'s doc comment says "enemy movement speed" with no mention of
  pathfinding):
  - `scenes/world/WorldScene.gd:6386` calls `Pathfinder.find_path(...)` for
    tap-to-move; see `docs/agent/tap-to-move.md` for the full path-following
    loop pattern (`GID-047`/`GID-082`) if full pathfinding is needed for
    obstacle-heavy areas (e.g. avoiding walls in dungeons).
  - Simpler alternative: since `EnemyNPC` is a `CharacterBody3D`, a per-`_process`
    `velocity = (player.global_position - global_position).normalized() *
    TRACKING_SPEED` + `move_and_slide()` may be sufficient outdoors and much
    cheaper than A* re-pathing every frame. Decide based on whether tracking
    enemies are ever placed somewhere a straight line to the player could clip
    through a wall (check named-map ENEMY placements with `tracking: true` and
    dungeon generation in `docs/agent/named-maps-and-dungeons.md`).
- Needs a reference to the player node to chase. Check how other proximity/AI
  code already gets this — `_on_body_entered(body: Node3D)` already receives the
  player's `CharacterBody3D` on first contact; for awareness *before* contact,
  a second larger `Area3D` (or a distance check against `WorldScene`'s player
  reference, passed in via `init_from_data` or a new setter) is needed. Prefer
  a second `Area3D` sphere at `ENEMY_AWARENESS_RANGE` with its own
  `body_entered`/`body_exited` handlers, mirroring the existing
  `_setup_proximity_area()` pattern, so `EnemyNPC` doesn't need a direct
  `WorldScene`/`Player` reference (keeps the existing decoupling — see
  `docs/agent/signals-and-constants.md` GameBus architecture notes if a signal
  is more appropriate than a direct node reference).
- New state needed: something like `_alert_state: int` (IDLE / ALERTED /
  CHASING) that TID-421 (ambush bonus when *not* alerted), TID-422 (ambush
  penalty when caught *while* chasing), and TID-423 (give-up when chase exceeds
  a distance/time threshold) all read and mutate. Define this enum here so the
  later tasks don't redesign it.
- Co-op note: `docs/agent/multiplayer-coop.md` — co-op enemies are
  "authority-owned shared state" (engage-locks). Chase movement in co-op needs
  to either run host-authoritative (broadcast position) or be scoped out for
  co-op sessions initially — flag this explicitly in the Plan section; the
  goal's acceptance criteria allow either as long as it's a documented decision.
- Performance: only tracking-type enemies get the awareness `Area3D` today
  (`_ready()` line 26, `if _tracking`) — keep that gate so wanderers (majority
  of world enemies) pay zero extra `_process` cost.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
