# BID-068: Unreferenced art files still shipped

**Category:** design-inconsistency
**Discovered During:** GID-143 / TID-607

## Description

The pre-GID-143 undead sprites (`enemy_undead*.png`) and the old hand-made `wizard_walk_*_pixel.png` frames are no longer referenced but still ship in the APK and in CREDITS.

## Evidence

`docs/agent/art-sprites.md` → "Third-party art inventory & generation roadmap", batch B0.

## Suggested Resolution

Delete them (and their .import), update CREDITS.md per-slot index.
