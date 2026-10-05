# GID-157: Codebase Cleanup — Coordinate Helpers

## Objective

One source of truth for world↔tile conversion; fix the negative-coordinate bug in `IsoConst.world_to_tile`.

## Context

User asked to clean up the codebase. Research found 21 hand-written tile-centre formulas (CLAUDE.md forbids
them), ~17 hand-rolled `floor(x / TILE_SIZE)` conversions, a duplicate `TILE_SIZE` const in `DungeonGen`, and
`IsoConst.world_to_tile` using `int()` truncation — wrong for the overworld's negative coordinates (tap-to-move
resolved -0.5 to tile 0).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-665](TID-665--coordinate-helpers.md) | Floor `world_to_tile`, add `entity_tile`, route hand-rolled conversions through IsoConst | agent | done | — |

## Acceptance Criteria

- [x] `world_to_tile` floors; regression test for negative coords.
- [x] No `* TILE_SIZE + TILE_SIZE * 0.5` outside `IsoConst`.
- [x] Tests, gdlint, `unsafe-hits.sh`, headless import clean.
