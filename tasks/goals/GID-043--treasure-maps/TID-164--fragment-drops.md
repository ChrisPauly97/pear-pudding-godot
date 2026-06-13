# TID-164: Map-Fragment Item Model, Chest Drop Source, Save Fields

**Goal:** GID-043
**Type:** agent
**Status:** done
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

1. Bump SaveManager to version 19; add `treasure_fragments`, `active_treasure`, `treasures_completed` fields with migration, load_save, save(), and new_game() reset.
2. Add `fragment_collected`, `treasure_map_assembled`, `treasure_excavated` signals to GameBus.
3. Add `collect_treasure_fragment()`, `_assemble_treasure_map()`, `complete_treasure()` mutators to SaveManager (assembly preloads TreasureGen).
4. Connect signals in SceneManager._ready() to AchievementToast.show_text() handlers.
5. Add 20% fragment drop gate in WorldScene._handle_interact() chest section (infinite world only, no active map).
6. Write headless tests in tests/unit/test_treasure_system.gd.

## Changes Made

- `autoloads/SaveManager.gd`: version 19, new treasure fields, migration, load/save, new_game reset, `collect_treasure_fragment()`, `_assemble_treasure_map()`, `complete_treasure()`.
- `autoloads/GameBus.gd`: added `fragment_collected`, `treasure_map_assembled`, `treasure_excavated` signals.
- `autoloads/SceneManager.gd`: connected treasure signals to toast handlers `_on_fragment_collected`, `_on_treasure_map_assembled`, `_on_treasure_excavated`.
- `scenes/world/WorldScene.gd`: 20% fragment drop in chest interaction (infinite world, no active map).
- `tests/unit/test_treasure_system.gd`: 20+ tests covering migration, fragment lifecycle, TreasureGen determinism.
- `tests/runner.gd`: registered new test suite.

## Documentation Updates

- `docs/agent/treasure-maps.md`: new doc covering full system.
- `docs/agent/signals-and-constants.md`: added treasure signal rows.
- `docs/agent/docsplan.md`: added treasure-maps entry.
- `CLAUDE.md`: added treasure-maps row to doc table.
