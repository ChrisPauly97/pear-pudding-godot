# BID-059: `scrolls`/`shrines`/`music_track` silently lost in 3 story map `.tres` files

**Category:** code-smell / content-bug
**Discovered during:** GID-021 / TID-071

## Summary

`MapData.gd` declares `scrolls: Array[Resource]`, `shrines: Array[Resource]`,
`triggers`, `regions`, `music_track`, `difficulty`, `author`, and `version`
as top-level exported fields. In the `.tres` map files, these are written as
plain `key = value` assignments — but in **3 of the 5** named story maps
(`madrian.tres`, `maykalene.tres`, `blancogov.tres`) those assignments
appear *after the last `[sub_resource]` block but before the `[resource]`
header*, with no section header of their own. Godot's `.tres` text format
attaches trailing `key = value` lines to whatever section was most recently
opened — so these values silently attach to the **last sub-resource**
(typically a `MapPuzzleShrine` or similar), which doesn't declare those
properties. Godot drops unknown properties on load with no error or
warning. The top-level `MapData` `[resource]` block then never gets these
fields set at all, and they fall back to their script defaults (empty
arrays, `""` for `music_track`).

**Verified by direct load test** (`load("res://assets/maps/<map>.tres")`,
inspect `.scrolls.size()`, `.shrines.size()`, `.music_track`):

| Map | Before fix | Scrolls authored in file | Shrines authored |
|---|---|---|---|
| `madrian` | scrolls=0, shrines=0, music="" | 1 (`scroll_15`) | 1 (`shrine_madrian_1`) |
| `maykalene` | scrolls=0, shrines=0, music="" | 1 (`scroll_9`) | 1 (`shrine_maykalene_1`) |
| `blancogov` | scrolls=0, shrines=0, music="" | 2 (`scroll_5`, `scroll_6`) | 1 (`shrine_blancogov_1`) |
| `farsyth_mansion` | *(fixed by TID-071)* | 2 | 1 |
| `blancogov_temple` | *(fixed by TID-071)* | 1 | 1 |

## Impact

Every lore scroll and puzzle shrine authored into `madrian`, `maykalene`,
and `blancogov` — story content referenced by `docs/human/story.md`'s
Chapter 2 Scrolls section and elsewhere — has **never actually spawned**
in-game. Each map's custom `music_track` (all currently
`grasslands.ogg`, likely wrong for at least some of these — worth a second
look once fixed) is also silently ignored; `WorldScene` falls back to its
own dungeon/town music override for named maps regardless, so this may be
lower-impact than the scrolls/shrines loss, but it's still dead authored
data.

## Root Cause

Whatever process generated/edited these `.tres` files (likely a
script-based writer used during original map authoring, or a manual editor
placing the map-level fields relative to the wrong preceding block) put the
`MapData`-level fields in the wrong section for these 3 files. The other 2
(`farsyth_mansion`, `blancogov_temple`) had the identical bug and were
fixed as part of TID-071 (moved the 8 dangling lines — `scrolls`, `shrines`,
`triggers`, `regions`, `music_track`, `difficulty`, `author`, `version` —
into the `[resource]` section, verified via the same load-and-inspect test).

## Suggested Fix

For each of `madrian.tres`, `maykalene.tres`, `blancogov.tres`: move the
dangling `scrolls =` / `shrines =` / `triggers =` / `regions =` /
`music_track =` / `difficulty =` / `author =` / `version =` lines (currently
sitting right before the `[resource]` header) into the `[resource]` section
itself (alongside the existing `enemies =` / `chests =` / `doors =` /
`npcs =` lines). Verify with a quick load-and-inspect script (see TID-071's
Changes Made for the exact one used) that `.scrolls.size()` /
`.shrines.size()` match the number of `MapScroll`/`MapPuzzleShrine`
sub-resources actually defined in the file, and that `music_track` is
non-empty. Also worth adding a lightweight regression test (e.g. a headless
script or GUT test that loads every `res://assets/maps/*.tres` and asserts
`scrolls.size()` / `shrines.size()` match a hand-counted expectation, or at
minimum that no named map with an authored scroll/shrine sub-resource
ends up with an empty top-level array) so this class of bug can't silently
reappear.
