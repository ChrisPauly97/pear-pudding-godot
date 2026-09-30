# TID-650: NPC idle loops

**Goal:** GID-152
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
