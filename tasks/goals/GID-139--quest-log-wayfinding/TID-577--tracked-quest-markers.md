# TID-577: Tracked Quest Drives Compass, Beacon & Minimap

**Goal:** GID-139
**Type:** agent
**Status:** pending
**Depends On:** TID-576

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Persist a tracked quest id; compass chevron, beacon and a new minimap pin follow it; other quests get dim compass dots.

## Research Notes

- Compass markers: `WorldHUD._create_compass`; beacon: `WorldScene._refresh_objective_beacon`; minimap draw: `Minimap._on_draw` (`_to_minimap`, edge clamp like `_draw_waypoint`).
- Save field: one PERSISTED_FIELDS entry + var.

## Plan

## Changes Made

## Documentation Updates
