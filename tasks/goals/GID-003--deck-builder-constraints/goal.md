# GID-003: Deck Builder Constraints & Validation

## Objective

Enforce minimum and maximum deck sizes in the inventory UI and prevent the player from starting a battle with an invalid deck.

## Context

The spec lists "Should the deck builder enforce a minimum / maximum deck size?" as an open question. Currently there is no enforcement: a player with 0 cards in their deck will silently enter battle with an empty draw pile (immediate loss or undefined behaviour). The `InventoryScene` doc recommends 8–20 cards but does not enforce it. This goal closes the open question and makes the constraint visible and enforced.

Chosen constraint: **minimum 8 cards, maximum 20 cards** (matching the doc recommendation).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-007 | Add deck size indicator and validation feedback in InventoryScene | agent | done | — |
| TID-008 | Block battle engagement if deck is below minimum; show HUD warning | agent | pending | TID-007 |

## Acceptance Criteria

- [ ] InventoryScene shows a live deck size counter (e.g. "Deck: 12 / 20")
- [ ] The counter turns red when deck size < 8 or > 20
- [ ] "Add to Deck" button is disabled when deck already has 20 cards
- [ ] "Remove" button is disabled when deck already has 8 cards (prevents going below minimum)
- [ ] If a player tries to engage an enemy with a deck of fewer than 8 cards, a HUD message appears ("Deck too small — need at least 8 cards") and the battle does not start
- [ ] Constraint constants (`DECK_MIN = 8`, `DECK_MAX = 20`) live in `IsoConst` so they are the single source of truth
