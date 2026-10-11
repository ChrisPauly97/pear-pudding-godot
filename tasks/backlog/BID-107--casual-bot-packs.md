# BID-107: A casual player loses to packs (no focus swap)

**Category:** balance
**Discovered During:** GID-187 / TID-784

## Description

The casual bot never changes its auto-attack focus. Same-level ghoul pack L3 / L4 / L5 = 50 / 25 / 12.5 % (8 fights);
with `--policy focus=1` ghoul L4 goes 23 → 100 %. The `casual` coverage section's per-cell floor is set to 10 % so it
passes; the mean is 91 %.

## Suggested Resolution

Either teach the fight to read (auto-retarget the weakest pack unit when the focused one is a wall), or soften packs
for players who don't retarget. Raise `CASUAL_CELL_MIN` back to ~40 % once fixed.
