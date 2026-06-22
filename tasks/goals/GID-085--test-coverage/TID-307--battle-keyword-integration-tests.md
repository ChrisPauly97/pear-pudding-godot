# TID-307: BattleScene keyword integration tests + resolve hero freeze/stun

**Goal:** GID-085
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

BattleScene-level tests are absent per BID-012. Ward/Surge/Shroud keyword interactions and spell resolution are only covered by pure-logic unit tests, not end-to-end.

Additionally, hero `freeze`/`stun` tick handling (BattleScene.gd:1665-1678, PlayerState.gd:65) is unreachable — no effect ever applies these to a hero. This task must make a decision: either wire hero freeze/stun to a real card effect or delete the dead paths.

## Plan

1. Create `tests/unit/test_keyword_integration.gd` testing Surge, Ward, and Shroud at the game-logic level via `PlayerState`/`GameState`/`CardInstance` (no BattleScene instantiation needed).
2. **Hero freeze/stun decision**: **remove** the dead code paths:
   - `PlayerState.can_play()`: remove `if hero.has_status("freeze"): return false` (nothing applies hero freeze)
   - `BattleFx._tick_statuses_on_hero()`: remove freeze and stun tick blocks (nothing applies them to heroes)
3. Add a test that verifies hero freeze no longer blocks `can_play()` post-removal.

## Changes Made

- Created `tests/unit/test_keyword_integration.gd` with 23 tests covering:
  - **Surge**: no summoning sickness after play, can attack immediately, non-Surge card cannot attack same turn, round-trip preserves keyword
  - **Ward**: `_ward_valid_targets` logic: all cards valid when no Ward present; only Ward cards valid when Ward present; multiple Ward cards all appear; non-Ward excluded; keyword round-trip
  - **Shroud**: `shroud_active` true on creation; first hit absorbed (no HP lost); `shroud_active` becomes false after hit; second hit deals damage; plain card has no shroud; round-trip preserves both consumed and unconsumed states
  - **Hero freeze dead-code removal**: confirms `can_play` is not blocked by hero freeze after removal
- `game_logic/battle/PlayerState.gd`: removed `if hero.has_status("freeze"): return false` from `can_play()` — nothing ever applies freeze to a hero; this was unreachable dead code
- `scenes/battle/BattleFx.gd`: removed hero freeze and stun tick blocks from `_tick_statuses_on_hero()` — same reason; hero poison tick retained as cards can apply poison to heroes

## Documentation Updates

None required — no new architecture introduced.
