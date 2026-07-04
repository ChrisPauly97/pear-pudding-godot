# GID-109: Desktop Keybindings Settings Page

## Objective

Add a desktop-only keybindings section to the Settings screen that lets players remap all 13 keyboard actions and persists their choices across sessions.

## Context

All keyboard actions are defined in `project.godot` under `[input]` but are never exposed for remapping. Desktop players have no way to change bindings from the default WASD/letter layout. The existing `SettingsScene.gd` has a scrollable panel with sections (Audio, Accessibility, Battle) that this goal extends with a fourth "Keybindings" section, shown only on non-mobile platforms.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-409 | Keybinding persistence & apply-on-load | agent | done | — |
| TID-410 | Keybindings UI section in SettingsScene | agent | done | TID-409 |

## Acceptance Criteria

- [ ] All 13 keyboard actions are listed in the Settings screen on desktop (hidden on mobile/Android)
- [ ] Clicking "Change" on a row captures the next key press and assigns it to that action
- [ ] Escape during capture cancels without changing the binding
- [ ] "Reset to Defaults" restores all actions to their project.godot defaults and clears saved overrides
- [ ] Remapped bindings persist across game restarts (saved in SaveManager.settings["keybindings"])
- [ ] Bindings are applied to InputMap at game start before the first scene loads
- [ ] Headless import passes with no parse errors
