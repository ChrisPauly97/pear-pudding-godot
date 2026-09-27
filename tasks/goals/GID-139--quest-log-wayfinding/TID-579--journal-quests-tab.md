# TID-579: Journal Quests Tab & Quest-Updated Toasts

**Goal:** GID-139
**Type:** agent
**Status:** pending
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

## Changes Made

## Documentation Updates
