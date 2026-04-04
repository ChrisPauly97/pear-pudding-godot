# BID-003: maykalene.txt DOOR+SCROLL lines were concatenated

**Category:** code-smell
**Discovered During:** GID-017 / TID-047

## Description

The last substantive line of `assets/maps/maykalene.txt` was missing a newline, causing
the `DOOR` and `SCROLL` directives to be concatenated into one line:

```
DOOR 50 0 __exit__ maykalene_exit FLAG:chapter1_warned_farsythSCROLL 52 55 scroll_martarquas_first_war
```

The WorldMap.gd parser splits on spaces and parsed `FLAG:chapter1_warned_farsythSCROLL`
as the flag key for the door, silently discarding the scroll entity `scroll_martarquas_first_war`.
This meant the scroll at (52, 55) was never spawned in Maykalene.

## Evidence

- `assets/maps/maykalene.txt` — final line before the fix
- `game_logic/world/WorldMap.load_from_string()` — DOOR parser stops at parts[5]

## Suggested Resolution

**Fixed in TID-047**: The line was split into two correct lines:
```
DOOR 50 0 __exit__ maykalene_exit FLAG:chapter1_warned_farsyth
SCROLL 52 55 scroll_martarquas_first_war
```

The `.tres` converter (`scripts/convert_maps.py`) and `maykalene.tres` both reflect the
correct data. The `.txt` file was also corrected so `bundle_maps.py` would produce correct
output if re-run before removal in TID-052.

**Secondary finding**: Map files are allowed to have fewer than 100 tile rows (some have 95-97).
The omitted trailing rows are implicitly all-grass. The WorldMap.gd parser reads HEIGHTS/entity
lines as tile rows for the missing rows, setting random garbage values. This is benign only
because those tiles are never reached in normal gameplay, but it indicates the `.txt` format
has no row-count validation. The `.tres` format stores a full flat PackedInt32Array so this
ambiguity is eliminated.
