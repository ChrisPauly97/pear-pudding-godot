# TID-650: NPC idle loops

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Townsfolk and named NPCs are one static frame. Part of GID-152 (art motion pass).

## Research Notes

- `generate_characters.py` `person(spec)` / `NPCS` table: add 2-4 idle frames (blink, breathe, prop fidget) → `<name>_idle_1..N.png`.
- `scenes/world/entities/TownspersonNPC.gd` L24 uses `make_billboard`; `SpriteRegistry.named_npc_texture()` / `_NAMED_NPC_TEXTURES`. Add frame lookup + AnimatedSprite3D, random start frame/phase so crowds don't sync. `test_starter_zone` checks named textures exist — keep it passing.

## Plan

Blink + glance poses in `person()`; frames cropped with the idle's box; `IdleLoop` node swaps textures on a
seeded schedule for townsfolk, merchants and named NPCs (IdleLife breathe already covers breathing).

## Changes Made

- `tools/generate_characters.py`: `IDLE_BLINK` / `IDLE_GLANCE` poses, `PEOPLE`, `untrimmed` / `shared_box` /
  `idle_life_frames`; 28 new `npc_*_idle_{1,2}.png` (idle PNGs unchanged).
- New `game_logic/IdleFrames.gd`, `game_logic/IdleLoopMath.gd`, `scenes/world/entities/IdleLoop.gd`.
- `TownspersonNPC.gd`, `MerchantNPC.gd`: attach the loop.
- Fixed a doc comment my TID-645 edit had split in `SpriteRegistry.gd`.
- Test: `tests/unit/test_idle_loop.gd`.

## Documentation Updates

- `docs/agent/art-sprites.md`: "NPC idle life".
