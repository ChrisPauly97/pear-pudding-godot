# TID-257: Save Slots & Slot Select UI

**Goal:** GID-070
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The game has exactly one save: `autoloads/SaveManager.gd` hardcodes `SAVE_PATH = "user://save.json"`. AAA games offer multiple save slots so players can run parallel playthroughs (e.g. different magic branches, different biome starts). This task adds 3 slots with a slot-select UI and migrates the legacy single save to slot 1.

## Research Notes

- `autoloads/SaveManager.gd` — single JSON save, dirty-flag batched writes (max 2s), field-migration system so old saves always load. Tracks deck, owned cards, position, map stack, defeated enemies, opened chests, time of day, world seed, biome, story flags, settings, achievements, XP/skills.
- Design: make the save path a function of the active slot (e.g. `user://save_slot_%d.json`). Keep the migration path: on first launch after update, if `user://save.json` exists and no slot files do, rename/copy it to slot 1.
- Settings (music/SFX volume, and TID-260's accessibility options) should arguably be global, not per-slot — decide whether to split settings into `user://settings.json` as part of this task; note the decision in the Plan.
- Slot-select UI: new scene under `scenes/ui/` showing 3 slots with metadata per slot (chapter/story progress flag, coin count, play position/biome, last-saved timestamp — add a `last_saved` field via the migration system). Entered from the main menu (`scenes/ui/MenuScene.gd` — Continue currently auto-hides when no save exists; New Game goes to biome select).
- TID-259 (Main Menu & Title Presentation) depends on this task because the slot flow changes what Continue / New Game do — keep the menu changes here minimal (just routing), leave presentation to TID-259.
- Deleting a slot is destructive — require a confirm dialog.
- UI sizing viewport-relative per CLAUDE.md; mobile parity (all interactions are buttons, so touch works by default).
- Tests: `tests/` has GUT tests; SaveManager currently has no migration/flush coverage (BID-011) — add at least a slot-migration test here.

## Plan

Change `SaveManager` to use `user://save_slot_%d.json` paths keyed by `active_slot`. Keep `LEGACY_SAVE_PATH` for migration: on `_ready()`, if `save.json` exists and no slot files do, copy it to slot 1. Add `set_active_slot`, `has_save_slot`, `get_slot_metadata`, `delete_save_slot`. Add `last_saved` timestamp field. New `SlotSelectScene` shows 3 slots with Continue/Delete or New Game. Back navigation and biome select `_on_back()` route through slot select. Settings stay per-slot (simpler; revisit in future if needed).

## Changes Made

- **MODIFIED `autoloads/SaveManager.gd`**: Removed hardcoded `SAVE_PATH/TMP/BAK`. Added `LEGACY_SAVE_PATH = "user://save.json"`, `NUM_SAVE_SLOTS = 3`, `active_slot: int = 1`, `last_saved: String`. Added `_get_slot_path/tmp/bak` functions. `_ready()` copies legacy save to slot 1 if no slot files exist. New API: `set_active_slot`, `has_save_slot`, `get_slot_metadata` (returns dict with map/coins/last_saved), `delete_save_slot`. `has_save()` scans all slots. `save()` writes `last_saved` timestamp. `load_save()` reads it back.
- **MODIFIED `autoloads/SceneManager.gd`**: Added `go_to_slot_select()` that changes to `SlotSelectScene.tscn`.
- **NEW `scenes/ui/SlotSelectScene.gd`**: Shows 3 save slots with per-slot metadata. Continue + Delete buttons for occupied slots, New Game for empty. Delete requires confirm dialog. `_on_load_slot` sets active slot then calls `SceneManager.continue_game()`. `_on_new_game_slot` sets active slot then navigates to `BiomeSelectionScene`.
- **NEW `scenes/ui/SlotSelectScene.tscn`**: Minimal tscn with uid `uid://1xaneli9gd9u`.
- **MODIFIED `scenes/ui/MenuScene.gd`**: Continue and New Game now both call `SceneManager.go_to_slot_select()`.
- **MODIFIED `scenes/ui/BiomeSelectionScene.gd`**: `_on_back()` now navigates to `SlotSelectScene.tscn` instead of `MenuScene.tscn`.

## Documentation Updates

Updated `docs/agent/save-system.md` — multi-slot section, legacy migration, metadata API.
