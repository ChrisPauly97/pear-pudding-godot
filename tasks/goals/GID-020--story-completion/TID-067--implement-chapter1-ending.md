# TID-067: Implement Chapter 1 Ending Scene/Trigger

**Goal:** GID-020
**Type:** agent
**Status:** superseded by GID-107/TID-400 (2026-07-02)
**Depends On:** TID-066

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Once the human has defined the victory condition (TID-066), this task implements it: the trigger in the named map, the ending presentation, the story flag, and the post-ending flow.

## Research Notes

- `autoloads/SceneManager.gd` manages all scene transitions; add a `go_to_chapter_end()` method or reuse existing overlay pattern
- `autoloads/SaveManager.gd` — set `story_flags["chapter1_complete"] = true` on trigger; call `SaveManager.save()` immediately (not batched) so the flag persists before scene change
- Narration scroll overlay approach (recommended if human chooses it): `scenes/ui/JournalScene.gd` or a new `EndingOverlay.gd` that displays text lines with a fade-in Tween, then returns to MenuScene
- Trigger: intercept the specific NPC interaction (King Eldar in blancogov_temple) in `WorldScene.gd` — after dialogue plays, check if `chapter1_complete` is NOT set; if so, trigger ending
- Alternatively, a TRIGGER map entity in blancogov_temple.tres can fire a GameBus signal that WorldScene connects to
- After ending presentation: call `SceneManager.go_to_menu()` — the existing Continue button on MenuScene will load the save correctly

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
