# TID-397: Social strip — consolidate Chat/Emote/Ping into one compact cluster

**Goal:** GID-107
**Type:** agent
**Status:** pending
**Depends On:** TID-394

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chat, Emote, and Ping are three separate always-on co-op buttons plus a free-text input row, each individually positioned in `scenes/world/WorldScene.gd`. They are lower-frequency than movement/combat controls but currently take up as much dedicated screen space as any core action. They belong together as one compact social cluster rather than three independent buttons plus an input field.

## Research Notes

Exact current locations in `scenes/world/WorldScene.gd`:
- `_emote_btn` — `_ensure_social_buttons()` ~4583, text ":)", opens the emote wheel via `_toggle_emote_wheel()`, positioned `Vector2(vp.x - vh*0.09, vh*0.87)`.
- `_ping_btn` — `_ensure_social_buttons()` ~4592, text "Ping", `toggle_mode = true`, toggles `_ping_mode_active`, positioned `Vector2(vp.x - vh*0.20, vh*0.87)`.
- `_chat_toggle_btn` — chat block ~4950, text "Chat", opens `_show_chat_quick_panel()` (quick-chat presets), positioned `Vector2(vp.x - vh*0.31, vh*0.87)` — note this already sits on the same row (`vh*0.87`) as Emote and Ping, so at least these three are already loosely grouped; the goal is to make that grouping deliberate and registry-backed rather than three buttons that happen to share a y-coordinate.
- `_chat_input` (LineEdit) + `_chat_send_btn` — chat block ~4967-4980, positioned at `vh*0.93`, visible by default on desktop; the inline comment says mobile users reveal it via the Chat HUD button. `_chat_log_panel` / `_chat_log_vbox` / `_chat_quick_panel` are the related always-in-tree-while-open panels.
- `_chat_log_panel` is described as "always visible while in co-op" in its declaration comment (~177) — confirm during Plan whether that stays true or moves behind a toggle as part of the consolidation.

## Plan

_Written during Plan phase._ Suggested shape (confirm/adjust during Plan):
- Register a "social strip" zone via TID-394's registry (bottom-right, where Emote/Ping/Chat already loosely cluster today) containing compact icon-style buttons for Chat, Emote, and Ping.
- Keep existing sub-panel behavior (emote wheel, chat quick-panel, free-text input + send) unchanged — only the three trigger buttons and their positioning need to move onto the registry.
- Preserve the existing desktop Enter-key shortcut for chat and CLAUDE.md's mobile/desktop parity rule — every one of these three actions must remain reachable by tap on Android.
- If `_chat_log_panel` stays always-visible, make sure the compact strip's placement doesn't overlap it; if you decide to make it toggle-visible instead, note that as a deliberate behavior change in Changes Made.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_Leave the full `docs/agent/ui-and-scene-management.md` rewrite to TID-398. Note the final social strip layout in this section for TID-398's reference.
