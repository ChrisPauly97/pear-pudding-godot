# TID-689: Building signs

## Lock
Session: — | Acquired: — | Expires: —

## Context
Buildings are detected from wall rings (`RealmLayout.building_plan`) with door gaps; streets and set pieces
are known per town. No building names existed anywhere.

## Plan
Pure `TownSigns.signs(town)` (placement + naming) → `BuildingSigns` world module renders and pops names up
on proximity (Label3D fade, polled every 0.2 s). Tests over all towns.

## Changes Made
- `game_logic/world/TownSigns.gd` (new): `NAMES` (Madrian), `ROLE_NAMES`, `signs()`, `outward()`.
- `scenes/world/modules/BuildingSigns.gd` (new); registered + ticked in `WorldScene.gd` (4 lines).
- `tools/generate_town_sign.py` → `assets/textures/props/town_sign.png`.
- `tests/unit/test_town_signs.gd` (new).

## Documentation Updates
- `docs/agent/named-maps-and-dungeons.md` (building signs), `CLAUDE.md` module table row.
