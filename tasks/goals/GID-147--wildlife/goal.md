# GID-147: Wildlife — Ambient Critters, Cactus Worms, Imbued Stags

## Objective

User request (2026-09-28): ambient critters for immersion (rats, mice,
butterflies, bees, scorched larvae, fawns, snow rabbits, blackened adders:
level 0, no health, wander a small area); new enemies cactus worm and imbued
stag (stag carrying ley-line essence). Also: trees floated or sank on slopes.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-594 | Fix prop/tree height sampling (height field has 2 vertices per tile) | agent | done | — |
| TID-595 | Ambient critters — CritterDef, Critter entity, Critters module | agent | done | — |
| TID-596 | Cactus worm + imbued stag enemies (registry, sprites, spawns) | agent | done | — |

## Changes Made

- `TreeScatter.height_at_local` samples the height field bilinearly; trees and
  ground props use it (they indexed it as one vertex per tile, so they read the
  wrong height).
- `game_logic/world/CritterDef.gd`, `scenes/world/entities/Critter.gd`,
  `scenes/world/modules/Critters.gd` (`WorldScene.critters`).
- `EnemyRegistry` gains `cactus_worm` (desert near pool) and `imbued_stag`
  (tracking; replaces the pool type on ley lines, `InfiniteWorldGen.enemy_type_at`).
- `scripts/gen_creature_sprites.py` draws the critter and enemy sprites.
- Tests: `test_critters`, `test_creature_enemies`.
