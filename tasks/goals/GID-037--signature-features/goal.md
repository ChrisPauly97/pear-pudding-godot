# GID-037: Signature Features — Make the World Play Cards Back

## Objective

Add five features that transform the game from a collection of systems into a living card-playing world: tavern duels, an Endless Spire roguelike run, living world events, puzzle battle shrines, and a story companion in battle.

## Context

GID-036 completed mobile-first UI. The game now has deep systems (keywords, skill trees, crafting, meta-progression) but lacks replayability hooks and moments that feel uniquely *this* game. These five features each leverage existing infrastructure (battle overlay, dungeon gen, town NPCs, boss framework) with minimal new coupling.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-143 | Friendly NPC duels with coin wagers | agent | pending | — |
| TID-144 | Regional champion ladder & rewards | agent | pending | TID-143 |
| TID-145 | Endless Spire run state & card-draft logic | agent | pending | — |
| TID-146 | Endless Spire entrance, floor progression & run summary | agent | pending | TID-145 |
| TID-147 | Living world event framework (scheduler, save fields, signals) | agent | pending | — |
| TID-148 | Three concrete world events: roaming boss, traveling merchant, card shower | agent | pending | TID-147 |
| TID-149 | Puzzle battle mode (preset board states, solve-the-lethal win check) | agent | pending | — |
| TID-150 | Puzzle shrine entity + 5 authored puzzles | agent | pending | TID-149 |
| TID-151 | Battle companion framework (passive/hero-power slot) | agent | pending | — |
| TID-152 | Maiteln as first companion, story-flag gated | agent | pending | TID-151 |

## Acceptance Criteria

- [ ] Any TownspersonNPC can be flagged as a duelist; approaching them offers a wager duel using the standard battle overlay
- [ ] A regional champion NPC exists in at least one named map; defeating all regional duelists unlocks the champion fight for a legendary card reward
- [ ] The Endless Spire can be entered from a named-map door; each floor presents a card draft and an enemy; run ends on death; run summary shows floors cleared
- [ ] Three world events fire on a timer/location trigger and are visible to the player (minimap dot for roaming boss, smoke particle for traveling merchant, sparkle for card shower)
- [ ] At least 5 puzzle shrines exist in named maps; each loads a preset board and checks for a one-turn lethal; correct solution rewards a rare card
- [ ] A companion slot exists on PlayerState; equipping Maiteln (after his story flag) grants a passive bonus visible in the battle UI; all tests pass headless
