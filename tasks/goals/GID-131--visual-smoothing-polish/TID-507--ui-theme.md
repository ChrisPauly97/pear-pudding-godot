# TID-507: Custom UI Theme

**Goal:** GID-131
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No project theme — every panel/button is Godot's default grey box.

## Research Notes

`UiUtil` factories; `project.godot` `gui/theme/custom`. Build a Theme in code or a `.tres` (+ .uid) with rounded StyleBoxFlat panels/buttons, consistent palette.

## Plan

Theme built in code; root-Window theme failed to reach CanvasLayer children, so install() merges into ThemeDB default theme at SceneManager startup.

## Changes Made

- New `scenes/ui/UiTheme.gd` (panels, buttons, labels, fields, bars, sliders, scrollbars, tabs, separators, popups).
- `SceneManager._ready`: `_UiTheme.install()`.
- Tests: new `test_ui_theme.gd` (incl. CanvasLayer reach). Visual check: world popup + main menu.

## Documentation Updates

ui-and-scene-management.md: Project UI Theme section. CLAUDE.md UI factories note.
