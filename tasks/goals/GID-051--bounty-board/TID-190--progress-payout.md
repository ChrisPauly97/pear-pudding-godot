# TID-190: Progress Tracking via GameBus Signals + HUD Tracker + Coin Payout

**Goal:** GID-051
**Type:** agent
**Status:** done
**Depends On:** TID-188

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The live tracking layer. Progress increments are driven by existing GameBus signals (`battle_won`, `coins_changed`) without adding new coupling into gameplay systems. A small HUD panel lists active bounties with live progress counters. Coin payouts happen on claim, reading from SaveManager and applying the reward.

## Research Notes

- **Progress tracking helper:** Recommend adding to **autoloads/SaveManager.gd** (keeps bounty state centralized):
  - `increment_bounty_progress(bounty_id: String, bounty_type: String, match_data: Dictionary) -> void` — called from a central listener that watches GameBus signals
  - For `"defeat_enemy_type"` bounties: match_data is `{ "enemy_type": String }` from battle result
  - For `"defeat_in_biome"` bounties: match_data is `{ "biome_id": int }` — biome ID comes from **scenes/world/WorldScene.gd** which tracks `_current_biome` or similar (verify the field name in WorldScene; if absent, this task adds it)
  - For `"open_chests"` bounties: match_data is `{}` (just a count increment)
  - Only increment matching bounties in `active_bounties` array
  - Mark dirty on change
- **Signal listener placement** — Recommend a new helper node or wiring in SaveManager itself:
  - **Option A (cleaner):** Create a small autoload `autoloads/BountyTracker.gd` (Node-based, registers itself in project.godot after SaveManager). In `_ready()`:
    - Listen to `GameBus.battle_won` (cite real signal name from **autoloads/GameBus.gd** line 7)
    - Extract `enemy_type` from pending battle data (cite **autoloads/SceneManager.gd** lines 253–298 which already reads `pending_battle_enemy_data.get("enemy_type")` at line 258)
    - Call `SaveManager.increment_bounty_progress(id, "defeat_enemy_type", { "enemy_type": enemy_type })` for all active bounties
  - **Option B (simpler):** Wire the increment call directly in **autoloads/SceneManager.gd** `_on_battle_won()` method, immediately after the `mark_enemy_defeated()` call at line 264 (same spot where defeated_enemies tracking happens)
  - Recommend Option B for consistency: SceneManager is already the battle win handler and already has access to enemy_type
  - For biome-type bounties: at the same spot, call `SaveManager.increment_bounty_progress(id, "defeat_in_biome", { "biome_id": current_biome })` where `current_biome` is fetched from the current WorldScene's biome tracking (cite where this is stored — likely `WorldScene._current_biome` or via a SaveManager field; verify the actual field name in **scenes/world/WorldScene.gd**)
  - For chest bounties: add listener in **scenes/world/WorldScene.gd** where chests are opened (cite line 1187 `mark_chest_opened(cid)`) and call `SaveManager.increment_bounty_progress(...)` right after
  - All listeners check: only increment if bounty is in `active_bounties` (not offered, not claimed)
- **SaveManager coin payout:**
  - Method `claim_bounty(bounty_id: String) -> int` — returns the coin reward amount
  - Finds bounty in `active_bounties` by ID
  - Verifies it's marked complete (progress >= count)
  - Sets `claimed: true`
  - Calls `add_coins(reward)` (cite line 476 of **autoloads/SaveManager.gd**)
  - Returns the reward amount for the UI toast
  - Guards against double-claim: if already claimed, returns 0 (no coins)
  - Mark dirty
- **HUD tracker panel:**
  - New Control node in **scenes/world/WorldScene.tscn** or created in **scenes/world/WorldScene.gd** at runtime
  - Position: top-right HUD area (above or below the coin counter, cite where coin counter is in WorldScene HUD layout)
  - Content: vertical list of active bounty lines, e.g.:
    - "Ghoul packs 2/3"
    - "Open chests 1/2"
    - (max 3 lines, hidden if no active bounties)
  - Update every frame or on signal: listen to a new signal `GameBus.bounty_progress_changed(bounty_id: String, progress: int, count: int)` emitted by `SaveManager.increment_bounty_progress()` (add signal to **autoloads/GameBus.gd**)
  - Label sizing: 2% vh font per **CLAUDE.md** viewport-relative rules (cite line in UI Sizing table)
  - Mobile parity: labels are read-only; no touch interaction needed (bounties are managed via the board UI, not the tracker)
- **Bounty completion detection:**
  - When `progress >= count` in a bounty row, mark it complete in SaveManager: add field `completed: bool`
  - Set `completed: true` when the increment brings progress to >= count
  - Emit `GameBus.bounty_completed(bounty_id)` signal (new, add to GameBus)
  - HUD tracker updates row to show a checkmark or "(Complete — Claim at board)" suffix
- **Tests (headless):**
  - Progress increment matching: only the right bounty type increments on the right signal (e.g., defeating a "ghoul_pack" enemy only increments bounties where bounty_type="defeat_enemy_type" and target="ghoul_pack", not other types)
  - Biome matching: defeating enemies in biome 2 (desert) only increments "defeat_in_biome" bounties targeting biome 2, not biome 3
  - Completion: when progress reaches count, `completed` flag is set and `bounty_completed` signal fires
  - Claim once: calling claim_bounty() twice on the same bounty returns 0 coins the second time
  - No progress while unaccepted: defeating an enemy matching an offered (not accepted) bounty does not increment it
  - Coin payout: claiming a bounty with reward 75 calls `add_coins(75)` and emits `coins_changed(new_total)` (cite coins_changed signal from **autoloads/SaveManager.gd** line 6)

## Plan

1. Add `bounty_progress_changed` and `bounty_completed` signals to `GameBus.gd`.
2. Add `increment_bounty_progress(bounty_type, match_data)` to `SaveManager.gd` — iterates active bounties, matches type + target, increments progress, sets `completed`, emits both new signals.
3. Call `increment_bounty_progress("defeat_enemy_type", ...)` in `SceneManager._on_battle_won()` (both spire and normal paths) after `record_enemy_defeated`.
4. Call `increment_bounty_progress("defeat_in_biome", ...)` in `WorldScene._on_battle_won()` using `_current_biome` + `BountyGen.BIOME_NAMES`.
5. Call `increment_bounty_progress("open_chests", {})` in `WorldScene._handle_interact()` after `mark_chest_opened`.
6. Add bounty tracker HUD to `WorldScene`: `_build_bounty_tracker()`, `_refresh_bounty_tracker()`, `_bounty_short_label()`, and handlers for the two new GameBus signals.
7. Create `tests/unit/test_bounty_progress.gd` with 13 tests; register in `runner.gd`.

## Changes Made

- **Updated `autoloads/GameBus.gd`**: added `bounty_progress_changed(bounty_id, progress, count)` and `bounty_completed(bounty_id)` signals.
- **Updated `autoloads/SaveManager.gd`**: added `increment_bounty_progress(bounty_type, match_data)` — matches type + target for all three bounty types, increments progress on matching active bounties, sets `completed: true` and emits `bounty_completed` when progress reaches count, emits `bounty_progress_changed`, marks dirty.
- **Updated `autoloads/SceneManager.gd`**: calls `save_manager.increment_bounty_progress("defeat_enemy_type", {"enemy_type": ...})` in both the spire-path and normal-path of `_on_battle_won()`.
- **Updated `scenes/world/WorldScene.gd`**: 
  - Added `var _bounty_tracker: VBoxContainer` field.
  - `_on_battle_won()` now calls `increment_bounty_progress("defeat_in_biome", ...)` using `_current_biome` + `BountyGen.BIOME_NAMES` for infinite-world battles.
  - Chest opening now calls `increment_bounty_progress("open_chests", {})`.
  - Added `_build_bounty_tracker()`, `_refresh_bounty_tracker()`, `_bounty_short_label()`, `_on_bounty_progress_changed()`, `_on_bounty_completed()` — live HUD panel at top-left showing "Target N/M" lines for each active non-claimed bounty, green when complete.
  - Connected `GameBus.bounty_progress_changed` and `GameBus.bounty_completed` to tracker refresh.
- **Created `tests/unit/test_bounty_progress.gd`**: 13 tests covering enemy-type matching, biome matching, chest tracking, completion flag, no-progress-while-not-accepted, double-claim guard, coin payout. All pass.
- **Updated `tests/runner.gd`**: registered `test_bounty_progress.gd`.

## Documentation Updates

- Updated `docs/agent/bounty-board.md` with progress tracking API, HUD tracker, signal details.
