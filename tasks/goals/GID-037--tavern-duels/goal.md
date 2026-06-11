# GID-037: Tavern Duels & Champion Ladder

## Objective

Let townsfolk challenge the player to friendly wager duels using the standard battle overlay, capped by a regional champion fight that rewards a legendary card.

## Context

Currently only EnemyNPC entities trigger battles — towns are quest dispensers, not card-playing communities. Friendly duels give towns life and give the coin economy (GID-007) a sink/source loop. The champion ladder adds a Gym Leader-style progression beat: defeat all duelists in a region to unlock the champion.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-143 | Friendly duel battle flow (GameState flag, GameBus signal, wager resolution) | agent | done | — |
| TID-144 | Duelist TownspersonNPC wiring + save tracking | agent | done | TID-143 |
| TID-145 | Regional champion NPC + legendary reward | agent | pending | TID-144 |

## Acceptance Criteria

- [ ] A battle can be started in "friendly duel" mode: no story-flag side effects, coins transferred per wager on win/loss
- [ ] Any TownspersonNPC can be flagged `is_duelist` with a deck and wager amount; approaching offers the duel
- [ ] Defeated duelists are tracked per save in `SaveManager.defeated_duelists`
- [ ] A champion NPC in blancogov refuses to duel until all regional duelists are beaten, then rewards a legendary card on defeat
- [ ] All tests pass headless
