# GID-041: Battle Companions

## Objective

A companion slot on the player that grants one passive battle effect, with Maiteln the wizard as the first companion, unlocked by story progression.

## Context

Maiteln, the story's mentor, currently exists only in dialogue. A companion slot ties the narrative to the battle loop: players who progress through Chapter 1 earn a tangible gameplay reward. The framework is intentionally minimal — one passive per companion, displayed in the battle HUD — leaving room for future companions without complex interactions.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-159 | Companion framework (CompanionData, registry, PlayerState passive, CharacterScene slot) | agent | pending | — |
| TID-160 | Maiteln companion content, story-flag gated | agent | pending | TID-159 |

## Acceptance Criteria

- [ ] CompanionData resources define a passive type/value and an unlock story flag; CompanionRegistry preloads them
- [ ] The active companion (persisted in `SaveManager.active_companion`) applies its passive at battle start and shows a portrait + tooltip in the battle HUD
- [ ] CharacterScene shows the companion slot with a picker; locked companions display their unlock requirement
- [ ] Maiteln unlocks via his story flag and grants "draw 1 extra card at the start of each turn"
- [ ] All tests pass headless
