# TID-033: HUD pickup notification + achievement milestone tracking + doc updates

**Goal:** GID-013
**Type:** agent
**Status:** pending
**Depends On:** TID-028, TID-029

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When a scroll is collected, the player should see a brief HUD toast confirming what they found. When all scrolls are collected, `GameBus.all_scrolls_collected` is emitted as an achievement hook. This task also writes all agent documentation updates for the feature.

## Research Notes

**HUD notification — existing pattern:**
`GameBus.hud_message_requested(text: String)` is the standard channel for world-layer text pop-ups. `WorldScene` listens to it and shows `_dialogue_label` for `DIALOGUE_DURATION` seconds (4 seconds, from TID-026 research).

However, scroll pickup toast should NOT use `hud_message_requested` — that label sits at `y = vp.y * 0.78` and is used for NPC dialogue. Using it for a toast would overlap with NPC lines.

**Use the tip label instead** (`_tip_label` added in TID-026):
- The tip label (`_tip_label`, yellow, at `y = vp.y * 0.14`) is appropriate for "Lore scroll found: [title]"
- WorldScene currently calls `_show_tip(text)` from `_check_interactions()`
- Add a GameBus signal `scroll_pickup_display(text: String)` that WorldScene listens to and routes to `_show_tip`

OR — simpler, since `StoryScroll.interact()` calls `GameBus.story_scroll_collected.emit(scroll_id)`:
- `WorldScene._ready()` connects `GameBus.story_scroll_collected.connect(_on_scroll_collected)`
- `_on_scroll_collected(scroll_id)` looks up `ScrollRegistry.get_scroll(scroll_id).title` and calls `_show_tip("Lore scroll found: " + title)`

This avoids a new signal and keeps the logic in WorldScene where the tip label lives.

**Achievement milestone:**
In `WorldScene._on_scroll_collected(scroll_id)` (or in `StoryScroll.interact()`), after marking collected:
```gdscript
if SaveManager.collected_scrolls.size() >= ScrollRegistry.SCROLL_COUNT:
    GameBus.all_scrolls_collected.emit()
```

`GameBus.all_scrolls_collected` was declared in TID-028. No listener is required for v1 — the signal is the hook; a future achievements system can connect to it.

**Tip label availability:**
The `_tip_label` was added to `WorldScene` in TID-026 (GID-012). Read `WorldScene.gd` during Plan phase to confirm the `_show_tip(text)` function signature and that it's accessible from `_on_scroll_collected`.

**Documentation updates required:**

1. **Create `docs/agent/story-narration-scrolls.md`** — new agent doc covering:
   - Key Features
   - How It Works (ScrollRegistry, SaveManager field, StoryScroll entity, audio channel, journal, achievement)
   - Integrations table
   - Asset Requirements (audio files, scroll entity scene, journal scene)

2. **Update `docs/agent/story-implementation.md`** — add a row to the Integrations table for ScrollRegistry and StoryScroll; note that `collected_scrolls` is a new SaveManager field.

3. **Update `docs/agent/save-system.md`** — add `collected_scrolls: Array[String]` to the Field Descriptions table; note v5 migration.

4. **Update `docs/agent/signals-and-constants.md`** — add `story_scroll_collected`, `all_scrolls_collected`, `journal_requested`, `dialogue_state_changed` to the Signal Reference Table.

5. **Update `docs/agent/ui-and-scene-management.md`** — add Journal overlay section (J key, JournalScene lifecycle).

**AudioManager doc** (`docs/agent/audio-manager.md` if it exists — check during Plan):
- Document the `_narration_player` channel and `play_narration` / `stop_narration` / `set_narration_suppressed` API.

**CLAUDE.md** — no changes needed; existing sections (UI sizing, Variant inference, class_name, UID sidecars) all apply.

**Commit message:** `TID-033: HUD scroll pickup toast, all_scrolls_collected achievement signal, agent doc updates`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
