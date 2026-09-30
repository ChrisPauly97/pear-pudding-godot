# BID-081: No water in named maps; no bridges

**Category:** content-gap
**Discovered During:** GID-152 research

## Description

Water exists only in the infinite world (`WaterMath`). Streams fade out `REALM_DRY_TILES` (4) from stitched towns and
roads, so no river ever reaches a town, and there are no bridges or fords. Named-map `.tres` have no water tile.

## Evidence

`game_logic/world/WaterMath.gd` (`REALM_DRY_TILES`, `DRY_RADIUS`), `assets/maps/*.tres`.

## Suggested Resolution

Add a water tile to the map format + terrain shader path, and a bridge prop where roads cross streams. Ask user if wanted.
