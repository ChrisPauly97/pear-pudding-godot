# TID-007: Add Deck Size Indicator and Validation Feedback in InventoryScene

**Goal:** GID-003
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
