# TID-286: Remove Discard Reshuffle from draw_card()

**Goal:** GID-077
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`PlayerState.draw_card()` (lines 44–58 in `game_logic/battle/PlayerState.gd`) currently shuffles the discard pile back into the draw deck the moment the draw deck is empty. This means a player can never truly run out of cards — they just cycle through their deck indefinitely. TID-280 will introduce fatigue damage instead; this task cleans up the old reshuffle behavior first so TID-280 has a clean hook point.

## Research Notes

- **File:** `game_logic/battle/PlayerState.gd` — `draw_card()` contains:
  ```gdscript
  if draw_deck.is_empty():
      # Shuffle discard back
      draw_deck.append_array(discard)
      discard.clear()
      draw_deck.shuffle()
  ```
  Delete these 4 lines. The second `if draw_deck.is_empty(): return null` guard stays — it will now be the fatigue hook point that TID-280 adds to.
- **Opening hand:** `draw_opening_hand()` calls `draw_card()` 4 times at battle start. Both players start with full decks so the reshuffle path can never fire during opening-hand draw — no special handling needed there.
- **AI draw:** `PlayerState.start_turn()` → `draw_card()`. Same codepath; removing reshuffle affects AI identically (which is correct).
- **Tests:** Run `godot --headless --path . -s tests/runner.gd` to confirm no regressions. No existing test exercises the reshuffle path directly (the deck is always at least 12 cards in unit tests), so no test changes are needed for this task alone.
- **No SaveManager changes:** `discard` is already persisted in `PlayerState.to_dict()/from_dict()` — the discard pile simply stays populated after the deck runs out instead of being shuffled back. No migration needed.

## Plan

1. Open `game_logic/battle/PlayerState.gd`.
2. Delete the four reshuffle lines inside `draw_card()`:
   ```gdscript
   # Shuffle discard back
   draw_deck.append_array(discard)
   discard.clear()
   draw_deck.shuffle()
   ```
3. Leave the second `if draw_deck.is_empty(): return null` in place — TID-280 will replace it with the fatigue damage block.
4. Run tests; confirm pass.

## Changes Made

- `game_logic/battle/PlayerState.gd`: removed the 4-line reshuffle block inside `draw_card()`; the second `is_empty` guard is now the fatigue hook (replaced in TID-287).

## Documentation Updates

_(none required — battle-system.md will be updated as part of TID-280)_
