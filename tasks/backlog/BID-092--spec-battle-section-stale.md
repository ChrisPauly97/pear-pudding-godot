# BID-092: Spec "Card Battle System" section describes the old turn-based model only

**Category:** spec-gap
**Discovered During:** GID-175 / research

## Description

`docs/human/specification.md` → Key Features → Card Battle System lists only turn-based rules: four card types, 5 board slots, mana capped at 10, hero HP 30. The game now defaults to real-time combat (GCD, mana points ×100, 3 Allies, auto-attack, momentum), and soon technique cards. None of that is in the spec.

## Evidence

Spec lines ~48-55 vs `docs/agent/combat-model.md` "Real-Time Combat (decided 2026-09-26)".

## Suggested Resolution

The user updates the spec section (human-owned), or permits the agent to summarise combat-model.md there.
