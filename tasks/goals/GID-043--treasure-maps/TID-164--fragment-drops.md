# TID-164: Map-Fragment Item Model, Chest Drop Source, Save Fields

**Goal:** GID-043
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Fragments are the loot path for treasures. Define the data model, wire drops into the chest loot system, and persist state so players can reassemble maps across restarts. No UI yet; TID-166 surfaces fragments in the journal.

## Research Notes

- **Fragment as simple counter:** Fragments are NOT inventory items (to keep loot simple in v1). `SaveManager.treasure_fragments: int` (0–2) tracks collected fragments; when player gathers a 3rd, emit `GameBus.treasure_map_assembled()` signal, set `treasure_fragments = 0`, and initialize `active_treasure: Dictionary` with the dig site coords (computed in TID-165).
- **SaveManager fields:** Add migration (following existing pattern in `autoloads/SaveManager.gd` around line 150):
  - `treasure_fragments: int = 0` — count of fragments collected so far (max 2 before assembly)
  - `active_treasure: Dictionary = {}` — `{ "site_x": int, "site_z": int, "completed": bool }` or empty if no map active; `completed` flag prevents the DigSpot from spawning again
  - `treasures_completed: int = 0` — counter of maps fully excavated; used as a salt in the seeded dig-site derivation so each new map goes to a new location
- **Chest drop integration:** In **`scenes/world/entities/Chest.gd`**, the `_collect()` or opening logic currently calls `GameBus.chest_opened(card_id)`. Modify to check `rng.randf() < 0.20` (~20% chance) to drop a fragment instead of a card, but **only if `SaveManager.active_treasure` is empty** (no map currently active, to avoid overwhelming the player). Emit `GameBus.fragment_collected()` signal so toast feedback can display.
- **GameBus signals:** Add to `autoloads/GameBus.gd`:
  - `signal fragment_collected()` — fired when a fragment drops; toast displays "Fragment acquired!" (reuse `AchievementToast.show_text()` pattern from `scenes/ui/AchievementToast.gd`)
  - `signal treasure_map_assembled()` — fired when 3 fragments assemble; toast displays "Map complete! Dig site revealed."
- **Toast feedback:** Connect both signals in `SceneManager._ready()` (or a new setup method) to call `AchievementToast.show_text()` (defined in `scenes/ui/AchievementToast.gd` line 67). The method signature is `show_text(title: String, desc: String)`. On `GameBus.fragment_collected()`, call `AchievementToast.show_text("Fragment Found!", "You have %d/3 fragments" % SaveManager.treasure_fragments)`. On `GameBus.treasure_map_assembled()`, call `AchievementToast.show_text("Map Complete!", "A dig site has been revealed!")`. Reuse the existing toast system; do NOT create a new one.
- **Headless tests** (`tests/test_*.gd`): Write tests for:
  - Fragment count increments when collected (mock Chest entity, verify SaveManager.treasure_fragments increases by 1)
  - Assembly at 3 fragments (verify count resets to 0, `active_treasure` becomes non-empty, signal fires)
  - No fragment drops while a map is active (20% random drop check skipped if `active_treasure` is non-empty)
  - Save round-trip (serialize/deserialize SaveManager with fragments, verify values persist)

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
