# GID-154: Proper Town Buildings

## Objective

Town houses read as buildings, not 1-high wall outlines: tall walls, roofs, doorways, windows.

## Context

Outdoor towns are authored as 100×100 named maps whose houses are rings of 1-high `TILE_WALL` tiles, stamped into
the overworld by `RealmLayout` (GID-138). The chunk renderer draws each wall tile as a 1-unit block, so houses looked
like low garden walls. User request: "generate proper buildings so they are not just 1 high walls".

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-659](TID-659--town-buildings.md) | Detect footprints, raise walls, roofs + trim, roof fade | agent | done | — |
