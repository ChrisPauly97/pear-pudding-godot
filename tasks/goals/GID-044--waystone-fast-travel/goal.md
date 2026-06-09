# GID-044: Waystone Fast Travel Network

## Objective

Discoverable waystones in named maps and rare infinite-world chunks that, once activated, become teleport destinations selectable from the map view overlay.

## Context

The world keeps growing (Spire entrance, shrines, towns, events) but the only way anywhere is walking. Activated waystones reward discovery and are a mobile-friendly QoL win, reusing the existing `MapViewOverlay` as the travel UI.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-167 | Waystone entity + activation flow + save tracking | agent | pending | — |
| TID-168 | Waystone placement: named-map entities + rare seeded infinite-chunk spawns | agent | pending | TID-167 |
| TID-169 | Fast travel UI in MapViewOverlay + SceneManager teleport routing | agent | pending | TID-167 |

## Acceptance Criteria

- [ ] Interacting with a dormant waystone activates it (visual change + toast/audio feedback) and records it in `SaveManager.activated_waystones` with migration
- [ ] Each named map's town has one waystone placed via the map's entity data; the infinite world spawns seeded waystones rarely (roughly 1 per ~40 chunks) on walkable tiles
- [ ] `MapViewOverlay` gains a travel list of activated waystones; selecting one teleports the player, correctly handling named-map ↔ infinite-world transitions via the `SceneManager` map stack
- [ ] Fast travel is blocked during battles and inside dungeons
- [ ] Mobile parity: activation and travel selection are fully touch-operable
- [ ] All tests pass headless
