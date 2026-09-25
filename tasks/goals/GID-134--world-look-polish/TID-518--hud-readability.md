# TID-518: HUD Readability

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Top-left location/coins/XP text overlaps ("Attuned" over "World: Infinite") and has no backing; compass has no matching frame.

## Research Notes

`scenes/world/WorldHUD.gd` builds the labels; compass ribbon in its own script.

## Plan

Chip backings + outlines for map/coins/XP; ley indicator moved under the compass.

## Changes Made

WorldHUD.hud_chip_style/outline_label/_style_status_labels; XP row in a chip; ley chip.

## Documentation Updates

ui-and-scene-management.md HUD section.
