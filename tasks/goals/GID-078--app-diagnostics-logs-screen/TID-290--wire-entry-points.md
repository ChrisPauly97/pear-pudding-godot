# TID-290: Wire entry points — pause menu & menu scene buttons

**Goal:** GID-078
**Type:** agent
**Status:** done
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

1. In `OverworldPauseOverlay.gd`: add `const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")`. Add a "Diagnostics" button after Settings and before Save & Quit with same sizing (`Vector2(_vh*0.3, _vh*0.07)`). `_on_diagnostics()` instantiates, adds as child, sets full-rect anchors, connects `closed` to `queue_free`.
2. In `MenuScene.gd`: same `const DiagnosticsScene` preload. Call `_add_btn("Diagnostics", _on_diagnostics)` before Quit. `_on_diagnostics()` uses the same open pattern (`add_child`, `set_anchors_preset`, connect `closed`).
3. Create `docs/agent/app-diagnostics.md` covering Key Features, How It Works, Integrations.

## Changes Made

- `scenes/ui/OverworldPauseOverlay.gd`: added `const DiagnosticsScene` preload; added a "Diagnostics" `Button` between Settings and Save & Quit; added `_on_diagnostics()` that instantiates and shows the overlay as a child node.
- `scenes/ui/MenuScene.gd`: added `const DiagnosticsScene` preload; injected a "Diagnostics" button via `_add_btn()` before Quit in the main menu; added matching `_on_diagnostics()` handler.
- Created `docs/agent/app-diagnostics.md` with full feature documentation.

## Documentation Updates

- Created `docs/agent/app-diagnostics.md`.
