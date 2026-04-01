# TID-007: Add Deck Size Indicator and Validation Feedback in InventoryScene

**Goal:** GID-003
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`InventoryScene` has no indicator of how many cards are in the active deck or whether it meets the required minimum. The player can remove cards below 8 without any warning.

## Research Notes

**InventoryScene** (`scenes/ui/InventoryScene.gd`):
- Left panel = collection (owned_cards), right panel = active deck (player_deck)
- "Add to Deck" and "Remove" buttons fire on each card entry
- All sizes are relative to viewport height (CLAUDE.md rule)

**Changes needed:**
1. **Deck counter label** — add a `Label` above the deck panel showing `"Deck: %d / %d" % [deck_size, DECK_MAX]`.
   - Update it in `_refresh_deck_panel()` (or equivalent refresh method — read the file to find the actual method name).
   - Colour: normal when 8 ≤ size ≤ 20; `Color.RED` when outside range.

2. **"Add to Deck" guard** — disable (or skip) the button when `player_deck.size() >= DECK_MAX`.

3. **"Remove" guard** — disable (or grey out) the button when `player_deck.size() <= DECK_MIN`.
   - Soft guard: show a tooltip or label "Minimum deck size reached" rather than a hard disable, so the player understands why.

4. **Constants** — add to `autoloads/IsoConst.gd`:
   ```gdscript
   const DECK_MIN: int = 8
   const DECK_MAX: int = 20
   ```

**Reading the file first is mandatory** — `InventoryScene.gd` structure (method names, panel hierarchy) must be confirmed before editing. The doc describes the UI but the actual implementation may differ in detail.

## Plan

1. Add `DECK_MIN = 8` and `DECK_MAX = 20` constants to `IsoConst.gd`.
2. Remove local `MAX_DECK` constant from `InventoryScene.gd`; replace all references with `IsoConst.DECK_MAX`.
3. Update `_refresh()` to set deck counter label color: red when `deck_sz < DECK_MIN or deck_sz > DECK_MAX`, white otherwise.
4. In `_make_deck_row()`, disable the remove button and set tooltip when `_working_deck.size() <= IsoConst.DECK_MIN`.

## Changes Made

- `autoloads/IsoConst.gd`: Added `DECK_MIN: int = 8` and `DECK_MAX: int = 20` constants.
- `scenes/ui/InventoryScene.gd`:
  - Removed local `const MAX_DECK: int = 20`.
  - `_refresh()`: deck counter label now shows color (red when invalid, white when valid).
  - `_make_collection_row()`: "Add" button disabled guard uses `IsoConst.DECK_MAX`.
  - `_make_deck_row()`: "Remove" button disabled with tooltip when at minimum.
  - `_on_add()`: guard uses `IsoConst.DECK_MAX`.

## Documentation Updates

No agent docs required; this is a UI enforcement change with constants in IsoConst (already documented as source of truth).
