# TID-583: Realm Map in the Overworld

**Goal:** GID-140
**Type:** agent
**Status:** done
**Depends On:** TID-581

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`WorldScene._open_map_view` returns early in the overworld, so M / minimap tap does nothing where the story happens. Add a vector realm map.

## Research Notes

- Towns: `RealmLayout.TOWNS`/`world_rect`; roads: `RealmLayout.ROADS` (tiles); waystones `RealmLayout.entities("waystones")`.
- Close pattern: `MapViewOverlay._unhandled_input` (map_view / ui_cancel), `closed` signal.

## Plan

Vector realm map (towns, roads, waystones, player, quest pins, waypoint) opened by WorldScene._open_map_view when in the overworld.

## Changes Made

- New `scenes/ui/RealmMapOverlay.gd`: north-up map framed by `realm_bounds()` (all towns/roads + player + quest targets, square); tracked quest pin labelled; right-click / long-press sets waypoint; M/Esc/tap-outside/X close.
- WorldScene: `_toggle_realm_map()`, `_realm_overlay`; M / minimap tap in the overworld now opens it (was a no-op).
- Tests: `tests/unit/test_realm_map.gd`; `world_scene_smoke` opens/closes it and checks a tracked quest exists.

## Documentation Updates

Covered by TID-585.
