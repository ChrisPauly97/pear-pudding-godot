# TID-296: Menu Hub navigation shell + SceneManager routing

**Goal:** GID-081
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The four player-facing screens (Inventory, Character, Skills, Journal) currently open as independent full-screen modals with no way to move between them. This task builds the shared **Menu Hub**: a tabbed shell that hosts those screens as switchable pages with a persistent tab bar, collapsing four `SceneManager` states into one. It defines the "embeddable page" contract the other screens migrate to (TID-297) and proves the framework by wiring the Inventory/Deck screen as the first tab.

## Research Notes

**Overlay framework (GID-073) — reuse, do not reinvent.**
- All modal overlays extend `"res://scenes/ui/BaseOverlay.gd"` via string-path `extends` (not `class_name`). It provides `_vh`/`_vw`, `_build_backdrop(alpha, close_on_tap)`, `_build_centered_panel(w, h)`, `_build_margin_vbox(...)`, `_make_dark_glass_style()`, `_close()` (emits `closed`), and `_input()` handling `ui_cancel → _close()`. See `scenes/ui/BaseOverlay.gd` and `docs/agent/ui-and-scene-management.md` (Overlay Framework section).
- Shared builders in `scenes/ui/UiUtil.gd`: `make_title_label`, `make_body_label`, `make_separator`, `make_close_button`, rarity helpers. Preload with `const _UiUtil = preload("res://scenes/ui/UiUtil.gd")`.

**Current open/close flow (the pattern to replace):**
- Signals in `autoloads/GameBus.gd`: `inventory_requested`, `character_requested`, `skill_tree_requested`, `journal_requested`.
- `autoloads/SceneManager.gd` connects each (lines ~103–110) and has a handler + closed-handler pair per screen (`_on_inventory_requested`/`_on_inventory_closed` at ~716; `_on_journal_*` ~792; `_on_character_*` ~808; `_on_skill_tree_*` ~824). Each does: guard `if _state != State.WORLD`, `instantiate()`, `get_tree().current_scene.add_child(overlay)`, connect `closed`, set `_state`. Closed handler frees and resets to `State.WORLD`.
- The `State` enum in SceneManager includes `INVENTORY`, `CHARACTER`, `SKILL_TREE`, `JOURNAL` (plus SHOP, BOUNTY_BOARD, BLACKSMITH which are NOT part of this hub — leave them alone).
- Note `_on_skill_tree_requested` also emits `GameBus.tutorial_popup_requested.emit("skill_tree")` — preserve that behaviour when Skills is opened.

**Scenes to host (all extend BaseOverlay today):** `scenes/ui/InventoryScene.gd`, `scenes/ui/CharacterScene.gd`, `scenes/ui/SkillTreeScene.gd`, `scenes/ui/JournalScene.gd`. This task only migrates **InventoryScene**; the rest are TID-297.

**Design — Menu Hub:**
- New `scenes/ui/MenuHubScene.gd` extends `BaseOverlay`. Structure: one backdrop + centered panel; inside, a persistent **tab bar** (row of buttons, one per page: Deck/Bag, Character, Skills, Journal) above a **content area** container that holds the active page.
- Define a lightweight "page" contract so each screen can render inside the hub instead of owning its own backdrop/close. Recommended approach: each page exposes `build_into(container: Control, hub) -> void` (or a `setup(hub)` + the page returns its root Control). The page must NOT add its own full-screen backdrop or Close button when hosted in the hub — those belong to the hub frame. Keep the existing standalone behaviour working only if cheaply possible; otherwise route all four exclusively through the hub (preferred — simpler, and matches the goal).
- Tab switching: hub clears the content area and builds the selected page; track `current_tab`. Provide a public `show_tab(tab_id: String)` so the entry point can deep-link.
- Sizing: viewport-relative per CLAUDE.md (tab bar height ~vh*0.07, font vh*0.022–0.03). Re-apply on `NOTIFICATION_RESIZED` if practical.

**SceneManager routing:**
- Add `open_menu_hub(tab: String = "deck")` and a single `MENU_HUB` state. Replace the four request handlers so `inventory_requested` → `open_menu_hub("deck")`, `character_requested` → `open_menu_hub("character")`, `skill_tree_requested` → `open_menu_hub("skills")`, `journal_requested` → `open_menu_hub("journal")`. Keep the old signals as the public API (HUD buttons, keybinds, and other callers still emit them) — only the handler bodies change.
- One `_on_menu_hub_closed()` resets to `State.WORLD`. Remove the now-dead per-screen state entries/handlers (or leave the enum values unused if other code references them — check first with a grep).
- Preserve the `tutorial_popup_requested.emit("skill_tree")` trigger when the hub opens to / switches to the Skills tab.

**Constraints:**
- Android-safe: use `preload()` for any `.tres`/scene resources (CLAUDE.md). MenuHubScene is pure code like TutorialPopup, so no `.tscn`/`.uid` needed unless a scene file is added.
- Do not couple systems via direct node refs — keep the `GameBus` signal entry points.

## Plan

### Files to Create
- `scenes/ui/MenuHubScene.gd` — pure-code overlay (no .tscn needed). Extends BaseOverlay.
  - Builds: backdrop → centered panel → VBox with [tab bar row, content area].
  - Tab bar: "Deck/Bag", "Character", "Skills", "Journal" buttons + Close button.
  - `show_tab(tab_id: String)` → clears content area and loads the page.
  - Deck/Bag tab: instantiates InventoryScene with `hub_mode=true`, adds it to content area.
  - Other 3 tabs: placeholder Label ("Coming in TID-297") until migrated.
  - `_close()` override: `closed.emit(); queue_free()`.

### Files to Modify
- `scenes/ui/InventoryScene.gd`:
  - Add `var hub_mode: bool = false` property.
  - In `_build_ui()`: branch on `hub_mode`. If true, skip `_build_backdrop()` and `_build_centered_panel()`; instead build a MarginContainer into `self` (which is FULL_RECT inside content_area) and add a VBox wrapper. If false, existing standalone path (unchanged for now, though won't be reached since all four are routed through hub).
  - Skip Close button(s) when `hub_mode = true`.
  - `_on_save()`: if `hub_mode`, save without emitting `closed`.

- `autoloads/SceneManager.gd`:
  - Add `MENU_HUB` to State enum.
  - Add `const _MenuHubScript = preload("res://scenes/ui/MenuHubScene.gd")`.
  - Add `open_menu_hub(tab: String = "deck") -> void`: instantiate hub, `show_tab(tab)`, add to world, connect `closed`, record in `_overlays[State.MENU_HUB]`, set state.
  - Add `_on_menu_hub_closed()`: erase MENU_HUB from `_overlays`, set `_state = State.WORLD`.
  - Replace `_on_inventory_requested()` → `open_menu_hub("deck")`.
  - Replace `_on_journal_requested()` → `open_menu_hub("journal")`.
  - Replace `_on_character_requested()` → `open_menu_hub("character")`.
  - Replace `_on_skill_tree_requested()` → preserve `tutorial_popup_requested.emit("skill_tree")` + `open_menu_hub("skills")`.
  - Leave INVENTORY/CHARACTER/SKILL_TREE/JOURNAL in enum (other code might reference them; they become unused variants).

### Acceptance check
- Opening any of Inventory / Journal / Character / Skills now opens a single hub with 4 tabs.
- Deck/Bag tab shows InventoryScene content (fully functional: browse, build, save deck).
- Other tabs show placeholder.
- Hub Close button returns to world correctly.
- Escape key closes hub (via BaseOverlay._input).

## Changes Made

**Created:**
- `scenes/ui/MenuHubScene.gd` — pure-code overlay (no .tscn). Extends BaseOverlay. Builds backdrop + centered panel with tab bar (Deck/Bag, Character, Skills, Journal) + Close button + content area. `show_tab(tab_id)` switches the active page. Deck tab embeds InventoryScene with `hub_mode=true`. Other tabs show placeholder until TID-297.

**Modified:**
- `scenes/ui/InventoryScene.gd`:
  - Added `var hub_mode: bool = false` property.
  - `_build_ui()` branches on `hub_mode`: hub path builds a MarginContainer into `self` (FULL_RECT inside content area) and skips backdrop/panel; standalone path unchanged.
  - Close buttons (portrait/landscape/craft panel) are skipped when `hub_mode=true`.
  - `_on_save()` only emits `closed` when `not hub_mode` (in hub, saving keeps hub open).
- `autoloads/SceneManager.gd`:
  - Added `MENU_HUB` to State enum (old states kept for backwards-compat).
  - Added `const _MenuHubScript = preload("res://scenes/ui/MenuHubScene.gd")`.
  - Added `open_menu_hub(tab: String = "deck") -> void` public entry point.
  - Added `_on_menu_hub_closed()` handler (resets to WORLD state).
  - `_on_inventory_requested()` → `open_menu_hub("deck")`.
  - `_on_journal_requested()` → `open_menu_hub("journal")`.
  - `_on_character_requested()` → `open_menu_hub("character")`.
  - `_on_skill_tree_requested()` → preserves tutorial_popup_requested emit + `open_menu_hub("skills")`.

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md`: added Menu Hub section documenting the hub overlay, page contract, SceneManager routing change, and tab IDs.
