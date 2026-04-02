# GID-015: Consolidate Named-Map Buildings & Map View Overlay

## Objective

Embed inn and building interiors directly into their parent named map files (no loading screens within a single town), and add an M-key full-map view overlay for named maps.

## Context

Currently `madrian_inn`, `madrian_masters_house`, and `maykalene_inn` are separate 100×100 `.txt` map files that load via DOOR entities, causing scene transitions (loading screens) when entering a building within the same town. The parent maps already have the building wall geometry baked into the tile grid — the DOORs are merely entity markers at wall gaps that trigger `SceneManager.enter_map()`. The fix is to move the sub-map entities (NPCs, MERCHANTs) into the parent map's coordinate space and delete the sub-map files.

The map view overlay gives the player a way to see the full layout of the named map they are currently in, toggled by the M key.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-039 | Embed inn/building interiors into parent named maps | agent | done | — |
| TID-040 | M-key full-map view overlay for named maps | agent | pending | — |

## Acceptance Criteria

- [ ] Walking into the madrian inn and master's house requires no loading screen — interiors are part of madrian.txt
- [ ] Walking into the maykalene inn requires no loading screen — interior is part of maykalene.txt
- [ ] `madrian_inn.txt`, `madrian_masters_house.txt`, `maykalene_inn.txt` are deleted
- [ ] All previously sub-map NPCs and MERCHANTs are accessible in the parent maps
- [ ] Pressing M while in a named map opens a full-map overlay showing the tile grid and entity positions
- [ ] Pressing M or Escape closes the overlay
- [ ] Map view is not available in infinite world mode
