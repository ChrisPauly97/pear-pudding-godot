# TID-054: Implement New Spell Effect Handlers

**Goal:** GID-018
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The magic system framework (GID-010) defined the `spell_effect` field on CardData and implemented 6 handlers: `deal_damage_single`, `deal_damage_all`, `deal_damage_random`, `debuff_attack`, `destroy_low_hp`, `resurrect_last`. Dawn and Dusk branches require 8 additional effect types. This task implements those handlers before card .tres files are created (TID-055, TID-056 depend on this).

## Research Notes

- Spell effect dispatch lives in `scenes/battle/BattleScene.gd` — search for `_resolve_spell` or `spell_effect`
- `game_logic/battle/GameState.gd` holds game state; `PlayerState.gd` holds per-player state (hand, board, hero HP, mana)
- `game_logic/battle/HeroState.gd` holds hero HP and attack
- `game_logic/battle/ZoneState.gd` holds a board slot (card + summoning_sick + attacked flags)
- `data/cards/*.tres` use `CardData` resource with fields: id, cost, attack, health, magic_type, magic_branch, spell_effect, spell_power, auto_resolve, card_class
- Existing `debuff_attack` reduces a minion's attack — use same pattern for `curse_minion` (reduce both attack and health)
- `resurrect_last` reads the discard pile — use same pattern for `draw_card`
- For `shield_minion` (armor): store an `armor` int on `ZoneState`; damage is reduced by armor before applying to health
- For `lifesteal_hit`: deal damage to one enemy minion AND heal the player hero by the same amount
- For `mana_drain`: reduce enemy's current mana (not max) by spell_power; floor at 0
- Strict mode: use explicit type annotations; avoid `:=` with Variant-returning expressions

**New effect types needed:**

| Effect ID | Target | Description |
|---|---|---|
| `heal_single` | friendly minion | Restore spell_power HP to one friendly minion (cap at max_health) |
| `heal_all` | all friendly minions | Restore spell_power HP to every friendly minion |
| `shield_minion` | friendly minion | Add spell_power armor to one friendly minion |
| `buff_attack` | friendly minion | Increase attack of one friendly minion by spell_power |
| `lifesteal_hit` | enemy minion | Deal spell_power damage to one enemy minion; heal player hero by same amount |
| `mana_drain` | enemy player | Reduce enemy current mana by spell_power |
| `curse_minion` | enemy minion | Reduce target enemy minion attack and health by spell_power |
| `draw_card` | self | Player draws spell_power additional cards from their deck |

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
