# TID-272: Migrate remaining overlays and standardize close/cleanup

**Goal:** GID-073
**Type:** agent
**Status:** pending
**Depends On:** TID-270

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The smaller overlays plus the battle-side inspect overlay; finish the close/cleanup unification across all 11 scenes. This task can run in parallel with TID-271 (different files), both depend only on TID-270.

## Research Notes

**Scenes to migrate:**
- JournalScene.gd (186 lines, split-pane, two margin blocks 39–42 and 98–101, emits closed then queue_free at 185–186)
- AchievementsScene.gd (144, grid, closed signal only 139–145)
- SettingsScene.gd (134, queue_free on closed at 129 — may already be migrated as the TID-270 pilot)
- TutorialPopup.gd (queue_free at 129)
- CardInspectOverlay.gd in scenes/battle (233 lines, custom StyleBox, queue_free at 228)
- BiomeSelectionScene.gd (163, ~10 override calls)

**Inconsistent close patterns to unify per BaseOverlay convention:**
- Modal queue_free (CardInspectOverlay, TutorialPopup, SettingsScene)
- closed-signal-managed (Inventory, Shop, SkillTree, Character, Achievements)
- Both patterns (Journal)

**SceneManager coordination:**
- SceneManager (autoloads/SceneManager.gd:386–465) owns open/close for 5 of them
- Keep its contract intact (GID-074 TID-275 separately dedupes SceneManager's side; coordinate, don't conflict)
- Verify that BaseOverlay integration does not break SceneManager's scene lifecycle tracking

**Parallel execution:**
- This task can run in parallel with TID-271 (different files)
- Both depend only on TID-270

**Post-completion steps (done by task executor, not this task):**
- Move tasks/backlog/BID-009 to tasks/archive/backlog/
- Update tasks/index.md to reflect the archival

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
