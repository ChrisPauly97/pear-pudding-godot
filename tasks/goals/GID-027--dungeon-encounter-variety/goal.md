# GID-027: Dungeon Encounter Variety

## Objective

Add rest site, treasure room, and random event room types to procedural dungeons so dungeon-running feels like a mini-roguelike loop rather than a linear combat gauntlet.

## Context

Procedural dungeons (entered via ruins doors in the infinite world) currently generate only combat rooms. Every dungeon door leads to the same experience. Adding 2–3 room types — without combat — gives the player resource management decisions (heal now vs. push on), discovery moments, and narrative texture. This is the primary driver of dungeon replayability in games like Slay the Spire.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-089 | Room type framework — assign room types during dungeon generation | agent | done | — |
| TID-090 | Rest site room — heal HP, optionally remove a card from deck | agent | done | TID-089 |
| TID-091 | Treasure room — guaranteed chest drop, no combat | agent | done | TID-089 |
| TID-092 | Random event room — text-choice with meaningful consequences | agent | done | TID-089 |

## Acceptance Criteria

- [ ] Dungeon generation assigns a room type (combat, rest, treasure, event) to each room
- [ ] Rest site rooms let player recover hero HP and optionally remove one card from their deck
- [ ] Treasure rooms contain a guaranteed chest with card or weapon reward, no enemy
- [ ] Event rooms present a text prompt with 2–3 choices, each with a defined outcome (gain coins, gain/lose HP, gain a card, etc.)
- [ ] Room type is visually distinguishable (different floor colour or icon on dungeon minimap if one exists)
- [ ] All tests pass headless
