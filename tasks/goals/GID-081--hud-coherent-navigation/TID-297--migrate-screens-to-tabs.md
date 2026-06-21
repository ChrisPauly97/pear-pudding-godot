# TID-297: Migrate Character/Equipment, Skills, and Journal into hub tabs

**Goal:** GID-081
**Type:** agent
**Status:** done
**Depends On:** TID-296

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-296 builds the Menu Hub shell and the embeddable-page contract, proving it with the Inventory/Deck tab. This task ports the remaining three screens — Character/Equipment, Skills, and Journal — to render as hub pages so all four are connected and cross-navigable, while preserving every existing feature.

## Research Notes

**Depends on the page contract defined in TID-296** (e.g. `build_into(container, hub)` or equivalent). Read the final TID-296 implementation before starting — the contract method name/signature is authoritative there.

**Screens to migrate (all currently extend `BaseOverlay`):**
- `scenes/ui/CharacterScene.gd` — character stats + multi-slot equipment (GID-029). Has equipment slots, item interaction. Preserve all slot logic.
- `scenes/ui/SkillTreeScene.gd` — branch skill trees, magic-type selection, point spending, hierarchy visualization (GID-030/032/033). On open it expects the `skill_tree` tutorial popup; TID-296 wires that trigger at the hub level — verify it still fires when switching to this tab, don't double-fire.
- `scenes/ui/JournalScene.gd` — itself a multi-tab screen (bestiary, scrolls, achievements, colossi per GID-045/067 etc.). It already has internal sub-tabs; make sure the hub's top-level tab bar and the Journal's own internal tabs don't visually collide — the Journal's content becomes the hub content area, its sub-tabs render inside that.

**Migration steps per screen:**
1. Remove the screen's own full-screen backdrop and standalone Close button when hosted in the hub (the hub frame owns those). Factor the screen's body-building code into the contract method so it builds into the hub's content container.
2. Replace any `_close()`/`closed` self-dismiss used for "back to world" with hub-level close (the hub keeps a single Close/back control).
3. Keep all interactive logic (equipment equip/unequip, skill point spend, journal sub-tab switching) intact.
4. Ensure each migrated page re-applies viewport-relative sizing.

**Cross-navigation:** after this task, the hub tab bar must list all four (Deck/Bag, Character, Skills, Journal) and switching between any two works without touching the world scene.

**Watch for shared/standalone callers:** grep for any place that instantiates these scenes directly (besides SceneManager) — e.g. CharacterScene or JournalScene opened from a non-world context. If found, route them through `SceneManager.open_menu_hub(tab)` or preserve a standalone path. Likely all four are only opened via the `GameBus` signals already redirected in TID-296.

**Constraints:** viewport-relative sizing, Android-safe `preload()`, no new system coupling (CLAUDE.md).

## Plan

_Written during Plan phase._

## Changes Made

**Modified:**
- `scenes/ui/CharacterScene.gd`: Added `hub_mode: bool = false`. `_build_ui()` branches on hub_mode — hub path builds MarginContainer (FULL_RECT) + VBox into self, skips backdrop/panel and close button. `_input()` returns early in hub_mode so ui_cancel propagates to the hub.
- `scenes/ui/SkillTreeScene.gd`: Added `hub_mode: bool = false`. Both `_build_magic_choice()` and `_build_ui()` branch on hub_mode. Close button gated on `not hub_mode`. Added `_input()` override (returns in hub_mode, calls super otherwise). `_unhandled_input()` gated on hub_mode.
- `scenes/ui/JournalScene.gd`: Added `hub_mode: bool = false`. `_build_ui()` branches on hub_mode. Close button gated. Added `_input()` override. `_close()` returns early in hub_mode.
- `scenes/ui/MenuHubScene.gd`: Added preloads for CharacterScene, SkillTreeScene, JournalScene .tscn files. Updated `_load_tab_content()` to instantiate all four real scenes with `hub_mode=true` instead of placeholder labels. Skills tab emits `GameBus.tutorial_popup_requested.emit("skill_tree")` before instantiating the page.

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md`: expanded Menu Hub section to document all four migrated pages and the full page contract (hub_mode behaviour).
