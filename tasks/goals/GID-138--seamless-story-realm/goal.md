# GID-138: Seamless Story Realm

## Objective

Fix the broken story waypoint chain and stitch the outdoor story towns into the
overworld so the player walks from town to town with no loading screens.

## Context

Raised by the user (2026-09-27): after "Speak to Maiteln" the next waypoint
("Leave Madrian") points at empty grass (madrian 50,50), not a door. Every town
is a 100×100 map but only a fraction is used (Madrian rows 8–44, Larik ~26×22),
and moving between towns always goes door → transition. User chose: stamp the
towns into the infinite overworld (`main`) at fixed coordinates joined by roads;
interiors (temple, mansion, home, guildhall) stay door-entered.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-566 | Fix Story Waypoint Chain | agent | done | — |
| TID-567 | RealmLayout — Town Placement & Roads | agent | done | — |
| TID-568 | Stamp Towns & Roads into Chunk Generation | agent | done | TID-567 |
| TID-569 | Town Entities in the Overworld | agent | done | TID-568 |
| TID-570 | Region Awareness Replaces Map-Name Checks | agent | done | TID-569 |
| TID-571 | Entry Points & Save Migration | agent | done | TID-570 |
| TID-572 | Objectives on the Realm | agent | done | TID-571 |
| TID-573 | Docs & Human Story Note | agent | pending | TID-572 |

## Acceptance Criteria

- [ ] Every story objective with a place points at a reachable, meaningful tile
- [ ] Madrian, Maykalene, Blancogov, Larik, Marsax Hold exist in the overworld, joined by roads
- [ ] Walking between towns needs no door and no transition
- [ ] Interiors still enter/exit by door, returning to the overworld at the door
- [ ] Old saves inside a stitched town load at the translated overworld position
- [ ] Tests, gdlint, unsafe-hits, smoke tests clean
