# TID-688: TownDecor set pieces + Madrian fountain

## Lock
Session: — | Acquired: — | Expires: —

## Context
Madrian's square (GID-165) is local 25..35 × 24..32 with the hub/spawn at (30,30). A wall-tile fountain would
be read by TownBuildings as a tower (roof), so the fountain is a set piece instead of map tiles.

## Plan
Pure `TownDecor` table (blocked tile square per piece) → TownStreets excludes those tiles, TapToMove treats
them as walls, StarterCamps renders an animated billboard on a collision cylinder. Move the shrine off it.

## Changes Made
- `tools/generate_fountain.py` → `assets/textures/props/fountain_0..3.png`.
- `game_logic/world/TownDecor.gd` (new); `TownStreets.plan(..., blocked)`; RealmLayout passes it.
- `scenes/world/modules/TapToMove.gd`: `tile_at()` lookup for A* and the tap check.
- `scenes/world/modules/StarterCamps.gd`: `_build_town_decor()`.
- `assets/maps/madrian.tres`: shrine (30,27) → (27,31).
- `tests/unit/test_town_decor.gd` (new).

## Documentation Updates
- `docs/agent/named-maps-and-dungeons.md` (set pieces), `CLAUDE.md` StarterCamps row.
