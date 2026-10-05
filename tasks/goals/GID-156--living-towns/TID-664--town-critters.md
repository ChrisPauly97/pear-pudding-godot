# TID-664: Town Critters — Pigeons, Cats, Chickens

**Goal:** GID-156
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`Critters` picks species by biome only, so towns get forest/grassland wildlife. Towns should have their own
critters: pigeons (flock, flutter away), cats (slow, nap), chickens (peck, hop).

## Research Notes

- Data: `game_logic/world/CritterDef.gd` — `FRAMES` (2-frame textures, preloaded consts), `SPECIES` (speed,
  radius, pause, fly, hop, day_only, scale), `BIOME_CRITTERS`, `species_for(biome, day, roll)`. Add
  `TOWN_CRITTERS` + `species_for_town(day, roll)` (cats at night, pigeons/chickens day_only).
- Sprites: `scripts/gen_creature_sprites.py` generates `assets/textures/critters/<name>_0/1.png`. Add pigeon,
  cat, chicken; run headless import so `.import` files exist. Preload as consts (Android rule — never `load()`).
- Spawner: `scenes/world/modules/Critters.gd` `_try_spawn` uses `_world._current_biome`; branch on
  `_world.current_town != ""` to use the town list. `_walkable` only allows grass/hill — allow path/street tiles
  in towns (check which tile id `TownStreets` paves to) but keep walls/water excluded. Despawn critters whose
  species no longer fits when leaving/entering a town.
- Entity: `scenes/world/entities/Critter.gd` handles fly/hop/flee; pigeons = fly + short flee bursts.
- `test_magic_types`-style guard: extend existing critter test (grep `tests/` for CritterDef) so every town
  species has FRAMES and SPECIES entries.
- Update `docs/agent/visual-polish.md` or the critters section (grep docs/agent for "Critter").

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
