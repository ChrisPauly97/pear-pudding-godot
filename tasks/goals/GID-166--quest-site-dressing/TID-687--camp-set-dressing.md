# TID-687: Camp set dressing

## Lock
Session: — | Acquired: — | Expires: —

## Context
Nine starter camps (`StarterZone.CAMPS`) had only enemies; names like "The Old Orchard", "North Barrow",
"South Road Wreck" had nothing in the world to match. The graveyard (TID-605) already showed the pattern:
data in StarterZone, billboards spawned once by `StarterCamps._build_scenery()`.

## Plan
1. Generate pixel-art props (`tools/generate_camp_props.py`, legend-prop style).
2. `CampDressing` data module: per-camp layouts (orchard grid generated) + texture lookup.
3. Render in StarterCamps; make each camp a reserved clearing via RealmLayout's reserved distance.
4. Tests: sprites exist, orchard trees, off member slots, clearing is flat unpaved grass.

## Changes Made
- `tools/generate_camp_props.py` → 21 `assets/textures/props/camp_*.png` (+ .import).
- `game_logic/world/CampDressing.gd` (new): `LAYOUTS`, `props_for`, `all_props`, `texture`.
- `game_logic/world/StarterZone.gd`: `CAMP_CLEAR_RADIUS`, `CAMP_SITE_PAD`, `camp_site_distance`,
  `camp_distance_in`, `camp_in_rect`, `camps_near` (kept out of RealmLayout, which sits at the 500-line cap).
- `game_logic/world/RealmLayout.gd`: camps join `reserved_distance`, `chunk_touches_realm`, `stamp_context` /
  `stamp_tile_in` (equivalence test still passes).
- `scenes/world/modules/StarterCamps.gd`: `_build_camp_dressing()`.
- `tests/unit/test_camp_dressing.gd` (new).

## Documentation Updates
- `docs/agent/starter-zone-and-training.md`: camp set dressing section. `CLAUDE.md`: StarterCamps row.
