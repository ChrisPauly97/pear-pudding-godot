# GID-021: Enemy & Boss Variety

## Objective

Add 6 new enemy types (2 per biome) and 2 boss encounters using the existing EnemyData framework, and wire them into biome spawn tables.

## Context

Only 4 enemy types exist (all "undead" variants) and all biomes spawn the same enemies. There are no bosses. This makes exploration feel homogeneous — every fight is the same regardless of where the player is. Bosses are needed to mark story chapter climaxes.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-068 | Human: author new enemy decks and drop pools | human-action | pending | — |
| TID-069 | Create 6 new enemy .tres files | agent | pending | TID-068 |
| TID-070 | Boss encounter framework | agent | done | — |
| TID-071 | Add 2 boss encounters to named maps | agent | pending | TID-068, TID-070 |
| TID-072 | Update biome spawn tables | agent | pending | TID-069 |

## Acceptance Criteria

- [ ] 6 new enemy .tres files exist with distinct decks and drop pools
- [ ] EnemyData supports a boss flag with appropriate battle presentation differences
- [ ] 2 boss encounters are placed in named maps with correct trigger conditions
- [ ] Each biome spawns at least 2 distinct enemy types in the infinite world
- [ ] All tests pass headless
