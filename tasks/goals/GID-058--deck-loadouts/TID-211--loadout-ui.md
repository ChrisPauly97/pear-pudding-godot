# TID-211: Deck Builder Loadout UI — Selector + Actions

**Goal:** GID-058
**Type:** agent
**Status:** pending
**Depends On:** TID-210

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The user-facing UI: loadout tabs in the deck builder, actions to create/rename/duplicate/delete loadouts, and visual feedback for invalid loadouts. All touch-friendly with viewport-relative sizing per CLAUDE.md mobile parity rules.

## Research Notes

- **InventoryScene current structure (cite SaveManager.gd line 30–36 for real viewport setup):**
  - Line 12: `var _vh: float = 0.0`, `var _vw: float = 0.0` — viewport dimensions computed in `_ready()` (line 32).
  - Deck panel is built at lines 154–168: `_deck_count_label` (line 154–157) shows "Deck (N / MAX)" with color feedback (line 289–294).
  - Deck list scrollable (`_deck_list`) starts at line 165.
  - Row builders and button logic at lines 299+.

- **Button sizing per CLAUDE.md table:**
  - Standard button: 12–18% vh width, 5–6% vh height.
  - Icon/square button: 5–6% vh width and height.
  - Font size: 2–2.5% vh.
  - Example from existing code (line 75): `_tab_cards_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)` — 14% vh width, 6.5% vh height, which matches the recommendation.

- **Loadout selector placement:**
  - Insert a new **row above the deck panel** (after the tab bar, before "Deck (N / MAX)" label), containing:
    - **Tab buttons:** one flat button per loadout (current style: line 73–78, already `flat = true` since they're tab buttons). Each shows the loadout name (e.g. "Deck 1", "Strat A", etc.). Size: ~12% vh width, ~5.5% vh height per button.
    - **"+" button (New loadout):** small icon-style button (5–6% vh square) to the right of the tabs, **disabled when 5 loadouts exist** (cap per TID-210).
    - **Actions for active tab:** three buttons visible only when a loadout is selected — Rename, Duplicate, Delete (small, ~4–5% vh width, ~5% vh height each, arranged horizontally). Delete is **red-tinted** for destructive clarity.

- **Design decision — layout choice:**
  - **Option A:** Three action buttons always visible below the tabs (cleaner, always reachable).
  - **Option B:** Long-press menu on a tab (less discoverable, but compact).
  - **Chosen: Option A** — explicit buttons are more touch-friendly (per CLAUDE.md mobile parity) and clearer for Android users who may not expect long-press. Buttons are sized per viewport and immediately visible.

- **Rename action:**
  - Trigger: Rename button → pops a modal dialog.
  - Dialog content: LineEdit (text input) pre-filled with current loadout name, OK and Cancel buttons.
  - LineEdit behavior: on Android, `focus()` automatically brings up the virtual keyboard; dialog should use a PopupPanel or AcceptDialog anchored to **top half** so the keyboard doesn't cover the input field when it appears (cite CLAUDE.md: "ensure the popup isn't covered — anchor top half").
  - Character limit: loadout names max 20 chars (arbitrary but prevents overflow in tabs).
  - Validation: reject empty names; on invalid input, show inline error or just keep the old name and return (simpler UX).
  - Example: similar to MapEditorScene.gd line 470–474 (LineEdit + popup).

- **Duplicate action:**
  - Copies the card list from the active loadout into a new loadout.
  - New loadout name: "Copy of <original_name>" (e.g. "Copy of Deck 1").
  - If that name already exists, append a counter: "Copy of Deck 1 (2)", etc.
  - Respects the 5-loadout cap: if at cap, Duplicate button is disabled.

- **Delete action:**
  - Requires confirmation: "Delete '<loadout_name>'? This cannot be undone." with Yes / No buttons (cite existing confirm pattern in InventoryScene or another scene; if none, use a simple alert-style PopupPanel with buttons).
  - **Guard:** if this is the last loadout (index 0 and size == 1), the Delete button is **disabled** (not just invisible, but greyed out with `disabled = true`). Tooltip or brief label: "Cannot delete the last loadout."
  - On confirm: remove the loadout from `loadouts` array, call `SaveManager.set_active_deck()` or a new `SaveManager.switch_loadout(index)` method to handle the active index if needed (or just trigger a refresh since InventoryScene should re-query the active loadout).

- **Tab state — switching loadouts:**
  - Clicking a tab: call `SaveManager.set_active_loadout(index)` (new method in TID-210, or implicitly handled by switching and triggering a refresh).
  - The tab button for the current active loadout is **visually distinct** (e.g., `modulate = Color.WHITE`, others `modulate = Color(0.7, 0.7, 0.7)`).
  - Validation badge: each tab shows a **red tint or outline** if the loadout at that index is invalid (fewer than 8 cards). Cite IsoConst.DECK_MIN and the validation helper from TID-210.
  - On tab switch, re-render the deck list (cite existing `_refresh_cards()` function at line 251, which rebuilds both `_collection_list` and `_deck_list` from `_working_deck`). When switching tabs, copy `loadouts[new_index].cards` into `_working_deck` and call `_refresh_cards()`.

- **Deck validation UI:**
  - Per GID-003 (TID-007), the deck count label (line 154–157) shows "Deck (N / MAX)" with red color if invalid.
  - With loadouts, the label still applies to the **active loadout only**. Keep the same logic: if `loadouts[active_loadout].cards.size()` is outside [8, 20], turn it red.
  - Additionally, show invalid badges on tabs (see above).

- **Headless tests:**
  - Any extracted tab-state logic (e.g., `_on_tab_pressed(index)`, `_update_tab_buttons()`) should be unit-testable if extracted into small helper functions. Test: switching tabs updates `_working_deck`, refreshes display, and subsequent deck edits only affect the active loadout.
  - Button enable/disable state: test that New (+) button is disabled at 5 loadouts; Delete button is disabled on the last loadout.
  - Validation badge state: test that a loadout with 4 cards shows a red badge; 8+ cards shows white.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
