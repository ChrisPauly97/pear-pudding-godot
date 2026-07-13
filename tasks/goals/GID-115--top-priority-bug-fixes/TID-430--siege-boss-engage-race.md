# TID-430: Fix Co-op Siege Boss Engage Race (Solo vs Joint Battle Desync)

**Goal:** GID-115
**Type:** agent
**Status:** done
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

1. Generalize the existing GID-106 Spire guard in `SceneManager._on_enemy_engaged`
   into a pure static predicate `_is_coop_joint_battle_enemy(enemy_data,
   current_map_name) -> bool` covering both the Spire floor boss and the
   `siege_boss_*` id prefix (the only place that prefix is generated is
   `CoopSiege.gd::_boss_id`, so the id alone is a sufficient, map-independent
   discriminator — matches the task's suggested fix shape).
2. Replace the two separate inline guards with one call to the predicate, still
   gated on `NetworkManager.is_active()` in the caller (so single-player sieges/
   Spire keep using the solo path — no active co-op session ever satisfies
   `is_active()`).
3. This handler is connected once at autoload boot and runs identically on host
   and client (`EnemyNPC.engage()` / `BlightHeart` emit `GameBus.enemy_engaged`
   locally on whichever peer touches the enemy), so the fix covers both without
   extra client-specific handling.
4. Add unit tests for the new pure predicate in
   `tests/unit/test_scene_manager_state.gd` (normal enemy, siege boss on any map,
   Spire enemy on/off a Spire floor map, missing id) — `NetworkManager.is_active()`
   itself isn't stubbed/tested since it depends on a live `MultiplayerPeer` state
   that isn't practical to fake in a headless unit test; extracting the predicate
   keeps the actually-interesting map/id logic fully covered.
5. Archive `BID-044` and update `tasks/index.md`.

## Changes Made

- `autoloads/SceneManager.gd` — added `static func _is_coop_joint_battle_enemy()`
  and rewrote `_on_enemy_engaged`'s co-op guard to call it once instead of two
  separate inline checks (one of which was BID-044's missing siege-boss guard).
- `tests/unit/test_scene_manager_state.gd` — 5 new cases for
  `_is_coop_joint_battle_enemy` (auto-discovered by `tests/runner.gd`).
- Archived `tasks/backlog/BID-044--siege-boss-engage-signal-race.md` to
  `tasks/archive/backlog/` and updated `tasks/index.md`.

**Verification note:** same sandbox constraint as the rest of this goal — no
Godot binary available and the 4.6-stable release download returns HTTP 403
from the outbound proxy, so `godot --headless --editor --quit` and
`tests/runner.gd` could not be run here. The diff was re-read in full to confirm
the predicate is a straight generalization of the pre-existing, already-shipped
Spire guard (GID-106/TID-391) plus the previously-missing siege-boss case;
recommend running the headless import + test suite in CI before merge.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — the GID-106/TID-391 research note that
  documented BID-044 as a found-but-deliberately-unfixed gap now records the
  resolution: the two inline guards were generalized into
  `SceneManager._is_coop_joint_battle_enemy()`, covering both the Spire boss
  and the siege boss under one `NetworkManager.is_active()` gate.
