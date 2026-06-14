# GID-076: Combat Deck Fatigue

## Objective

Remove the discard-reshuffle mechanic and replace it with an escalating fatigue damage system: when a player's draw deck is empty, drawing a card instead deals increasing damage to their hero (1 on first miss, 2 on second, etc.).

## Context

Currently `PlayerState.draw_card()` shuffles the discard pile back into the draw deck whenever the deck runs out, allowing battles to continue indefinitely with no consequence. This makes long stall games viable and removes deck-out as a meaningful threat. The fix mirrors Hearthstone's "fatigue" mechanic: once the draw deck is truly exhausted the game clock is running — every failed draw ticks the player's hero closer to death.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-279 | Remove discard reshuffle from draw_card() | agent | pending | — |
| TID-280 | Fatigue damage system — escalating hero damage on empty draw | agent | pending | TID-279 |

## Acceptance Criteria

- [ ] `PlayerState.draw_card()` no longer shuffles the discard back into the draw deck
- [ ] When `draw_deck` is empty, each draw attempt deals `fatigue_counter` damage to the hero and increments the counter (1, 2, 3 …)
- [ ] `fatigue_counter` is persisted in `PlayerState.to_dict()/from_dict()` for mid-battle save/restore
- [ ] Floating damage labels and game-over check fire correctly on fatigue damage
- [ ] AI draws also trigger fatigue (no special-casing)
- [ ] `docs/agent/battle-system.md` documents the fatigue mechanic
- [ ] All tests pass headless
