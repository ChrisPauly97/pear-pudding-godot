# TID-424: Detection/Ambush State Machine Tests + Doc Update

**Goal:** GID-113
**Type:** agent
**Status:** done
**Depends On:** TID-421, TID-422, TID-423

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Closes out the goal: tests the new alert-state machine (IDLE/ALERTED/CHASING
transitions, ambush-flag determination) and brings
`docs/agent/enemies-and-npcs.md` up to date, since the "Mixed engagement"
description it currently gives (binary tracking/wanderer split) will be
inaccurate once TID-420-423 ship.

## Research Notes

- Testing challenge: `EnemyNPC` is a scene node (`CharacterBody3D` + `Sprite3D`
  + `Area3D`), which the existing GUT-based unit test suite generally avoids in
  favor of testing pure `game_logic/` classes headlessly (see
  `tests/unit/test_pathfinder.gd` for the pattern of testing `Pathfinder.gd`,
  a pure `RefCounted` class, in isolation). If TID-420's alert-state machine
  logic (IDLE/ALERTED/CHASING transition rules, give-up radius/timer math,
  ambush-flag determination) was written as pure logic inside `EnemyNPC.gd`
  methods, consider whether it's extractable into a small pure helper (e.g.
  `game_logic/world/EnemyAlertState.gd`, `extends RefCounted`, following the
  same "pure logic separated from the scene node" pattern already used for
  `TerrainMath.gd`, `Pathfinder.gd`, `BattlefieldRules.gd`) so it can be unit
  tested without instantiating the full scene tree. Flag this refactor
  suggestion during Plan for TID-420 retroactively if it wasn't already done —
  don't duplicate logic between a scene method and a new pure helper.
- Test cases needed (exact file: new `tests/unit/test_enemy_alert_state.gd` if
  a pure helper class exists, or `tests/integration/` if scene instantiation is
  unavoidable — check whether an integration test tier already exists in this
  repo before assuming unit-only):
  1. Distance below awareness radius → stays IDLE.
  2. Distance within awareness radius → transitions to ALERTED (not yet
     CHASING/caught).
  3. Contact (within `AUTO_BATTLE_RANGE`) while ALERTED/CHASING → `engage()`
     produces `enemy_ambush = true`.
  4. Contact while IDLE (wanderer, or tracking enemy that never got close
     enough to alert) → `engage()` produces `player_ambush = true`.
  5. Distance exceeds give-up radius for the required duration while
     ALERTED/CHASING → reverts to IDLE; a subsequent contact from IDLE again
     produces `player_ambush = true` (proves give-up correctly re-arms the
     ambush bonus).
  6. `player_ambush` and `enemy_ambush` are mutually exclusive — never both
     true for the same engage.
- `docs/agent/enemies-and-npcs.md` sections needing rewrite:
  - "Key Features" bullet: "Mixed engagement: aggressive enemies... attack on
     proximity via Area3D; wanderers... wait for player interaction" (line 7) —
     replace with a description of the new detection/pursuit/ambush model.
  - "EnemyNPC Scene" section, "Tracking split (per enemy type)" subsection
    (lines 97-102) — update to describe awareness radius, alert states, and
    chase movement instead of "aggressive = instant proximity trigger".
  - "Integrations with Other Features" table — add rows for the new
    `player_ambush`/`enemy_ambush` enemy_data flags and their consumption in
    `BattleScene`.
  - Add asset/constant references for any new `IsoConst` fields introduced by
    TID-420/423 (`ENEMY_AWARENESS_RANGE`, `ENEMY_GIVEUP_RANGE`, etc.) to the
    existing `IsoConst` bullet in the "Integrations" table (line 221).
- Also update `docs/agent/battle-system.md` if TID-421/422's HP-delta
  application lives adjacent to `_apply_gambit_handicaps()` — add a short
  cross-reference so a future reader of the Gambits section knows ambush
  modifiers exist too (don't duplicate the Gambits table, just note the
  sibling mechanism and link to `enemies-and-npcs.md`).

## Plan

**Retroactive extraction (per the research note's suggestion):** TID-420-423
wrote the alert-state transition rules directly inside `EnemyNPC.gd` methods.
This task extracts them into `game_logic/world/EnemyAlertState.gd` (`extends
RefCounted`, static pure functions), the same "pure logic separated from the
scene node" shape as `TerrainMath.gd`/`Pathfinder.gd`/`BattlefieldRules.gd`,
and refactors `EnemyNPC.gd` to delegate to it — behavior-preserving, verified
by the full suite still passing after the refactor plus the new unit tests
exercising the extracted rules directly.

- `check_awareness(state, distance, awareness_range) -> int`: IDLE -> ALERTED
  transition rule. Also used from `_on_awareness_entered()` (computing the
  actual flat distance at the moment the `Area3D` fires) so there is one
  canonical "is this close enough to notice" decision instead of the
  `Area3D`'s physics-radius check being implicitly a second copy of it.
- `tick_reaction(state, alert_timer, delta, reaction_time) -> Dictionary`:
  ALERTED -> CHASING after the reaction beat.
- `tick_giveup(state, giveup_timer, delta, distance, giveup_range,
  hold_time) -> Dictionary`: sustained-distance give-up back to IDLE.
- `classify_ambush(state) -> Dictionary`: `{player_ambush, enemy_ambush}` at
  contact time.

`EnemyNPC.gd`'s own `AlertState` enum is removed in favor of
`_EnemyAlertState.State`; all 12 `AlertState.X` call sites become
`_EnemyAlertState.State.X`. `_process()`/`_on_awareness_entered()`/
`engage()` now call the pure functions and just apply the returned
state/timers — no behavior change, only where the decision logic lives.

**Test file:** `tests/unit/test_enemy_alert_state.gd` (auto-discovered by
`tests/runner.gd` from `tests/unit/test_*.gd`, mirrors
`tests/unit/test_pathfinder.gd`'s `extends
"res://tests/framework/test_case.gd"` + `const X = preload(...)` shape).
Covers the 6 cases from Research Notes directly against
`EnemyAlertState`'s pure functions (no scene instantiation needed):
below/within awareness radius, reaction-timer completion, give-up
distance+duration (including the "reset timer if player returns" case),
`classify_ambush` for IDLE/ALERTED/CHASING, and mutual exclusivity.

**Docs:** `docs/agent/enemies-and-npcs.md` — the "EnemyNPC Scene" section
already got a substantial rewrite in TID-420's commit describing
awareness/pursuit; this task's remaining doc work is the "Key Features"
bullet (still describes the old binary split) and the "Integrations" table
row for `player_ambush`/`enemy_ambush`. `docs/agent/battle-system.md` gets a
one-line cross-reference next to the Gambits section pointing at the ambush
mechanism, per the research note (not duplicating the Gambits table).

## Changes Made

- New `game_logic/world/EnemyAlertState.gd` (`extends RefCounted`): pure
  static functions `check_awareness`, `tick_reaction`, `tick_giveup`,
  `classify_ambush` — the whole IDLE/ALERTED/CHASING transition rule set
  extracted from `EnemyNPC.gd`, mirroring the `TerrainMath`/`Pathfinder`/
  `BattlefieldRules` "pure logic separated from the scene node" pattern.
- `scenes/world/entities/EnemyNPC.gd`: removed the local `AlertState` enum
  in favor of `_EnemyAlertState.State`; `_process()`,
  `_on_awareness_entered()`, and `engage()` now delegate their state
  decisions to the pure helper instead of inlining the rules — behavior
  unchanged (verified: same headless import clean, full suite still 0
  failures after the refactor). Added `_flat_distance_to()` and
  `_tick_reaction()` helpers along the way to keep `_process()` readable
  once it's just applying returned Dictionaries.
- New `tests/unit/test_enemy_alert_state.gd` (auto-discovered): 18 tests
  covering all 6 Research Notes cases plus reentry-resets-timer and
  mutual-exclusivity-across-all-3-states. Full suite: 2355 passed (2337 +
  18 new), 0 failed, 1 pending (pre-existing), headless import clean.

## Documentation Updates

- `docs/agent/enemies-and-npcs.md`:
  - "Key Features" bullet rewritten to describe detection/pursuit/ambush
    instead of the old binary tracking/wanderer split.
  - "Awareness & pursuit" section (TID-420's original writeup) updated to
    describe the `EnemyAlertState` extraction, the TID-422 telegraph, the
    TID-423 give-up mechanic, and `ENEMY_GIVEUP_RANGE`.
  - New "Ambush bonus/penalty" subsection describing `player_ambush`/
    `enemy_ambush`, the `BattleScene` integration point, and the
    rival/duel-panel scope boundary.
  - "Integrations with Other Features" table: added `EnemyAlertState` and
    `BattleScene` (ambush consumer) rows; `IsoConst` row gained
    `ENEMY_GIVEUP_RANGE`.
- `docs/agent/battle-system.md`: added a short cross-reference at the end
  of the Gambits "Tests" subsection pointing at the sibling ambush
  mechanism in `enemies-and-npcs.md`, without duplicating the Gambit
  catalogue table.
