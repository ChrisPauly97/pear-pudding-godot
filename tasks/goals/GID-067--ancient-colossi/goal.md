# GID-067: Ancient Colossi — Discoverable Mega-Landmarks

## Objective

Rare deterministic mega-structures (fallen colossus, obelisk ring, shattered spire) with biome-specific variants, procedurally generated names, a Journal discovery log, and one-time rewards.

## Context

Infinite procedural worlds blur together — every chunk is locally interesting but nothing is memorable. Landmarks give players places: a kneeling stone giant on the horizon worth walking toward, a name to remember it by ("The Kneeling King of the Ashen Waste"), and a permanent record of having found it. Discovery is its own reward loop, distinct from pending goals GID-043 (Treasure Maps — directed loot chases) and GID-044 (Waystones — travel utility): colossi are pure exploration landmarks with lore flavour. Everything is deterministic from world_seed, so landmarks are shared facts about a world, not random spawns.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-244 | Landmark Placement — Deterministic Rarity Roll, Biome Variants, Chunk Integration | agent | pending | — |
| TID-245 | Landmark Meshes — CPU ArrayMesh Structures | agent | pending | TID-244 |
| TID-246 | Discovery System — Name Generator, Journal Tab, Toast, Reward | agent | pending | TID-244 |

## Acceptance Criteria

- [ ] Roughly 1 in 60 chunks hosts a landmark, decided deterministically from (world_seed, cx, cz); same seed always yields the same landmarks.
- [ ] Landmark variant is biome-appropriate (at least 3 distinct variants across the 5 biomes).
- [ ] Landmark structures are tall/large enough to be visible several chunks away in the orthographic isometric view, with collision.
- [ ] Walking up to an undiscovered landmark fires a toast with its procedurally generated name, logs it in a Journal "Discoveries" section, and grants a one-time reward.
- [ ] Discovered landmark ids persist in the save; re-visits do not re-reward.
- [ ] All tests pass headless.
