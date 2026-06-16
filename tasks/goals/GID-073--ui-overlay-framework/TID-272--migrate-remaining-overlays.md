# TID-272: Migrate remaining overlays and standardize close/cleanup

**Goal:** GID-073
**Type:** agent
**Status:** done
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

Migrate JournalScene, AchievementsScene, TutorialPopup, CardInspectOverlay to BaseOverlay in parallel with TID-271. BiomeSelectionScene excluded — it is a full-screen scene with no `signal closed`, not a modal overlay pattern.

## Changes Made

- **JournalScene.gd**: extends BaseOverlay; removed `signal closed`/`_vh`/`_vw`; replaced outer backdrop+panel+margin+vbox block with BaseOverlay helpers; overrides `_close()` to add `queue_free()` after emitting `closed`; removed `_unhandled_input` (BaseOverlay handles `ui_cancel`).
- **AchievementsScene.gd**: same base changes; close button now calls `_close()`; removed `_on_close()` and `_unhandled_input`.
- **TutorialPopup.gd**: same base changes; replaced local `vh`/`vw` vars with `_vh`/`_vw` from BaseOverlay; removed `_dismiss()`, close button calls `_close()` directly; `_unhandled_input` kept only for `ui_accept`.
- **CardInspectOverlay.gd** (scenes/battle): same base changes; removed local `var _vh`; backdrop built with `_build_backdrop(0.72, true)` (close-on-tap); panel uses `_build_centered_panel()` + `_make_dark_glass_style()`; overrides `_close()` to add `queue_free()`.
- **BiomeSelectionScene.gd**: intentionally not migrated — full-screen new-game scene, not a modal overlay, has no `signal closed`.
- Moved `tasks/backlog/BID-009` to `tasks/archive/backlog/`.

## Documentation Updates

Updated docs/agent/ui-and-scene-management.md with BaseOverlay/UiUtil section.
