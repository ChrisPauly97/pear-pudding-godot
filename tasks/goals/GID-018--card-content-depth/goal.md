# GID-018: Card Content Depth — Dawn & Dusk Branches

## Objective

Add the two missing magic branches (Dawn and Dusk), each with ~8 cards, and implement all required spell effect handlers so the card pool has meaningful build diversity.

## Context

The magic system framework (GID-010) defined four branches — Ember, Ash, Dawn, Dusk — but only Ember and Ash cards were implemented (13 cards total). Dawn (healing/restoration) and Dusk (lifesteal/drain) have schema support but zero cards. At 13 cards the game has no deck-building variety. This goal brings the card pool to ~30, enabling different archetypes.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-054 | Implement new spell effect handlers | agent | done | — |
| TID-055 | Create Dawn branch card .tres files | agent | done | TID-054 |
| TID-056 | Create Dusk branch card .tres files | agent | done | TID-054 |
| TID-057 | Register new cards in drop pools, shop, and rewards | agent | done | TID-055, TID-056 |

## Acceptance Criteria

- [ ] New spell effect types (heal_single, heal_all, shield_minion, buff_attack, lifesteal_hit, mana_drain, curse_minion, draw_card) are handled in battle logic without errors
- [ ] 8 Dawn cards (6 spells + 2 minions) exist as .tres files with .uid sidecars
- [ ] 8 Dusk cards (6 spells + 2 minions) exist as .tres files with .uid sidecars
- [ ] New cards appear in merchant shop and enemy drop pools
- [ ] All tests pass headless
