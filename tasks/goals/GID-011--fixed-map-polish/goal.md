# GID-011: Fixed Map Polish — Path Tiles & Inn Merchants

## Objective

Bring fixed hand-crafted maps to parity with the infinite world by adding a TILE_PATH engine type (brown dirt paths between buildings) and placing MERCHANT NPCs inside inn maps.

## Context

Recent goals added two systems that the infinite world already uses but fixed maps do not:
- **GID-007** introduced the `MERCHANT x z` map directive and MerchantNPC scene — no fixed map uses it yet.
- Brown dirt paths between building doors exist conceptually (players walk between buildings) but no `TILE_PATH` tile type exists; paths are currently invisible (plain grass).

The terrain shader already uses vertex COLOR channels (R=height-blend, G=wall flag) so adding B=path flag is a clean extension with minimal surface area.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-024](TID-024--tile-path-engine.md) | Add TILE_PATH engine support | agent | pending | — |
| [TID-025](TID-025--update-fixed-maps.md) | Update fixed maps: path tiles + merchants | agent | pending | TID-024 |

## Acceptance Criteria

- [ ] `IsoConst.TILE_PATH = 3` exists and is the single source of truth
- [ ] PATH tiles render as brown packed-earth (visually distinct from grass) with no wall collision
- [ ] `madrian_inn.txt` and `maykalene_inn.txt` each contain a `MERCHANT` directive
- [ ] `madrian.txt` and `maykalene.txt` have brown path tiles (`3`) connecting building doors
- [ ] `BundledMaps.gd` updated to reflect all map changes (required for Android export)
- [ ] No existing tests broken; terrain height tests unaffected (PATH treated as TILE_GRASS for height)
