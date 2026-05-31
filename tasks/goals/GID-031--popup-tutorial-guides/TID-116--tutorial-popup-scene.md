# TID-116: TutorialPopup Scene — Reusable Overlay

**Goal:** GID-031
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

We need a polished modal overlay that renders a tutorial guide entry (title + body text) with a "Got it" button. It must be reusable — any system emits a signal with a popup ID and the overlay shows the right content. It must also work on mobile (tap button) and desktop (Enter/Escape dismiss).

## Research Notes

**Existing pattern to follow:**
- `scenes/ui/SettingsScene.gd` — dynamically-built overlay with dark backdrop `ColorRect` + `PanelContainer` + close button. Emits `closed` signal.
- `BattleScene` first-battle overlay (inside `scenes/battle/BattleScene.gd`) — `ColorRect` + `Label` + `Button`, auto-dismiss after 8s.
- Viewport-relative sizing: always use `get_viewport().get_visible_rect().size` for `vh`/`vw`. Never fixed pixels.

**GameBus signal to add:**
```gdscript
signal tutorial_popup_requested(popup_id: String)
```

**SceneManager integration:**
- `SceneManager.gd` connects to `GameBus.tutorial_popup_requested` in `_ready()`.
- On signal: checks if `SaveManager.has_story_flag("seen_tutorial_" + popup_id)` — if already seen, skip.
- If not seen: sets the flag immediately, then instantiates `TutorialPopup`, adds it to `get_tree().root`, connects `closed` signal to remove it.

**Scene location:** `scenes/ui/TutorialPopup.gd` (code-only, no .tscn needed — built entirely in `_ready()`).

**Layout:**
- Full-screen dark `ColorRect` backdrop (alpha ~0.65), mouse_filter STOP
- Centered `PanelContainer` ~70% vw × 50% vh
- Inside: `VBoxContainer` with title `Label` (bold, ~3.5% vh), body `Label` (autowrap, ~2.2% vh), spacer, "Got it" `Button` (~5.5% vh tall, ~18% vh wide, centered)
- Dismiss: button press OR `ui_cancel` / `ui_accept` in `_unhandled_input`
- On dismiss: emits `closed` signal (SceneManager removes the node)

**Do NOT use .tscn** — keep it pure GDScript to avoid needing .uid sidecar for a purely programmatic scene.

## Plan

1. Add `tutorial_popup_requested(popup_id: String)` signal to `GameBus.gd`.
2. Create `scenes/ui/TutorialPopup.gd` — pure-code Control with backdrop, panel, title/body labels, "Got it" button, keyboard dismiss.
3. Create stub `game_logic/TutorialRegistry.gd` (content filled in TID-117).
4. In `SceneManager.gd`: preload both scripts, connect signal in `_ready()`, implement `_on_tutorial_popup_requested()` which checks the seen flag, looks up the registry, sets the flag, and adds the popup to root.

## Changes Made

- `autoloads/GameBus.gd`: added `signal tutorial_popup_requested(popup_id: String)`
- `scenes/ui/TutorialPopup.gd`: new file — reusable modal overlay (backdrop + panel + title + body + "Got it" button); emits `closed`; dismisses on button press or ui_cancel/ui_accept
- `game_logic/TutorialRegistry.gd`: new stub file with empty `_DATA` dict and `get_entry()` static func (populated in TID-117)
- `autoloads/SceneManager.gd`: preloads `TutorialPopup` and `TutorialRegistry`; connects `GameBus.tutorial_popup_requested` in `_ready()`; implements `_on_tutorial_popup_requested()` with flag dedup, registry lookup, and popup lifecycle

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md` with TutorialPopup system details.
