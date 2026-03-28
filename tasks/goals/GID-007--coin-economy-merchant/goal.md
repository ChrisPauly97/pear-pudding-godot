# GID-007: Coin Economy & Merchant NPC

## Objective

Complete the coin loop: enemies drop coins on defeat, and a merchant NPC lets the player spend coins to buy cards.

## Context

`SaveManager.coins` exists, `add_coins()` is wired, and the HUD already shows the coin count. Chests drop coins. But enemies award nothing on defeat, and there is no place to spend coins — making the economy half-built. A merchant NPC in named maps and procedural towns would give coins a purpose and make exploration rewarding beyond card drops alone.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-015 | Award coins on enemy defeat | agent | pending | — |
| TID-016 | Merchant NPC and shop overlay | agent | pending | TID-015 |

## Acceptance Criteria

- [ ] Defeating an enemy awards coins (amount scales by enemy type)
- [ ] Coin total updates in the HUD immediately after battle
- [ ] A merchant NPC entity type exists and can be placed in named maps and spawned in procedural towns
- [ ] Interacting with the merchant opens a shop overlay listing buyable cards with coin prices
- [ ] Buying a card deducts coins, adds card to `owned_cards`, and saves
- [ ] Cannot buy if insufficient coins (button disabled / feedback shown)
