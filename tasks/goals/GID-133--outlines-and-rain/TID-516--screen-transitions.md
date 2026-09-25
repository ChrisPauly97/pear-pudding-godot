# TID-516: Stylised Screen Transitions

**Goal:** GID-133
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-09-25): "transitions ok" — replace the plain 0.2 s black fade between world, battle and menus with a stylised wipe.

## Research Notes

`autoloads/TransitionManager.gd` (CanvasLayer 100, ColorRect alpha tween, `transition(change_fn)` used 12×). `SceneManager._restore_world(after)` runs post-swap work inside the transition, so the API and awaited `fade_out`/`fade_in` must stay.

## Plan

Shader wipe on the existing TransitionManager rect (API kept, optional style); diamond mosaic sweep default, swirl iris for battle entry.

## Changes Made

- New `assets/shaders/screen_wipe.gdshader` (+ .uid); `TransitionManager` rewritten around it (0.3 s, `STYLE_WIPE`/`STYLE_BATTLE`, hidden when idle).
- `SceneManager._enter_battle` uses `STYLE_BATTLE`.
- Tests: new `test_screen_wipe.gd`; spire_draft_smoke (transition-timing sensitive) passes. Visual check of both styles.

## Documentation Updates

ui-and-scene-management.md Screen Transitions section; CLAUDE.md spire-draft learning timing.
