# TID-578: Realm Map in the Overworld

**Goal:** GID-139
**Type:** agent
**Status:** pending
**Depends On:** TID-576

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

## Changes Made

## Documentation Updates
