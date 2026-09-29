# TID-604: Generated Named-NPC Sprites

**Goal:** GID-143
**Type:** agent
**Status:** done
**Depends On:** TID-603

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-065: quest givers and trainers look like random townsfolk.

## Research Notes

- Generator: one humanoid body with outfit/colour/prop parameters (apron + loaf, herbalist satchel, friar robe, old soldier with pike, chandler with candle, trainer, gravedigger with spade, rift warden robe, bounty master).
- `SpriteRegistry.townsperson_texture(seed)` → add `npc_texture_for(npc_id)` map; `TownspersonNPC` uses it when the id is known.

## Plan

`person(spec)` rig in generate_characters.py + a spec per named NPC; SpriteRegistry id → texture map; TownspersonNPC uses it.

## Changes Made

- `tools/generate_characters.py`: `HAIR`, `CLOTH`, `person()`, `NPCS` (9 specs; idle only).
- 9 `assets/textures/characters/npc_*.png` (+ imports).
- `SpriteRegistry`: preloads + `named_npc_texture()`. `TownspersonNPC._ready`: uses it.
- Test: `test_starter_zone.test_every_trainer_and_quest_giver_has_its_own_sprite`. Verified in an xvfb capture.

## Documentation Updates

`art-sprites.md` generated characters table + person rig.
