# TID-582: Tracked Quest Drives Compass, Beacon & Minimap

**Goal:** GID-140
**Type:** agent
**Status:** done
**Depends On:** TID-581

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

WorldScene caches active quests + tracked quest (250 ms) and moves the beacon from that refresh; compass chevron and minimap pin read the cache; other quests get kind-coloured dots.

## Changes Made

- WorldScene: `active_quests()`, `tracked_quest()`, `tracked_quest_pos()`, `quest_pos()`, `_refresh_quests(force)` (called from `_process`, forced on story flag / `quest_tracking_changed`); beacon now follows the tracked quest's nearest target (`_place_objective_beacon`).
- WorldHUD compass: primary chevron = tracked quest; secondary dots per untracked story/treasure/bounty quest.
- Minimap: `_draw_quests` — diamonds per quest, tracked one larger/outlined, clamped to the rim when off-disc.
- MapViewOverlay (named maps): label shows the tracked quest; quest pins drawn.

## Documentation Updates

Covered by TID-585.
