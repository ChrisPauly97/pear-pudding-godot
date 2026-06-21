# TID-289: DiagnosticsScene overlay — scrollable log viewer

**Goal:** GID-078
**Type:** agent
**Status:** done
**Depends On:** TID-288

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A full-screen overlay that reads from `AppLog`'s ring buffer and renders all entries in a colour-coded, scrollable `RichTextLabel`. Works on Android because it reads from the in-memory buffer — no file I/O. Follows the `BaseOverlay` pattern used by `SettingsScene`, `JournalScene`, etc.

## Research Notes

- Extend `res://scenes/ui/BaseOverlay.gd`. Call `super._ready()` and use `_build_backdrop`, `_build_centered_panel`, `_build_margin_vbox`, `_make_dark_glass_style()`.
- `BaseOverlay` sets `_vh` and `_vw` in `_ready()`.
- `UiUtil.make_title_label`, `make_close_button`, `make_separator` for consistent styling.
- `RichTextLabel` with `bbcode_enabled = true` lets us colour lines:
  - INFO → `[color=green]`
  - WARN → `[color=yellow]`
  - ERROR → `[color=red]`
  - Timestamp prefix in dim grey: `[color=#888888]`
- Wrap `RichTextLabel` in a `ScrollContainer` with `size_flags_vertical = SIZE_EXPAND_FILL` to fill available height.
- Auto-scroll to bottom on open: `rich_label.scroll_to_line(rich_label.get_line_count() - 1)` in `_ready()` after populating.
- "Clear" button calls `AppLog.clear()` and repopulates (or just clears the label).
- "Copy" button (optional, desktop only): `DisplayServer.clipboard_set(plain_text)`.
- File location: `scenes/ui/DiagnosticsScene.gd` (script-only, no `.tscn` needed — instantiate via `DiagnosticsScene.new()`).
- Entry format line: `[color=#888888][{ts:.1f}s][/color] [color={col}][{level}][/color] {msg}\n`
- `AppLog` is an autoload so reference it directly as `AppLog`.

## Plan

1. Create `scenes/ui/DiagnosticsScene.gd` — script-only, extends `BaseOverlay`.
2. In `_ready()`: call `super._ready()`, `_build_backdrop()`, `_build_centered_panel(vw*0.88, vh*0.82)` with dark glass style.
3. Inside a MarginContainer VBox: title label, then a `ScrollContainer` (EXPAND_FILL) containing a `RichTextLabel` with `bbcode_enabled = true`.
4. Populate in `_populate()`: iterate `AppLog.get_entries()`, format each line as `[color=#888888][{ts:.1f}s][/color] [color={col}][{level}][/color] {msg}\n` where col is green/yellow/red per level.
5. Row of buttons at the bottom: "Clear" (calls `AppLog.clear()` + `_populate()`) and "Close" (calls `_close()` inherited from BaseOverlay).
6. Call `_populate()` at the end of `_ready()` so entries are shown immediately on open.

## Changes Made

- Created `scenes/ui/DiagnosticsScene.gd`: script-only `BaseOverlay` subclass with an 88%×82% viewport-relative panel, BBCode colour-coded `RichTextLabel` in a `ScrollContainer`, and Clear/Close button row. Reads `AppLog.get_entries()` on open; re-renders after Clear is pressed.

## Documentation Updates

None in this task — agent docs for the diagnostics system are created in TID-290.
