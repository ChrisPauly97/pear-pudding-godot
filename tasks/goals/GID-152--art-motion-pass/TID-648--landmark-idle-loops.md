# TID-648: Landmark idle loops

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Waystone, mana well, blight heart and puzzle shrine are static PNGs (only NightLights glow). Part of GID-152 (art motion pass).

## Research Notes

- Draw 4-frame loops in `tools/generate_sprites.py` (rune pulse on active waystone, swirl in mana well, heartbeat for blight heart, glyph shimmer on shrine) → `<name>_anim_1..4.png`.
- Entities set up via `SpriteRegistry.setup_sprite`; switch to AnimatedSprite3D with frames (preload consts) at ~4-6 fps. Dormant waystone stays static.
- Files: find spawners in `scenes/world/modules/NamedMapProps.gd` (waystones, shrines), mana wells (ley lines, `docs/agent/ley-lines.md`), `BlightHeart` entity.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
