# TID-692: Eastern sea, Maykalene waterfront

## Lock
Session: — | Acquired: — | Expires: —

## Context
Water in the overworld is `WaterMath` intensity baked into terrain UV2.y; the terrain shader draws it
(three depth bands, ripples, shoreline). Realm ground (towns, roads, glades, camps) is reserved through
`RealmLayout.reserved_distance` — flat, no ruins/landmarks/trees/random spawns.

## Plan
A pure `Coast` module (shoreline polygon, signed depth) folded into reserved distance (as a padded
glade, so the sea floor is level grass, never paved) and into WaterMath (after the structure/realm fades,
so it reaches the quay). A `Coastline` world module blocks deep water by sliding the hero back each
physics frame (works through Ghost Phase), and builds the pier, quay edge, boats and cargo.

## Changes Made
- `game_logic/world/Coast.gd` (new): SHORE polygon (world tiles, west edge = Maykalene's crop edge),
  `depth()` with a wobbly natural coast away from the quay, `is_deep` (≥ 1.5 tiles, not a pier),
  `reserved_distance`, `sea_water`, `touches[_chunk]`, `to_land`, PIERS, BOATS.
- `RealmLayout`: sea in `reserved_distance`, `stamp_tile_in`, `chunk_touches_realm`; Maykalene crop
  (30,0,50,58); Maykalene→Blancogov road now leaves the south-east corner (world 29,123). Three
  `var cached` returns compacted to stay at the 500-line lint cap.
- `WaterMath`: `intensity` = max(inland, sea); `water_at`/`wet_at` add the sea after the structure fade;
  no stream flow at sea; `edge_prop_ok` (no lily pads at sea, no reeds along the quay).
- `InfiniteWorldGen`: chunks by the sea are grasslands (only water biomes draw water). One-entry
  scroll list returned directly (line cap).
- `scenes/world/modules/Coastline.gd` (new, `coastline`): deep-water slide / wade-ashore after a
  teleport or load; plank pier + posts, dressed-stone quay kerb (one vertex-coloured mesh), bobbing cog
  and rowboats, crates/barrels on the quay. Runs its own `_process` (WorldScene line ceiling).
- `TapToMove.tile_at`: deep sea is a wall. `NocturnalSpawner`: no spectres at sea. `TreasureGen`: dig
  sites walk round their ring to land. `ChunkRenderer`: edge props filtered by `edge_prop_ok`.
- `RealmMapOverlay`: the sea drawn (clipped to the panel).
- `assets/maps/maykalene.tres`: quay (local x 75..79), lane from the square to the pier, Harbourmaster's
  door faces the water, new Fishmonger's; the port-city NPC (npc_5) stands on the quay. `TownSigns` names.
- Art: `tools/generate_boats.py` → `boat_cog.png`, `boat_rowboat.png`.
- Tests: `tests/unit/test_coast.gd` (bounds, quay meets water, story places dry, piers/boats, flat
  reserved sea water, treasure on land).

## Documentation Updates
- `docs/agent/world-generation.md` (Coast), `docs/agent/named-maps-and-dungeons.md` (Maykalene
  waterfront), `CLAUDE.md` module row.
