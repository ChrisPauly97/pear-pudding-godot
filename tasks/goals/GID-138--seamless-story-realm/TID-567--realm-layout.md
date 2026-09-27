# TID-567: RealmLayout — Town Placement & Roads

**Goal:** GID-138
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Pure-logic table that places the cropped outdoor towns at fixed overworld tile
origins in story order and defines the roads joining them.

## Research Notes

- Stitched towns: madrian, maykalene, blancogov, larik, marsax_hold. Interiors
  (blancogov_temple, farsyth_mansion, player_home, guildhall, dungeons) stay separate.
- Used bboxes (non-grass): madrian x5–92 z8–44 (door_9 at 50,99 is the old edge exit),
  maykalene 5–80 × 6–94, blancogov 0–99 × 5–94, larik 36–62 × 38–60, marsax 25–75 × 25–75.
- Overworld = `main`/`infinite`, chunks of `IsoConst.CHUNK_SIZE` (16) tiles, spawn safe
  zone `InfiniteWorldGen.SAFE_ZONE_DIST`.
- Must be usable from worker threads (chunk gen) → static, no autoload refs.

## Plan

## Changes Made

## Documentation Updates
