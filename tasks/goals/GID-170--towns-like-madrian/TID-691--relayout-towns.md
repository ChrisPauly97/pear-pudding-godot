# TID-691: Re-lay Maykalene, Blancogov, Larik and Marsax Hold Madrian-style

## Lock
Session: — | Acquired: — | Expires: —

## Context
Madrian's philosophy (GID-165/167/168/169, `docs/agent/named-maps-and-dungeons.md`): small 5×5–9×7 houses
round a paved square, a set piece in the square, NPCs inside the building that fits their role (≥1 tile off
north/west walls, off the door line), no free-standing wall lines, a named sign at every door.

## Plan
Keep each town's overworld offset (story sites, the Madrian road and save positions stay put) and entity
ids; rewrite tiles / heights / spawn / entity tiles; shrink crops; move road ends that sat on the old crop
edge; add a centrepiece per square (new well / brazier / statue art); author sign names; follow up
SiegeDefs gates and StoryQuests objective tiles.

## Changes Made
- `assets/maps/maykalene.tres`: inn (innkeeper inside), Harbour Goods (merchant inside), archive (Martarquas
  scroll), harbourmaster (port-city NPC), 4 cottages round a square with a grand marble fountain (51,27, 5×5 tiles in a ground-level octagonal marble pool); cobbled street
  south to the Farsyth Mansion (door in its north gap, guard beside it). Crop (3,0,80,100) → (30,0,46,58).
- `assets/maps/blancogov.tres`: golden gate tower pair + two more pairs up the avenue (three tower pairs),
  Duellists' Hall (both duelists inside), Royal Library (both scrolls), The Golden Lyre (Lisette), guard house,
  townhouses, gilded statue (50,28) on the square, the temple at the avenue's end. Crop (0,2,100,98) → (28,2,46,56).
- `assets/maps/larik.tres`: ~6 houses round a village green with a well (48,48): Odd's farmhouse, the old
  neighbour's house (neighbour inside), stables, Saimtar's empty house (letter inside, 57,58).
- `assets/maps/marsax_hold.tres`: curtain wall now has a south gatehouse on the road and a west-wall breach;
  the keep (Lord Marsax inside), barracks, armoury, storehouse; courtyard brazier (50,60); raiders' effects
  scroll by the breach (33,50); war-camp door outside it (27,47). Crop → (26,30,47,49).
- `RealmLayout`: new crops; Maykalene→Blancogov road starts at world (38,106), Blancogov→Larik at (71,272).
- `TownDecor`: a piece per town; `StarterCamps._DECOR_FRAMES` well / brazier / statue;
  `tools/generate_town_pieces.py` → `assets/textures/props/{well,brazier,statue}_0..3.png`.
- `TownSigns.NAMES`: every building in all four towns.
- `SiegeDefs.TOWN_GATES`: Maykalene north road, Blancogov golden gate, Marsax breach (old ones pointed at
  empty corners). `StoryQuests`: Blancogov gate guard (48,9), Larik letter (57,58), Marsax scroll (33,50),
  war-camp door (27,47).
- Tests: Larik / Marsax spawn, Blancogov objective tile; sign-name and set-piece tests now cover every town;
  tower buildings carry no trim (roof only).

## Documentation Updates
- `docs/agent/named-maps-and-dungeons.md`: per-town layout notes; `CLAUDE.md` StarterCamps row.
