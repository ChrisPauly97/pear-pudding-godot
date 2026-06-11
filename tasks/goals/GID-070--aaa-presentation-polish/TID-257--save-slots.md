# TID-257: Save Slots & Slot Select UI

**Goal:** GID-070
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
