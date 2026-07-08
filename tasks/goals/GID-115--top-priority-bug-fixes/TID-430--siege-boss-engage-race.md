# TID-430: Fix Co-op Siege Boss Engage Race (Solo vs Joint Battle Desync)

**Goal:** GID-115
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Promotes **BID-044**. When a co-op party engages the Town Siege boss, two listeners
race on `GameBus.enemy_engaged`, and connection order guarantees the wrong one wins on
the host: `SceneManager._on_enemy_engaged` (connected at autoload boot, always first)
starts a **solo** `BattleScene` and flips `_state = State.BATTLE`; then
`WorldScene._on_enemy_engaged_coop` routes the same engage to
`SceneManager.enter_coop_pve_battle(...)`, which guards on `_state == State.WORLD` and
silently no-ops. Clients, who only receive the `notify_coop_pve_start` RPC, correctly
enter the joint battle. Net effect: the host fights a solo duel against the siege boss
while clients sit in a joint co-op battle — a visible desync that breaks the shipped
Town Siege feature (GID-103) in co-op.

## Research Notes

- `autoloads/SceneManager.gd:426` — `_on_enemy_engaged`. Already contains the exact
  precedent to generalize: the GID-106 Spire guard at lines 429–438 skips the solo path
  when `NetworkManager.is_active() and current_map.begins_with("spire_floor_") and
  str(enemy_data.get("id", "")) == "spire_enemy"`. Its comment explicitly cites BID-044
  as the analogous unresolved siege risk.
- `scenes/world/WorldScene.gd:711` — `GameBus.enemy_engaged.connect(_on_enemy_engaged_coop)`
  (connected per-map, always **after** SceneManager's boot-time connection).
- `scenes/world/WorldScene.gd:1427` — `_on_enemy_engaged_coop`; at line 1437 it routes
  `eid.begins_with("siege_boss_")` to `_coop_engage_siege_boss(edata)`.
- `scenes/world/WorldScene.gd:2902` — `_coop_engage_siege_boss` →
  `_coop_start_siege_boss_battle` (line 2919) → `SceneManager.enter_coop_pve_battle(...)`.
- The Spire guard deliberately checks `current_map` rather than
  `is_coop_spire_active()` because the latter is host-only (see the doc comment at
  `SceneManager.gd:1694`). For the siege boss the discriminator is the enemy id prefix
  `"siege_boss_"`, which is present in `enemy_data` on every peer — no map check needed,
  but mirror the `NetworkManager.is_active()` gate so single-player sieges still route
  to the solo battle (single-player siege raiders/boss legitimately use the solo path).
- **Fix shape (minimal, matches precedent):** in `_on_enemy_engaged`, alongside the
  Spire guard, `return` early when `NetworkManager.is_active() and
  str(enemy_data.get("id", "")).begins_with("siege_boss_")`. BID-044 also sketches a
  more robust source-side fix (predicate consulted by `EnemyNPC.engage()` before
  emitting) — consider it, but the targeted guard is lower-risk and consistent with how
  GID-106 solved the identical problem for the Spire.
- Also verify the co-op siege boss engage path on a **client**: clients also run
  `_on_enemy_engaged` locally if they touch the boss; the same guard must cover them.
- BID-044 notes verification requires a headless run or multi-peer log trace — at
  minimum add a unit test asserting `_on_enemy_engaged` returns without state change
  for a `siege_boss_*` id while `NetworkManager.is_active()` is stubbed true, mirroring
  whatever test shape GID-106/TID-391 used for the Spire guard (see
  `tasks/goals/GID-106--party-legacy/TID-391*.md`).
- After the fix, move `tasks/backlog/BID-044--siege-boss-engage-signal-race.md` to
  `tasks/archive/backlog/` and update `tasks/index.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
