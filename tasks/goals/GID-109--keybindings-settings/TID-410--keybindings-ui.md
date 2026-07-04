# TID-410: Keybindings UI Section in SettingsScene

**Goal:** GID-109
**Type:** agent
**Status:** done
**Depends On:** TID-409

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Adds the visible "Keybindings" section to `SettingsScene.gd` so desktop players can see and remap all 13 keyboard actions. Hidden entirely on mobile/Android (where virtual controls handle input).

## Research Notes

**SettingsScene** (`scenes/ui/SettingsScene.gd`):
- Extends `BaseOverlay.gd`, uses `_vw`/`_vh`/`_ref` for sizing.
- `_build_ui()` adds sections into a `VBoxContainer` inside a `ScrollContainer`.
- Existing section pattern: section label (color `Color(0.75, 0.85, 1.0)`, font size `_vh * 0.03`) → rows → `_UiUtil.make_separator()`.
- Uses `_UiUtil` helpers: `make_title_label`, `make_body_label`, `make_separator`, `make_close_button`.
- Add section after the existing "Battle" section, guarded by `not (OS.has_feature("mobile") or OS.has_feature("android"))`.

**TID-409 API** (written in TID-409):
- `SceneManager.REBINDABLE_ACTIONS: Array[String]` — the ordered list of action names.
- `SceneManager.apply_keybindings()` — applies saved overrides to InputMap (also called internally at startup).
- `SceneManager.save_manager.get_setting("keybindings", {})` — the current overrides dict.
- `SceneManager.save_manager.set_setting("keybindings", dict)` — write overrides.

**Key display helper** — `OS.get_keycode_string(key)` returns a readable name (e.g. `"W"`, `"Escape"`, `"Space"`). Use `DisplayServer.keyboard_get_label_from_physical(physical_keycode)` as a fallback for physical→label mapping, or just `OS.get_keycode_string(physical_keycode)`.

**Row layout per action**:
```
[Action Name Label (expand)]  [Current Key Button]  [Change Button]
```
- "Current Key Button" is a flat Label-style button showing the key name, disabled — purely informational.
- "Change" button: clicking starts capture mode.

**Capture mode**:
- Show a small `AcceptDialog`-style overlay (or a `PanelContainer` child of the SettingsScene root) with "Press any key for [Action]… (Esc to cancel)".
- Override `_input(event)` while capturing: on `InputEventKey` with `pressed == true` and `echo == false`, if `event.physical_keycode == KEY_ESCAPE`, cancel; else save the new binding and close.
- After capture: call `set_setting` with updated dict, call `apply_keybindings()`, refresh the row labels.

**Reset to Defaults** button:
- Calls `set_setting("keybindings", {})` (empty dict = all defaults), then `apply_keybindings()`, then rebuilds the UI section.
- Place at the bottom of the Keybindings section, aligned center.

**Conflict detection** (optional but nice): if the chosen key is already bound to a different action, show a brief warning label "Already used by [other action]" but still allow the override (same behavior as most games).

**Sizing**: follow the same `_vh * 0.028` font size used in existing rows. "Change" button: `custom_minimum_size = Vector2(_vh * 0.15, _vh * 0.05)`.

## Plan

1. Add Keybindings section after Battle in `_build_ui()`, guarded by `not (OS.has_feature("mobile") or OS.has_feature("android"))`.
2. Build rows: Action Name | Current Key label | Change button.
3. Capture mode via `_unhandled_input` overlay (PanelContainer child).
4. Escape cancels; any other key saves and applies.
5. Optional conflict warning on the key label.
6. Reset to Defaults button clears overrides dict and calls `apply_keybindings()`.

## Changes Made

- `scenes/ui/SettingsScene.gd`: Added state vars (`_capture_action`, `_capture_key_lbl`, `_capture_overlay`, `_kb_vbox`). Added `_build_keybindings_section()`, `_rebuild_keybinding_rows()`, `_start_capture()`, `_show_capture_overlay()`, `_unhandled_input()`, `_cancel_capture()`, `_on_reset_keybindings()`, `_key_label()`, `_action_display_name()`, `_current_keycode()` helper methods. Desktop-only section guarded by mobile/android feature check. Conflict detection highlights key label amber with tooltip.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: Added Keybindings Settings section.
