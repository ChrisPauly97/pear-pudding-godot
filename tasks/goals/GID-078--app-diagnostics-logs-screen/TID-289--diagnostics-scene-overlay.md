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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
