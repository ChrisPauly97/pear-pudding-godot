# GID-183: Magic-school Allies (Verdant & Rift)

## Objective

Give the verdant and rift schools their own Allies so a deck built around any one school has board presence, making damage-school matchups (GID-181) a real deck choice.

## Context

GID-181 / TID-757 measured mono-school decks: verdant and rift lose almost every fight (forest roster: verdant 0 %, rift 3 % vs physical 92 %) because both schools have **0 minion cards** (10 spells each), while light (~11) and dark (~12) have Allies and the starter deck is all-physical Allies. User approved this content goal on 2026-10-10 (option "matched decks + content goal"). Spec: the card is the atomic unit; captures/Allies are the hook.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-767 | Verdant + rift Ally roster design | agent | done | — |
| TID-768 | Verdant Allies: cards, registry, art | agent | done | TID-767 |
| TID-769 | Rift Allies: cards, registry, art | agent | done | TID-767 |
| TID-770 | Distribution: drop pools, vendors, packs | agent | done | TID-768, TID-769 |
| TID-771 | Mono-school re-measure, tune, tighten bands | agent | pending | TID-770, TID-757 |

## Acceptance Criteria

- [ ] Verdant and rift each have 6–8 Allies across both their branches
- [ ] Every new card has generated art, a `.uid` sidecar, a CardRegistry preload, and passes test_magic_types / card art tests
- [ ] New Allies drop in thematic biomes and appear in vendors/packs
- [ ] Mono verdant and mono rift decks are competitive (measured, within the band TID-771 sets)
