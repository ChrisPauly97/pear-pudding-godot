# TID-290: Wire entry points — pause menu & menu scene buttons

**Goal:** GID-078
**Type:** agent
**Status:** pending
**Depends On:** TID-289

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Per the mobile/desktop parity rule, every interactive feature must be reachable via both keyboard and touch. We add a "Diagnostics" button to:
1. `OverworldPauseOverlay.gd` — reachable in-world via the pause key or the HUD pause button
2. `MenuScene.gd` — reachable from the main menu without starting a game

## Research Notes

- `scenes/ui/OverworldPauseOverlay.gd` builds its VBox in `_build_ui()`. Add a "Diagnostics" button after the "Settings" button, before "Save & Quit". Use the same `custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)` as the other buttons.
- Opening pattern: instantiate `DiagnosticsScene` (preloaded const), add as child of the overlay (`add_child(overlay)`), connect `overlay.closed` to `overlay.queue_free`. The pause overlay stays open behind the diagnostics panel.
- `scenes/ui/MenuScene.gd` — read the file to find where secondary buttons live (e.g., Achievements, Settings). Add "Diagnostics" in the same row/area.
- `DiagnosticsScene` is script-only — preload with `const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")` and instantiate with `.new()`.
- No new signals needed — the overlay's own `closed` signal (inherited from BaseOverlay) handles cleanup.
- No SceneManager state needed — diagnostics is a lightweight modal that doesn't affect game state.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
