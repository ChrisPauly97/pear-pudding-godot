# TID-424: Detection/Ambush State Machine Tests + Doc Update

**Goal:** GID-113
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
