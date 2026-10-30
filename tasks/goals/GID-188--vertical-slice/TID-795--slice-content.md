# TID-795: Fit starter-zone content to levels 1–10, slice boss + completion screen

**Goal:** GID-188
**Type:** agent
**Status:** todo
**Depends On:** TID-794

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make the slice's world end where the slice ends: enforce `SliceRules.LEVEL_CAP` (XP stops, level-up UI says the slice is complete), keep the player in Madrian + starter camps (other stitched towns, sea/rivers, caves, rift portals hidden or blocked in slice mode), pick ~6 enemy types for levels 1–10 and one slice boss whose defeat shows a "Slice complete" screen (reuse `BattleResultUI._build_result_overlay` / narration overlay).

## Research Notes

- Camps: `StarterZone` / `StarterCamps.gd` (GID-141); zone levels `ZoneLevels`; XP `XpCurve`.
- World placement: `RealmLayout.gd` (towns), `CaveSites`, `InfiniteWorldGen` rift portals, `Coast`/`Rivers` — chunk gen is threaded: read `SliceRules` as a pure const/flag passed in, no autoload state (CLAUDE.md TerrainMath threading rule).
- Gate with `SliceRules.active()`; add new keys to the SliceRules table rather than scattered checks.

## Plan

## Changes Made

## Documentation Updates
