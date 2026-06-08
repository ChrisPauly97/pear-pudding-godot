# GID-037: Combat Deck & Fatigue Bugs

## Objective

Remove the discard-reshuffle mechanic, fix dead cards re-entering the game with 0 health, and implement a fatigue damage system when the draw deck is exhausted.

## Context

Two related bugs exist in the battle system:
1. Dead minions move to the discard pile with damaged/zero health. Because `PlayerState.draw_card()` shuffles the discard back into the draw deck when empty, these cards re-enter the game with 0 HP and can be played/die instantly.
2. There is no fatigue system — the reshuffle meant players could cycle cards indefinitely. The intended design is: discard is a permanent graveyard, and drawing from an empty deck deals escalating damage.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-143 | Remove reshuffle; reset health on discard | agent | pending | — |
| TID-144 | Implement fatigue damage system | agent | pending | TID-143 |

## Acceptance Criteria

- [ ] Cards that die in combat never re-enter the draw deck
- [ ] The `resurrect_last` spell correctly resurrects minions at full health
- [ ] Drawing from an empty deck deals 1, 2, 3… damage to the drawing player's hero
- [ ] Fatigue applies to both player and enemy
- [ ] A visible notification appears when fatigue triggers
- [ ] Fatigue counter persists through save/load
