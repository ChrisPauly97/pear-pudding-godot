# TID-171: Bestiary Tab in JournalScene with Reveal Tiers

**Goal:** GID-045
**Type:** agent
**Status:** done
**Depends On:** TID-170

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The UI layer for the bestiary. Extends `JournalScene` with a second tab for viewing enemy types in three tiers: unseen (hidden), seen (name + stats), defeated ×3 (lore revealed). Layout is viewport-relative and touch-friendly per CLAUDE.md guidelines.

## Research Notes

- **JournalScene current structure:** Exists at `scenes/ui/JournalScene.gd` (lines 1–80 read). Today it has left panel (scroll list of collected scrolls) and right panel (title + lore text + replay button). Uses `_vh` (viewport height) and `_vw` (viewport width) for responsive sizing. Pattern: split is VBox for portrait, HBox for landscape (line 68).
- **Tab bar design:** Add a tab bar at the top (before the two-panel split). Simple HBoxContainer with two flat Button nodes: "Scrolls" and "Bestiary", each 50% width. Use a `_active_tab: String` variable to track state (values: `"scrolls"`, `"bestiary"`). Connect button `pressed` signals to `_on_tab_selected(tab_name)` which updates `_active_tab` and calls `_refresh_view()`.
- **Bestiary list panel (left):** When `_active_tab == "bestiary"`, populate with one row per enemy type. Call `EnemyRegistry.get_all_enemy_ids()` to get the list in stable order. For each type_id, determine tier via `SaveManager.get_bestiary_entry(type_id)` → `seen` and `defeated` counts:
  - Tier 0 (unseen): `seen == 0` — display as "???" label in gray
  - Tier 1 (seen): `seen >= 1` and `defeated < 3` — display enemy's `display_name` in white
  - Tier 2 (defeated ×3): `defeated >= 3` — display display_name in gold/light color
  Each row is a Button (flat) in a VBoxContainer, sized viewport-relative. On press, select that enemy and refresh the right panel.
- **Enemy sprite/silhouette sourcing:** EnemyData stores `display_name` (e.g., "Undead Wanderer") but no sprite reference. Per `enemies-and-npcs.md`, enemy sprites come from `assets/textures/pixel_art/` but no specific field in EnemyData. For v1, use **text-only rows** (no sprite). If a silhouette icon is needed later, use a generic placeholder texture (e.g., `assets/textures/ui/generic_enemy_silhouette.png`); for now, omit it.
- **Right panel content:** When an enemy is selected (or on first load, select the first unseen enemy, fallback to first in list):
  - **Unseen tier:** Show "???" large centered text, darkened color (e.g., modulate = Color(0.4, 0.4, 0.4)). Smaller text: "Encounter this enemy to reveal more."
  - **Seen tier:** Show display_name as title, then stats: "Deck size: N cards", "Difficulty: N/4" (from EnemyData.difficulty_tier), "Reward: N coins" (from EnemyRegistry.get_coin_reward(type_id)).
  - **Defeated ×3 tier:** Show display_name + stats + full lore_text in a RichTextLabel (matching the Journal's scroll_lore pattern from lines 100–120).
- **Touch-friendly layout:** Per CLAUDE.md, use viewport-relative sizing:
  - Row height: `_vh * 0.055` (5.5% viewport height per button)
  - Font size in list: `_vh * 0.020` (2% vh)
  - Right panel title font: `_vh * 0.032` (3.2% vh)
  - Right panel body font: `_vh * 0.018` (1.8% vh)
  - Margins/padding: `_vh * 0.015` (1.5% vh)
  - Use ScrollContainer for both list and text (line 80+ shows ScrollContainer pattern).
- **Scroll list filtering:** When tab switches to Bestiary, call `_populate_bestiary_list()` (new method) instead of `_populate_scroll_list()`. Both populate a common VBoxContainer `_list_container` which is swapped between the two modes. Re-apply `_selected_id` from active tab state (e.g., track `_bestiary_selected_id: String` separately).
- **Tier-resolution logic:** Extract into a pure function `_get_bestiary_tier(type_id: String) -> int` returning 0, 1, or 2 based on seen/defeated counts. Test this as a standalone function in the headless test suite.
- **Header label update:** The header (line 53–55) shows "Journal — N / 8 Scrolls". When on Bestiary tab, update to show "Bestiary — N / M Revealed" where N = enemies with seen >= 1, M = total enemies. Calculate on tab switch.
- **Close button / ESC key:** Existing code (line 62, _close method) should work as-is — both tabs close the overlay.
- **Reuse SceneManager entry point:** `SceneManager.go_to_journal()` (if it exists, or check how Journal is opened today from HUD/inventory). The overlay is opened via `SceneManager` state tracking (JOURNAL state per `ui-and-scene-management.md`). No changes needed to entry point; the tab bar will default to "Scrolls" on open.

## Plan

1. Add `const _EnemyRegistry`, `_active_tab`, `_bestiary_selected_id`, `_tab_scrolls_btn`, `_tab_bestiary_btn` to `JournalScene.gd`
2. Insert tab bar (HBoxContainer with 2 flat buttons) in `_build_ui()` between header row and treasure label
3. Update `_show_empty_state()` to branch on `_active_tab` for header text and empty title
4. Add methods: `_on_tab_selected()`, `_get_bestiary_tier()`, `_update_bestiary_header()`, `_populate_bestiary_list()`, `_on_bestiary_enemy_selected()`, `_show_bestiary_detail()`
5. Bestiary list: rows sorted by `EnemyRegistry.get_all_enemy_ids()`, styled by tier (grey "???", white name, gold name)
6. Detail panel: tier 0 = "???" dimmed + message; tier 1 = stats + countdown; tier 2 = stats + lore_text

## Changes Made

- `scenes/ui/JournalScene.gd`: added `const _EnemyRegistry` preload; added vars `_active_tab`, `_bestiary_selected_id`, `_tab_scrolls_btn`, `_tab_bestiary_btn`; inserted tab bar (HBoxContainer with 2 flat viewport-relative buttons) in `_build_ui()` between header and treasure label; updated `_show_empty_state()` to branch on `_active_tab`; added `_on_tab_selected()`, `_get_bestiary_tier()`, `_update_bestiary_header()`, `_populate_bestiary_list()`, `_on_bestiary_enemy_selected()`, `_show_bestiary_detail()` methods
- Bestiary list uses grey "???" for tier 0, white name for tier 1, gold name for tier 2
- Detail panel shows encounter prompt (tier 0), stats + countdown (tier 1), stats + lore_text (tier 2)
- Header shows "Bestiary — N / M Revealed" with "★ All enemies defeated!" banner on completion

## Documentation Updates

- Updated `docs/agent/bestiary-codex.md` (created as part of TID-170)
