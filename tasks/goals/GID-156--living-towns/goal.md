# GID-156: Living Towns — Walking Townsfolk, Daily Schedules, Town Critters

## Objective

Stitched story towns feel inhabited: plain townsfolk stroll the streets on a daily schedule and town critters (pigeons, cats, chickens) roam.

## Context

User asked "how can I make towns feel more alive?" and picked walking townsfolk, daily schedules and town critters.
Towns already have buildings (GID-154), streets + lamps (GID-155) and night lights, but every `TownspersonNPC`
stands on one tile (breathe/blink only) and `Critters` picks species purely by biome.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-661](TID-661--town-life-logic.md) | TownLife pure logic: street routes, walker selection, clock-deterministic positions | agent | pending | — |
| [TID-662](TID-662--town-life-module.md) | TownLife world module: move townsfolk, keep interaction data in sync, pause on talk | agent | pending | TID-661 |
| [TID-663](TID-663--town-schedules.md) | Daily schedules: role slots by time of day, indoors at night, lantern guard | agent | pending | TID-662 |
| [TID-664](TID-664--town-critters.md) | Town critters: pigeon / cat / chicken sprites + town species list | agent | pending | — |

## Acceptance Criteria

- [ ] Plain townsfolk in the five stitched towns walk along `TownStreets` tiles between stops; quest-givers / story / merchant NPCs stay put.
- [ ] Walker positions are a pure function of (synced clock, seed, town plan), so co-op peers agree with no new RPCs.
- [ ] Talking to a walker works wherever they are; they stop and face the player while the dialogue is open.
- [ ] Schedules change who is out by time of day (busy day, quieter dusk, mostly indoors at night, a lantern guard patrols).
- [ ] Inside a town, critters come from a town species list (pigeon, cat, chicken) instead of the biome list.
- [ ] Mobile-safe: bounded walker count, no per-frame A* (routes precomputed).
- [ ] Tests, gdlint, `scripts/unsafe-hits.sh` and the headless import are clean; agent docs updated.
