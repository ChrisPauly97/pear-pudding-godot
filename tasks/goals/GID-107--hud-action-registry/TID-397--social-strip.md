# TID-397: Social strip — consolidate Chat/Emote/Ping into one compact cluster

**Goal:** GID-107
**Type:** agent
**Status:** done
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

- `ZONE_SOCIAL` (already anchored bottom-right by TID-394, `HBoxContainer`) becomes
  the compact strip. Emote and Chat register via `register_action` (simple `.pressed`
  callbacks: `_toggle_emote_wheel`, `_toggle_chat_quick_panel`). Ping is built directly
  and parented via `get_zone_container(ZONE_SOCIAL)` — same reasoning as the Ranked
  toggle in TID-396: it needs `.toggled` (toggle_mode), not a plain `.pressed`.
- `_chat_input`/`_chat_send_btn` (free-text row at `vh*0.93`) and `_chat_log_panel`
  (left side, `vp.x*0.012, vh*0.16`) are untouched — the task's plan explicitly scopes
  this to the three trigger buttons; neither of these two overlaps the social strip's
  new position (bottom-right) so there's no correctness reason to move them, and
  moving them would be unreviewed scope creep beyond "one compact cluster of
  buttons."
- **`_chat_log_panel` visibility decision:** kept always-visible while co-op is active
  (no behavior change) — it doesn't compete for space with the social strip (opposite
  side of the screen), so there's no clutter motivation to make it toggle-only, and
  doing so would be a user-facing behavior change outside this task's placement-only
  scope.
- Enter-key chat shortcut and Android tap parity for all three buttons are preserved
  automatically — none of the underlying handlers (`_toggle_emote_wheel`,
  `_toggle_chat_quick_panel`, the ping toggle) changed, only their container parent.

## Changes Made

- `scenes/world/WorldScene.gd`:
  - `_ensure_social_buttons()`: "emote" registered via `register_action` into
    `WorldHUD.ZONE_SOCIAL`; `_ping_btn` built directly and parented into the same
    zone via `get_zone_container()`.
  - `_ensure_chat_ui()`: "chat" (the toggle button, not the log panel or input row)
    registered via `register_action` into the same zone.
- **Minor, deliberate layout change:** registration order now renders the strip
  left-to-right as Emote, Ping, Chat (previously Chat/Ping/Emote right-to-left via
  three independent hand-picked x-offsets). Purely cosmetic — same three buttons,
  same behavior, mirrored order; not worth a special-case to preserve the old
  left-right order given the zone-stacking approach naturally follows registration
  order.

**Not run:** `godot --headless --editor --quit` — same network-policy block as
TID-394/395/396. Traced `_emote_btn`/`_ping_btn`/`_chat_toggle_btn` with `grep` across
the file to confirm no other code assumed direct `_hud` parentage, and re-checked the
parenthesis/bracket/brace balance against the pre-edit file (no new imbalance).

## Documentation Updates

For TID-398: social strip = `WorldHUD.ZONE_SOCIAL` (bottom-right `HBoxContainer`),
containing Emote, Ping, Chat in that left-to-right order. Chat's log panel and
free-text input/send row are separate, unmoved elements (left side / bottom,
respectively) — not part of the strip itself.
