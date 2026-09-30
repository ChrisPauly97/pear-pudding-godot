# TID-652: Chest and door opening frames

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chests swap closed→open instantly; doors have one frame; mimic has no reveal. Part of GID-152 (art motion pass).

## Research Notes

- `generate_sprites.py` `chest_body()` / `chest()` / `door()`: add 2-3 intermediate frames. Mimic (`generate_characters.py` on `chest_body`) gets a reveal (lid pops, teeth).
- Runtime: chest open handled in `scenes/world/modules/ChestLoot.gd`; play frames then settle on `chest_open.png` (co-op sync already sends open state — play animation on receive too). Doors: named-map doors/crypt doors.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
