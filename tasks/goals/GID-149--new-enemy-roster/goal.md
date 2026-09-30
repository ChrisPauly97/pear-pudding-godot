# GID-149: New Enemy Roster

## Objective

Eight new enemies that widen the roster beyond undead and Martarquas humans — beasts, casters, a night hunter,
a mirror and a crypt boss — each with a world presence, a fight that matches it, a soulbind signature and
generated sprites.

## Context

User (2026-09-30) approved all eight drafts: Grey Wolf Pack, Bog Hag, Martarquas Scout, Dune Scarab Swarm,
Ember Cultist, Frost Wendigo, Riftborn Echo, Barrow King. Defaults taken for the open questions: the Wolf Pack
has an Alpha as its enemy hero (no BID-077 rule change); new minion cards are ordinary collectibles; art comes
from the in-house generator (`scripts/gen_creature_sprites.py`). Enemy spells resolve since BID-078, so caster
decks work.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-619 | Cards, Signatures & Capture Conditions | agent | done | — |
| TID-620 | Enemy Registry Entries & World Placement | agent | done | TID-619 |
| TID-621 | Fight Traits (howl, swarm, frenzy, mirror) | agent | done | TID-620 |
| TID-622 | Generated Sprites | agent | done | TID-620 |
| TID-623 | Docs, Bestiary & Verification | agent | done | TID-621, TID-622 |

## Acceptance Criteria

- [ ] All eight enemies spawn in their biome/situation and can be fought in turn-based and real time
- [ ] Each has a signature card and a working capture condition
- [ ] Each has a generated world sprite (packs show their members)
- [ ] Tests, gdlint, unsafe-hits, smoke tests clean
