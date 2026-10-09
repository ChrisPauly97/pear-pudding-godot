# TID-734: Skill .tres re-authored; actives → technique cards; hero power removed

**Goal:** GID-179
**Type:** agent
**Status:** todo
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

_TBD._

## Changes Made

_TBD._

## Documentation Updates

_TBD._
