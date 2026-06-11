# TID-256: Overworld Pause Menu

**Goal:** GID-070
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles have a pause overlay (Resume / Settings / Return to Menu) but the overworld has none — pressing ESC in WorldScene does nothing. A shippable game needs pause everywhere, on both desktop and mobile.

## Research Notes

- Existing pattern: `scenes/battle/BattleScene.gd` `_show_pause_overlay()` (~lines 542–619) builds a pause overlay with Resume / Settings / Return to Menu buttons. Reuse its structure and styling; consider extracting a shared `PauseOverlay` scene/script under `scenes/ui/` rather than copy-pasting (BID-009 notes overlay boilerplate is already duplicated across 8 UI scenes — do not add a 9th copy).
- Settings screen already exists: `scenes/ui/SettingsScene.gd` (music/SFX sliders persisted via SaveManager, applied to AudioManager). The pause menu's Settings button should route there via SceneManager.
- Pause semantics: use `get_tree().paused = true` with the overlay's `process_mode = PROCESS_MODE_ALWAYS`; verify the day/night tick, enemy AI wander, and autosave dirty-flag flush in `autoloads/SaveManager.gd` all respect tree pause.
- Save & Quit: SaveManager uses dirty-flag batched writes (max 2s delay) — call its flush/save method explicitly before returning to the menu.
- Input: add an ESC binding (e.g. `ui_cancel` or a new `pause` action) in `project.godot`. Per the CLAUDE.md mobile/desktop parity rule, every key binding needs a touch equivalent: add a small pause button to the world HUD (HUD currently shows map label, coin count, level, XP bar, interact prompt; minimap is in `scenes/world/Minimap.gd`).
- UI sizing must be viewport-relative per CLAUDE.md (button height ~5–6% vh, fonts ~2–2.5% vh).
- Coordinate with TID-255: if TransitionManager exists, fade when leaving to menu.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
