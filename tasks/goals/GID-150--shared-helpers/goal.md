# GID-150: Shared Helpers for Duplicated Code

## Objective

Extract copy-pasted code into common helpers without changing behaviour.

## Context

User (2026-09-30) asked to use common helpers and extract shared duplicated features. Research found three
clusters worth folding: hand-rolled emissive materials in world entities, the tile-centre formula repeated ~48
times, and the quest diamond / waypoint pin drawn separately by all three map views.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-624 | `WorldEntityBase.glow_material()` | agent | done | — |
| TID-625 | `IsoConst.tile_center()` | agent | done | — |
| TID-626 | `MapMarkers` shared map-marker drawing | agent | done | — |
| TID-627 | Loose enemy spawns, terrain and chunk lookups | agent | done | — |
| TID-628 | Battle banners, attack drags, armor | agent | done | — |
| TID-629 | UI grids, panels and small dups | agent | done | — |

## Acceptance Criteria

- [x] No behaviour change; full suite, smoke tests, gdlint, unsafe-hits clean
