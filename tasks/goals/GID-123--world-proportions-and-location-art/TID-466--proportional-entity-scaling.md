# TID-466: Proportional Entity Scaling

**Goal:** GID-123
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

`SpriteRegistry.setup_sprite()` applied a flat `CHAR_PIXEL_SIZE = 0.05` to
every character sprite, so world height tracked source pixel height. The
0x72 pack's sprites range 16–36 px: skeletons/ghouls/mimics/spectres (16 px)
rendered 0.8 units tall — half the 1.6-unit player — while raiders/duelists
(23 px) hit 1.15 and only the rival (28 px) approached player height. The
user's complaint: "the enemy sprites are small relative to my player."

## Plan

1. Add `setup_sprite_height(sprite, tex, world_height)` to `SpriteRegistry` —
   computes `pixel_size = world_height / tex_height` and delegates to
   `setup_sprite()` so the feet-at-y=0 formula stays in one place.
2. Add `enemy_world_height(etype, is_roaming_boss, is_boss)` mirroring
   `enemy_texture()`'s archetype routing, backed by `HEIGHT_*` constants
   that document the size hierarchy (player 1.4 reference).
3. Convert `EnemyNPC`, `TownspersonNPC`, `MerchantNPC` to height-based
   setup. Leave `ScoutAmbush` (deliberately small scouts), chest, and door
   at their existing sizes.

## Changes Made

- `game_logic/SpriteRegistry.gd`: `PLAYER_HEIGHT 1.4`, `HEIGHT_SMALL_UNDEAD
  1.15`, `HEIGHT_SPECTRE 1.05`, `HEIGHT_MIMIC 0.85`, `HEIGHT_SOLDIER 1.25`,
  `HEIGHT_RIVAL 1.4`, `HEIGHT_BOSS 1.9`, `HEIGHT_NPC 1.4`,
  `HEIGHT_MERCHANT 1.3`; `enemy_world_height()`; `setup_sprite_height()`.
- `scenes/world/entities/EnemyNPC.gd`: sprite scaled via
  `enemy_world_height()` (boss node scale ×1.3/×1.5 still applies on top).
- `scenes/world/entities/TownspersonNPC.gd`: `HEIGHT_NPC`.
- `scenes/world/entities/MerchantNPC.gd`: `HEIGHT_MERCHANT`.

## Documentation Updates

- `docs/agent/art-sprites.md`: new GID-123 section documenting the
  height-based scaling API and the hierarchy table.
