# TID-509: Project Fonts (Nunito body, Cinzel titles)

**Goal:** GID-132
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Engine default font everywhere reads as a prototype.

## Research Notes

Theme is built in `scenes/ui/UiTheme.gd` and merged into ThemeDB default theme. Fonts via npm @fontsource (woff2, OFL). `UiUtil.make_title_label` for titles. Attribution in `CREDITS.md`.

## Plan

Fontsource OFL woff2 subsets; theme default font + TitleLabel variation; engine font fallback; ThemeDB.fallback_font set so Label3D picks it up.

## Changes Made

- New `assets/fonts/` (Nunito-Bold, Cinzel-Bold woff2 + .import, OFL licences); `CREDITS.md` Fonts section.
- `UiTheme`: `body_font`, `title_font`, `TITLE_VARIATION`, default font in `install()`.
- `UiUtil.make_title_label`, MenuScene title, TutorialPopup title use `TitleLabel`.
- Tests: font install/fallback/licence asserts in `test_ui_theme`. Visual check: menu + popup.

## Documentation Updates

ui-and-scene-management.md Fonts subsection; CLAUDE.md UI note.
