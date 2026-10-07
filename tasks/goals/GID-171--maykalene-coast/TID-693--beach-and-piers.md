# TID-693: Beach and piers

## Lock
Session: — | Acquired: — | Expires: —

## Context
User: "Beach and pier" after TID-692. The wild coast went straight from grass to water, and the
T-pier was a bare deck.

## Plan
Beach = a band of land along the shore whose reserved distance is 0, so `stamp_tile_in` paves it
(path tiles draw as sand) with no RealmLayout change. Pier railings on water-facing deck edges, pier
lamps through the street-lamp list (NightLights glow), a second jetty off the beach, beach clutter art.

## Changes Made
- `Coast`: `BEACH_WIDTH`/`BEACH_WOBBLE`, `beach_width`, `is_beach`; `reserved_distance` 0 on the beach;
  `SHORE_WATER` 0.24 → 0.3 (water meets the sand, no green strip); fishing jetty in `PIERS`, `PIER_LAMPS`,
  a rowboat at the jetty, `BEACHED_BOAT`; `touches()` grows by the beach; `depth()` early-out at `FAR`
  (16 tiles) so the beach and blend margin always see the exact shore. `QUAY_END_X` removed.
- `RealmLayout.street_lamps_world`: appends `Coast.PIER_LAMPS` (loop compacted, still under 500 lines).
- `WaterMath.edge_prop_ok`: no reeds or lily pads on the sea coast at all.
- `Coastline`: `_build_railings` (top + mid rail, balusters) on every deck edge facing water;
  `_build_beach` (shells / starfish / driftwood on ~7% of beach tiles west of x 130, beached rowboat).
- Art: `tools/generate_boats.py` → `beach_shell/starfish/driftwood.png`, `boat_beached.png`.
- `test_coast`: beach is sand between sea and grass, beached boat on sand, jetty runs beach → deep
  water; pier lamps stand on piers and are street lamps.

- Follow-up ("open the ends of the fences, so the boats can actually dock"): `Coast.rail_open` leaves
  every pier's far ends (short sides) open plus a gangway beside each boat with a `berth` reach; boats
  re-moored against the openings (cog alongside the T-head, rowboats at both T-head ends, two
  gangways on the main pier, one at the jetty end). `test_boats_dock_at_open_rails`.

## Documentation Updates
- `docs/agent/world-generation.md` (beach, railings, lamps, jetty).
