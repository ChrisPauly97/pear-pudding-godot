# TID-594: Visual Finish Fixes

**Goal:** GID-141
**Type:** agent
**Status:** done
**Depends On:** TID-593

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Fix the top-ranked findings from TID-593 on the first-30-minutes path. Scope is the ranked list; anything large gets a
backlog item instead.

## Research Notes

- Follow CLAUDE.md UI rules (viewport-relative sizes, `_UiUtil` factories, `UiTheme`), Sprite3D rules (depth clipping,
  `SpriteOutline.apply()` for custom materials), `.uid` sidecars for any new resource, const preloads (Android).
- Re-capture the same screenshots after fixing for a before/after pair in the task file.

## Plan

Fix TID-593 findings 1–5 (all small, code/map only); re-capture to confirm; items 6–9 stay backlog (art).

## Changes Made

- `WorldHUD.gd`: XP bar / label use the current level's span (`_level_start_xp`); Ley-Attuned chip at 11 % vh.
- `TownspersonNPC.gd`: trainer / quest-giver name tags. `SideQuests.giver_name_for()`.
- `madrian.tres`: `trainer_madrian` (79,41), `training_dummy_madrian` (82,41), `merchant_8` (42,25) off wall tiles.
- `NpcInteractions._quest_panel`: 42 % height.
- Test: `test_starter_zone.test_named_npcs_stand_on_open_ground`.
- Before → after captures: level bar "0 / 50 XP" → "0 / 200 XP"; "Shepherd" → "Hilda the Baker"; "Pilgrim" on the
  wall → "Combat Trainer" on open ground; quest panel no longer half empty.

## Documentation Updates

`starter-zone-and-training.md` "Visual finish pass".
