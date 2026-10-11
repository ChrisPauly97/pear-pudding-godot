# TID-792: Gear UI: stats, comparison, level requirement

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-789

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Item tooltips list stats (rating and the % it gives at the player's level), band / rarity colour and level
requirement; compare against the equipped item (green / red deltas); the character sheet totals every stat.
Touch and mouse parity (long-press to inspect).

## Research Notes

- `scenes/ui/CharacterScene.gd`, `BlacksmithScene.gd`, inventory tiles (`tests/inventory_tiles_smoke.gd`);
  `UiUtil` factories, `UiUtil.rarity_color`, `LongPressDetector`.
- Viewport-relative sizing rules in CLAUDE.md.

## Plan

## Changes Made

## Documentation Updates
