# TID-267: Extract DungeonSessionUI and WorldHUD

**Goal:** GID-072
**Type:** agent
**Status:** done
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

1. Create `scenes/world/DungeonSessionUI.gd` with `setup()`, hero HP accessors, and the three dungeon overlay panels + `apply_event_outcome()`.
2. Create `scenes/world/WorldHUD.gd` with `setup()`, all nav/cantrip buttons, dialogue/tip/coord/XP/ley/compass/mount/bounty nodes.
3. Remove corresponding code from WorldScene.gd and wire through the two new components.

## Changes Made

- Created `scenes/world/DungeonSessionUI.gd` + `.uid` — extracts `_show_rest_site_panel`, `_show_cull_panel`, `_show_event_panel`, `_apply_event_outcome`, and `_dungeon_hero_hp` from WorldScene.
- Created `scenes/world/WorldHUD.gd` + `.uid` — extracts all dynamically-created HUD nodes, dialogue/tip display, bounty tracker, mount button, compass, ley indicator, XP bar from WorldScene.
- Removed from WorldScene: `_dungeon_hero_hp`, all dungeon panel functions, `_update_mount_btn`, `_on_mount_state_changed`, bounty tracker functions, `_show_dialogue`/`_show_tip` implementations, XP bar creation, ley indicator, compass, all nav/cantrip button creation, signal connections moved to WorldHUD.
- WorldScene `_handle_interact()` now delegates to `_dungeon_session_ui.show_rest_site_panel()` / `show_event_panel()`.
- WorldScene `_show_stable_panel()` delegates mount button refresh to `_world_hud.update_mount_btn()`.
- WorldScene reduced from ~3245 lines to ~2681 lines.

## Documentation Updates

None required — `docs/agent/ui-and-scene-management.md` already describes HUD and dungeon UI components.
