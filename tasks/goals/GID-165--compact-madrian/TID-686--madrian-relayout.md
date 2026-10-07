# TID-686: Re-lay Madrian

## Lock
Session: — | Acquired: — | Expires: —

## Context
User: "the town is still too big … needs a better layout and smaller buildings, so every NPC isn't just on
the random wall." Old Madrian: crop (4,4,91,56), houses 9×7–13×11 in the west, a 1-tile fence row across
z=44 with ~12 NPCs strung along z 36–42 beside it.

## Plan
Keep the 100×100 local coordinate system and the overworld offset (so camps, graveyard, crypt, Barrow King
and story sites keep their tiles); rewrite tiles/heights and NPC positions; shrink the crop; follow-up the
hard-coded local tiles (StoryQuests, SiegeDefs, road start, tests).

## Changes Made
- `assets/maps/madrian.tres`: new tiles/heights — master's house 9×7, inn 9×7, merchant/smithy 6×5,
  chandler/bakery/herbalist/cottage 5×5, chapel 7×6, stable 6×5, crypt kept; paved square 25..35×24..32;
  spawn (30,30). NPCs moved to their buildings (inn folk inside the inn, Garrick at its door, Maiteln,
  shrine and bounty board on the square, trainer/dummy/duelist in a yard, rift warden by the Spire door,
  Old Tam by the south road). Ids unchanged.
- `RealmLayout`: crop → (6,6,49,52); Madrian→Maykalene road starts at local (50,57).
- `SiegeDefs`: Madrian gate → local (50,56).
- `StoryQuests`: Hilda (43,30), Maiteln (32,29); "fence" wording in StoryQuests/SideQuests.
- Tests: updated Madrian-local tiles in test_realm_layout / test_objective_tracker / test_quest_log.

## Documentation Updates
- `docs/agent/named-maps-and-dungeons.md`: spawn tile + Madrian layout note.
