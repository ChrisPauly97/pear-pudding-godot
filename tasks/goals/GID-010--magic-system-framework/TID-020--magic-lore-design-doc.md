# TID-020: Magic Lore & Design Doc

**Goal:** GID-010
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Before any schema or asset work can begin, the magic system needs a canonical design document that the user can review and adjust. This doc will be referenced by TID-021, TID-022, and TID-023, so it must be complete and agreed-on before those tasks run.

The user's brief:
- **Light magic** — warmth, energy, goodness
- **Dark magic** — cold, vacuum, badness
- **Ember** (Light sub) — fire offense, aggressive burn spells
- **Dawn** (Light sub) — healing/restoration wrapper; no cards in this release
- **Dusk** (Dark sub) — lifesteal/drain wrapper; no cards in this release
- **Ash** (Dark sub) — earth, phoenix metaphor, necromancy; resurrection and disruption spells
- Cards in this system are **Card / Spell** type (cost mana, targeted effect, no board slot)

## Research Notes

- `data/CardData.gd` — current schema: `id`, `card_name`, `cost`, `attack`, `health`, `card_class`, `description`, `color`
- `card_class` is currently always `"minion"` — spells need a different class (`"spell"`)
- Existing minion costs: Ghost 1, Skeleton ~2, Zombie ~3, Ghoul ~4 — spells can use a similar 1–5 range
- `docs/agent/battle-system.md` — no mention of spell mechanics; adding spells is new design territory
- The user's item type table classifies spells as "Card / Spell": cost mana, can target enemy hero or minions

## Plan

_Written during Plan phase._

Create `docs/agent/magic-system.md` containing:

1. **Top-level magic lore** — Light and Dark flavour paragraphs
2. **Sub-branch profiles** — Ember, Dawn, Dusk, Ash with personality, playstyle, and colour palette
3. **Card stat proposals** — table for all 8 spells with cost, effect description, and flavour text
4. **Implementation notes** — what CardData fields are needed, spell effect design patterns for future implementation

## Proposed Card Stats

### Ember Branch (Light / Ember) — direct damage spells

| Card | Cost | Effect | Flavour Text |
|------|------|--------|--------------|
| Spark | 1 | Deal 1 damage to any target | "The smallest flame is still a flame." |
| Flicker | 2 | Deal 1 damage to all enemies | "Unstable, uncontainable, inevitable." |
| Ember | 3 | Deal 3 damage to one target | "What smolders longest burns deepest." |
| Scorch | 5 | Deal 5 damage to one target | "Nothing survives the full expression of the flame." |

### Ash Branch (Dark / Ash) — disruption and resurrection spells

| Card | Cost | Effect | Flavour Text |
|------|------|--------|--------------|
| Ash | 1 | Reduce a minion's attack by 2 until end of turn | "What remains when fire has finished." |
| Brittle | 2 | Deal 2 damage to a minion | "Cold makes things fragile." |
| Char | 3 | Destroy a minion with 3 or less HP | "The last thing it knew was heat." |
| Alight | 4 | Resurrect the last destroyed friendly minion with 1 HP | "From ash, something stirs." |

## Changes Made

_Filled after Build phase._

## Documentation Updates

Creates `docs/agent/magic-system.md`.
