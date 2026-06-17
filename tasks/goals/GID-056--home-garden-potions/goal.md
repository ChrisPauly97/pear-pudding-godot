# GID-056: Home Garden & Potion Brewing

## Objective

Garden plots at the player home grow seeds into plants over in-game days; plants craft into potions the player can drink in battle — one per battle — for healing, draw, or mana effects.

## Context

The GID-046 house is static once bought. A garden gives a reason to come home (growth runs on the days_elapsed counter bounties also use), and potions create the game's first consumable: plants → potions via the existing crafting screen, used from the battle HUD. **Depends on GID-046 (TID-173 player_home interior map).**

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-203 | Garden model: seed/plant types, growth via days_elapsed, plot save fields | agent | done | — |
| TID-204 | Garden plot entities at the player home: plant/harvest interactions, growth-stage sprites | agent | done | TID-203 (+ GID-046 TID-173) |
| TID-205 | Seeds in merchant stock + plant inventory + potion recipes in the crafting screen | agent | done | TID-203 |
| TID-206 | Potion use in battle: one-per-battle HUD button, three potion effects | agent | pending | TID-205 |

## Acceptance Criteria

- Three seed types (sunpetal, moonroot, embercap) grow through 3 visual stages over 2–3 in-game days, tracked per plot in SaveManager with migration; growth advances on day rollover even while away
- The player home interior has 3 garden plots: interact to plant (choosing an owned seed), interact again when mature to harvest 1–2 plants; plot states render distinct sprites per stage
- Seeds are sold by merchants (~30 coins); plants and potions are counted inventories in SaveManager; the crafting screen gains potion recipes (e.g. 2 sunpetal → Healing Draught, 2 moonroot → Clarity Brew, 2 embercap → Ember Tonic)
- In battle, a potion button in the HUD lets the player drink ONE potion per battle: Healing Draught restores 8 hero HP (capped at max), Clarity Brew draws 2 cards, Ember Tonic grants +1 mana this turn; the button is hidden when no potions are owned or one was already used
- Everything is touch-operable with viewport-relative sizing (mobile parity per CLAUDE.md)
- All tests pass headless
