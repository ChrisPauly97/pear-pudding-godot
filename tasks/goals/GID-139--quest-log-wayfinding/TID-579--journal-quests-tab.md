# TID-579: Journal Quests Tab & Quest-Updated Toasts

**Goal:** GID-139
**Type:** agent
**Status:** done
**Depends On:** TID-577

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Journal gets a Quests tab (active quests, Track button, story so far by chapter). A HUD toast fires when the story step changes.

## Research Notes

- `scenes/ui/JournalScene.gd` tab pattern (`_on_tab_selected`, `_scroll_list`, `_title_label`, `_lore_label`, `_replay_btn`).
- Toast: `GameBus.hud_message_requested`; story change hook `WorldScene._on_story_flag_set_for_cast`.

## Plan

Journal gets a default Quests tab (active quests coloured by kind, ★ tracked, Story so far by chapter) with a Track button; WorldScene shows a 'New objective' tip when the story step changes (deferred to re-attach after a battle).

## Changes Made

- `JournalScene`: Quests tab (default), `_populate_quest_list`, `_on_quest_selected` (giver, summary, progress), `_on_story_step_selected`, `_track_btn` → `SaveManager.set_tracked_quest`.
- WorldScene: `_announce_story_step()` on story flag set and `_on_reattached`, via the tip line so the NPC's dialogue line isn't overwritten; baseline set on map load.
- Tests: `tests/unit/test_journal_quests.gd`.

## Documentation Updates

Covered by TID-580.
