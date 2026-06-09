# GID-053: The Rival — Isfig's Shadow

## Objective

Isfig becomes a recurring rival who duels the player at three story beats with a deck that grows a tier stronger each encounter, ending in a final showdown with a unique card reward.

## Context

Isfig already exists in the Chapter 1 flag sequence (as the open-world encounter between Maykalene and Blancogov who delivers Scargroth's letter) but is currently a one-off non-combat NPC. A recurring rival whose deck tracks the player's growth gives the story a personal antagonist between the opening and the King Eldar finale, and reuses the existing enemy-battle flow — no new battle mechanics.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-194 | Rival framework: encounter tiers keyed to story flags + player level, deck definitions, save fields | agent | pending | — |
| TID-195 | Rival encounters: spawn/dialogue/battle wiring at three story beats in named maps | agent | pending | TID-194 |
| TID-196 | Final showdown + unique card reward + journal entry | agent | pending | TID-195 |

## Acceptance Criteria

- [ ] Three rival encounter tiers exist as EnemyData-style decks whose strength scales with the encounter number (and is nudged by player level at battle time); rival progress (encounters fought/won) persists in SaveManager with migration
- [ ] Each encounter is gated by a story flag from the existing Chapter 1 sequence (no new human-owned story content required); Isfig appears in the appropriate named map, has pre-battle dialogue, and the battle uses the standard enemy battle flow
- [ ] Losing to the rival is non-blocking: the player can retry; winning advances rival progress and is remembered in dialogue
- [ ] The final showdown unlocks after the prior two wins plus the late-chapter story flag, and awards a unique non-craftable card exactly once
- [ ] A journal entry records the rivalry's progress (reuse the existing journal/scroll presentation)
- [ ] All tests pass headless
