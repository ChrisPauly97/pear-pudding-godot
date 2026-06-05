# GID-035: Card Effects & Ability Text

## Objective

Make card effects visible and interactive: show ability text on card faces, add targeting UI for all single-target spells, and introduce the Emergence mechanic for minions.

## Context

Players currently can't see what a spell card does without right-clicking to open the inspect overlay. Single-target spells other than `deal_damage_single` silently auto-target slot 0 with no player choice. Minions have no on-play effects — only passive keywords (Ward, Surge, Shroud). This goal fixes all three gaps.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-140 | Inline ability text on card panels | agent | done | — |
| TID-141 | Extended targeting for single-target spells | agent | done | TID-140 |
| TID-142 | Minion Emergence system + new cards | agent | done | TID-140 |

## Acceptance Criteria

- [ ] Spell cards show their effect in plain English on the card face (in hand and on-board)
- [ ] Minion cards with Emergence show "Emergence: <text>" on the card face
- [ ] `heal_single`, `shield_minion`, `buff_attack` enter friendly-target mode (player picks their own minion)
- [ ] `curse_minion` and `lifesteal_hit` enter enemy-target mode (player picks enemy minion or hero)
- [ ] At least 5 new minion cards with Emergence effects exist across branches
- [ ] Emergence fires and resolves visibly (float labels + flash) when a minion is summoned
- [ ] CardInspectOverlay shows Emergence text alongside existing spell/keyword sections
