# GID-175: Skill Bar → Technique Cards

## Objective

Replace the fixed real-time skill bar with technique cards that are deckbuilt, drawn and played from the hand.

## Context

The user wants the game to stay a TCG rather than drift into a WoW clone. The new spec section `## Identity` (docs/human/specification.md) makes "the card is the atomic unit" the rule. The fixed 3-slot bar (TID-550) is the main thing that breaks it.

Defaults agreed at the review gate: max 1 copy of each technique per deck; Strike is a normal deck card; techniques work in both turn-based and real-time. When played, a technique goes to the bottom of the draw pile (deck cycling replaces cooldowns).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-706](TID-706--technique-card-design.md) | Design: technique-card rules | agent | done | — |
| [TID-707](TID-707--technique-card-type.md) | Technique card type: 8 cards, recycle-on-play, both modes | agent | done | TID-706 |
| [TID-708](TID-708--technique-learning.md) | Learning grants cards + save migration | agent | pending | TID-707 |
| [TID-709](TID-709--technique-realtime.md) | Real-time integration: hand replaces the bar | agent | pending | TID-707 |
| [TID-710](TID-710--retire-skillbar.md) | Retire SkillBar dependents + docs | agent | pending | TID-708, TID-709 |
| [TID-711](TID-711--identity-section.md) | Identity section in specification.md | human-action | done | — |

## Acceptance Criteria

- [ ] No fixed skill bar in real-time battles; all 8 techniques are cards played from the hand
- [ ] Techniques recycle to the bottom of the draw pile and work in both battle modes
- [ ] Trainers grant technique cards; old saves are migrated without loss
- [x] Identity section in specification.md
- [ ] Tests, gdlint and unsafe-hits clean; agent docs updated
