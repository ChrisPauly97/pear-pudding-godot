# TID-420: Real Pursuit Movement for Tracking Enemies

**Goal:** GID-113
**Type:** agent
**Status:** done
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

**Movement model:** direct-vector chase, no A*. `EnemyNPC` extends
`WorldEntityBase` (plain `Node3D`, no physics body) — there's nothing to
`move_and_slide()`. Each `_process(delta)` while `CHASING`, move `position`
toward the player's `global_position` (Y zeroed) by
`min(TRACKING_SPEED * delta, remaining_distance)`. Confirmed via
`EnemyRegistry` that tracking enemies do include dungeon/depth placements, so
straight-line chase can clip through dungeon walls — accepted as a known
limitation for this foundation task (logged as BID-058, not fixed here; full
pathfinding chase is a much larger change than "make them move at all").

**Player reference:** no per-call-site wiring. `WorldScene._create_player_node()`
already does `p.add_to_group("player")`, so `EnemyNPC` lazily resolves
`get_tree().get_first_node_in_group("player")` itself, cached and
revalidated with `is_instance_valid()`. This avoids touching the 8 existing
`EnemyNPC` spawn call sites (WorldScene ×3, ChunkRenderer/TerrainMath,
CoopActivities ×3, WorldEvents) and matches the project's preference for
decoupling over direct references.

**Awareness state:** new `enum AlertState { IDLE, ALERTED, CHASING }` on
`EnemyNPC`, gated behind the existing `_tracking` flag (same performance gate
as the current proximity `Area3D` — wanderers pay zero extra cost). A second
`Area3D` (radius = new `IsoConst.ENEMY_AWARENESS_RANGE = 6.0`, mirroring
`_setup_proximity_area()`'s pattern) fires `IDLE -> ALERTED` on player entry.
`ALERTED` holds for `_ALERT_REACTION_TIME = 0.4s` (matches the existing
`engage()` beat timing) before flipping to `CHASING`, giving TID-422's future
"fair warning" indicator a state to hook. No give-up / exit handling is added
here — TID-423 owns breaking pursuit, so state only escalates in this task.
The existing `AUTO_BATTLE_RANGE` proximity `Area3D` is untouched and still
fires `engage()` normally; since it's a child of the now-moving `EnemyNPC`,
Godot's physics re-evaluates the overlap every physics tick regardless of
which side moved, so a completed chase naturally ends in `engage()` with no
new code.

**Gating:** movement and awareness both additionally require
`SceneManager.can_proximity_engage()` (state == WORLD, no post-battle
immunity window) — reuses the exact guard `_on_body_entered()` already uses,
so enemies don't advance/chase while the player is in battle/menus.

**Co-op scoping (explicit decision):** chase movement and awareness are
skipped entirely when `NetworkManager.is_active()` (co-op session active) —
matches the "scoped out for co-op sessions initially" option the task notes
call out. Co-op enemies remain static this task; host-authoritative chase
sync is future work if wanted. Documented in `docs/agent/enemies-and-npcs.md`.

**Constants:** add `IsoConst.ENEMY_AWARENESS_RANGE: float = 6.0` next to
`AUTO_BATTLE_RANGE`/`TRACKING_SPEED`; update `TRACKING_SPEED`'s comment since
it's no longer "reserved for future movement AI" — it's consumed now.

**Backlog note discovered during research:** `docs/agent/enemies-and-npcs.md`,
`docs/agent/battle-system.md`, `docs/agent/ui-and-scene-management.md`, and
this task's own research notes all describe an `EnemyNPC.engage_cooldown`
field ticked in `_process()` (GID-069/TID-250-251) that does not exist
anywhere in the current `EnemyNPC.gd` — no `_process`, no `engage_cooldown`
field. It was apparently dropped by a later refactor (likely the TID-427
`engage()` rewrite) without updating the docs or re-adding the mechanic.
Logging as BID-058 rather than fixing here (out of scope — this task adds the
first real `_process()` to the file, for chase movement, and restoring a
possibly-intentionally-removed cooldown mechanic is a separate concern).

## Changes Made

- `autoloads/IsoConst.gd`: added `ENEMY_AWARENESS_RANGE: float = 6.0`; updated
  `TRACKING_SPEED`'s comment (no longer "reserved for future movement AI" —
  it's consumed now).
- `scenes/world/entities/EnemyNPC.gd`:
  - New `enum AlertState { IDLE, ALERTED, CHASING }`, `_alert_state`,
    `_alert_timer`, `_player_ref`, `_ALERT_REACTION_TIME = 0.4`.
  - New `_setup_awareness_area()` (second `Area3D`, radius
    `ENEMY_AWARENESS_RANGE`), called from `_ready()` alongside the existing
    proximity area, gated the same way (`if _tracking`).
  - New `_on_awareness_entered(body)`: `IDLE -> ALERTED` on player entry
    (guarded by `_alive`, `_tracking`, co-op inactive, `can_proximity_engage()`,
    not-already-defeated — mirrors `_on_body_entered()`'s guards).
  - New `_process(delta)` (first one in this file): ticks `ALERTED ->
    CHASING` after `_ALERT_REACTION_TIME`, then calls `_chase_player(delta)`
    every frame while `CHASING`. Gated off entirely in co-op
    (`NetworkManager.is_active()`) and outside `SceneManager.WORLD` state.
  - New `_chase_player(delta)`: lazily resolves the player via
    `get_tree().get_first_node_in_group("player")` (no new spawn-site wiring
    needed — `WorldScene._create_player_node()` already adds the player to
    that group), moves `position` toward it by `TRACKING_SPEED * delta`
    clamped to remaining distance.
  - The existing `AUTO_BATTLE_RANGE` proximity `Area3D`/`engage()` path is
    unchanged; since it's a child of the now-moving `EnemyNPC`, a completed
    chase naturally ends in `engage()` with no new code (physics re-evaluates
    Area3D overlap regardless of which side moved).
- Filed `tasks/backlog/BID-058--enemy-npc-engage-cooldown-missing.md`: docs in
  three files and this task's own research notes describe an
  `EnemyNPC.engage_cooldown` field ticked in `_process()` (GID-069) that does
  not exist in the current file — dropped by a later refactor without a doc
  update. Not fixed here (out of scope; this task adds the file's first real
  `_process()`, for chase movement).
- Verified: headless editor import clean; `tests/runner.gd` — 2337 passed, 0
  failed, 1 pending (pre-existing).

## Documentation Updates

- `docs/agent/enemies-and-npcs.md`: rewrote "EnemyNPC Scene" section to
  describe the awareness/pursuit system (IDLE/ALERTED/CHASING, awareness
  radius, chase movement, co-op scoping) in place of the old "Static entity —
  no movement AI" framing; updated the `IsoConst` integrations row for
  `TRACKING_SPEED`/`ENEMY_AWARENESS_RANGE`.
