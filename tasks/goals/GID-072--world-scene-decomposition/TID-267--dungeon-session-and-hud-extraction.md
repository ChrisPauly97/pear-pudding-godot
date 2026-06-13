# TID-267: Extract DungeonSessionUI and WorldHUD

**Goal:** GID-072
**Type:** agent
**Status:** pending
**Depends On:** TID-266

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Approximately 445 lines of UI code (dungeon event panels + HUD wiring) are embedded in WorldScene. This extraction creates focused UI components for dungeon events and world HUD, improving modularity and testability. The DungeonSessionUI and WorldHUD components will be owned by WorldScene but encapsulated for future theming or overlay framework integration.

## Research Notes

- **Dungeon session cluster:** WorldScene.gd:131–134 (state: `_dungeon_hero_hp`) and 1435–1677 — rest sites, culling, event panels (`_show_rest_site_panel`, `_show_cull_panel`, `_show_event_panel`), `_apply_event_outcome` (complex branching). Approximately 245 lines → `scenes/world/DungeonSessionUI.gd`.
- **HUD cluster:** WorldScene.gd:108–130, 313–359, 382–421, 1242–1363 — label/button creation and positioning, dialogue display, tips, scroll messages, XP bar refresh. Approximately 200 lines → `scenes/world/WorldHUD.gd`.
- **GID-073 note:** GID-073 (UI Overlay Framework, UiUtil/Theme) may land first — if so, build the panels on it.
- **Mobile parity rule (CLAUDE.md):** Any keyboard shortcut must keep its touch equivalent (minimap tap, HUD buttons). Do not ship keyboard-only features.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
