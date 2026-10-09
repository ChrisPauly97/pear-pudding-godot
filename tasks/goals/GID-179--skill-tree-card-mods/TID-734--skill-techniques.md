# TID-734: Skill .tres re-authored; actives → technique cards; hero power removed

**Goal:** GID-179
**Type:** agent
**Status:** done
**Depends On:** TID-733

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-09).

## Research Notes

- Hero power: `BattleConsumables._add_hero_power_button/_use_hero_power/_apply_hero_power_effect`, BattleNet intent `encode_hero_power`, `BattleArena` effects list (line 261).
- Technique ownership: `TechniqueDefs.known_cards(learned)` → `SaveManager._restore_technique_cards`; extend for unlocked skills. `SaveManager.unlock_skill` should deal the card in like `learn_ability`.
- Card `.tres` pattern: data/cards/tech_ember_lance.tres + CardRegistry preload.

## Plan

Re-author the 48 skill .tres per the combat-model table; 16 branch-typed technique cards; skill-granted ownership + migration; delete the hero power end to end.

## Changes Made

- `data/skills/*.tres` (48): `effect_type` / `effect_value` / `filter` / `grants_card` + new descriptions; ids and tree positions unchanged.
- 16 `data/cards/tech_*.tres` (+ `.uid`), preloaded in `CardRegistry`; magic type + branch set.
- `TechniqueDefs`: 16 rows with a `skill` key; `card_for_skill`, `is_skill_technique`; `known_cards(learned, skills)`; `ids()` = trainer ORDER + skill ones.
- `SaveManager`: `_grant_skill_technique` on `unlock_skill` / alt purchase; load repair owns skill techniques. `SaveMigrations` v48 queues them into `technique_deck_pending`.
- Hero power removed: `BattleConsumables` (button, use, effect), `BattleScene` fields + save keys, `BattleShortcuts.has_move`, `BattleArena` effects list (now "Skill:" rows, real time only), `BattleNet` intent, `BattleNetProtocol.INTENT_HERO_POWER` / `encode_hero_power`.
- Heal techniques capped at the "≤ 9" technique rule (Restoration 9, Overgrowth 8 / 1 s / ↻ 16 s).
- Tests: skill-tree technique table, unlock deals the card, v48 migration; ladder / count tests scoped to trainer techniques; hero-power protocol test removed.

## Documentation Updates

- `skill-trees.md` (fields, effect types, battle integration), `combat-model.md`, `battle-system.md`, `multiplayer-coop.md`, CLAUDE.md module table.
