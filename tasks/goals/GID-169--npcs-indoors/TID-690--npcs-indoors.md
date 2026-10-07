# TID-690: Move shopkeepers inside their buildings

## Lock
Session: — | Acquired: — | Expires: —

## Context
GID-165 put each Madrian shopkeeper just outside their door. Roofs fade when the player steps inside
(BuildingMesh), so indoor NPCs are seen on entering; signs (GID-168) say who is where.

## Plan
Move the NPCs to interior tiles off the door line and at least one tile from the north / west walls (a
billboard there leans into the wall and clips — found on the first screenshot). Follow-up Hilda's objective tile.

## Changes Made
- `assets/maps/madrian.tres`: merchant (37,12), blacksmith (46,12), Ivy (46,22), Hilda (46,30), Wenna (14,23),
  Brother Aldo (13,31), stable master (39,39), Garrick (27,14) in the inn (line now "a stool by the inn fire"),
  master (11,11) and the master's scroll (11,13) off the west wall.
- `StoryQuests` Hilda objective (46,30); `test_objective_tracker` expectation.

## Documentation Updates
- `docs/agent/named-maps-and-dungeons.md`: indoor shopkeepers + back-wall rule.
