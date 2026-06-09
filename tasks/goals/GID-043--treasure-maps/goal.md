# GID-043: Treasure Maps & Buried Caches

## Objective

Torn map fragments drop from chests; assembling a full map reveals a seeded dig site in the infinite world where a DigSpot entity yields a one-time treasure cache.

## Context

Chests currently give cards/coins directly. Fragments that assemble into a treasure map pointing at a deterministic dig site (derived from the world seed) turn loot into a multi-step chase across the infinite world, and give duels (GID-037) and world events (GID-039) another reward to hand out later.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-164 | Map-fragment item model, chest drop source, save fields | agent | pending | — |
| TID-165 | Seeded dig-site placement + DigSpot world entity with interaction | agent | pending | TID-164 |
| TID-166 | Map view overlay dig-site marker + fragment display in journal | agent | pending | TID-165 |

## Acceptance Criteria

- [ ] Chests have a chance to drop a map fragment; fragment count persists in SaveManager with migration; collecting 3 fragments consumes them and assembles a treasure map
- [ ] Each assembled map deterministically derives a dig-site tile from the world seed + a per-save treasure counter, placed 200–400 tiles from world origin on a walkable tile
- [ ] A DigSpot entity spawns at the site when its chunk loads; interacting digs up a cache (coins + a rare-or-better card) exactly once, then the map is marked complete
- [ ] MapViewOverlay shows a marker for the active dig site; the journal (or inventory) shows fragment count and active map state
- [ ] Mobile parity: dig interaction works via the existing touch interact flow
- [ ] All tests pass headless
