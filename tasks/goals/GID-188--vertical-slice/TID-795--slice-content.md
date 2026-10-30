# TID-795: Fit starter-zone content to levels 1–10, slice boss + completion screen

**Goal:** GID-188
**Type:** agent
**Status:** done
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

User decision (2026-10-30): **no XP compression** — real pacing, levels 1–10 ≈ 4.5 h, slice ends on the Barrow
King. Because levels 6–10 need the Chapter 1 road camps (wolf_hollow … scout_ridge, L5–10, by Maykalene), there is
**no hard region edge**; the slice is bounded by level, ladder and quests instead. Level cap in `add_xp`; out-of-slice
quests filtered in `SideQuests.can_offer`; Barrow King wakes after `old_bones` in the slice; completion via the
chapter-ending narration overlay.

## Changes Made

- `SliceRules`: `BOSS_ENEMY_TYPE`, `BOSS_QUEST`, `COMPLETE_FLAG` / `TITLE` / `PAGES`, `boss_quest()`,
  `capped_xp()`, `allows_quest()` (min level ≤ cap, every `learn` target on the slice ladder, no `rift_tier`).
- `SaveManager.add_xp`: XP clamps at `XpCurve.xp_to_reach(LEVEL_CAP)` in the slice.
- `SideQuests.can_offer`: skips out-of-slice quests (Sealed Crypt, bounties, night hunts, rifts, L>10).
- `StarterZone.barrow_king_awake`: slice requires `old_bones` (Dig) instead of `sealed_crypt` (Phase).
- `BattleVictory`: beating the Barrow King in the slice shows "Demo Complete" (3 pages, last one points to
  Settings > Full Game) and sets `slice_complete` on close.
- Tests: 4 more in `test_slice_rules.gd` (cap, quest filter, every slice quest finishable, boss). Suite 3647 pass.
- Not done (by decision): region edge, other towns/caves stay reachable.

## Documentation Updates

- `docs/agent/vertical-slice.md`: level cap, quests, boss + completion rows.
