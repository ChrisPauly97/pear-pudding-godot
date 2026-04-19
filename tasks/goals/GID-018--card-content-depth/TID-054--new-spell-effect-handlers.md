# TID-054: Implement New Spell Effect Handlers

**Goal:** GID-018
**Type:** agent
**Status:** done
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

1. **`CardInstance.gd`** — Add `var armor: int = 0` field. Add `func take_damage(dmg: int) -> void` that subtracts `maxi(0, dmg - armor)` from health, flooring at 0. This makes shield_minion's armor reduction apply consistently to all damage sources.

2. **`BattleScene.gd` combat damage** — Replace all `target.health -= X` / `attacker.health -= X` direct writes with calls to `target.take_damage(X)` / `attacker.take_damage(X)` so armor is respected in combat.

3. **`ai/BasicAI.gd` combat damage** — Same replacement for minion-vs-minion in `decide_turn`.

4. **`BattleScene.gd` `_resolve_spell_effect`** — Add 8 new `match` arms:
   - `heal_single`: first friendly minion's health += spell_power, capped at max_health
   - `heal_all`: same for all friendly minions
   - `shield_minion`: first friendly minion's armor += spell_power
   - `buff_attack`: first friendly minion's attack += spell_power
   - `lifesteal_hit`: call `take_damage(spell_power)` on first enemy minion; heal player hero by same amount (capped at max_health); remove minion if dead
   - `mana_drain`: opponent.hero.mana = maxi(0, opponent.hero.mana - spell_power)
   - `curse_minion`: reduce first enemy minion's attack and health by spell_power (attack floor 0, remove minion if health ≤ 0)
   - `draw_card`: call caster.draw_card() spell_power times

## Changes Made

- `game_logic/battle/CardInstance.gd`: Added `armor: int = 0` field and `take_damage(dmg: int)` method that reduces incoming damage by armor before applying to health.
- `scenes/battle/BattleScene.gd`: Replaced 3 direct `health -=` combat-damage writes with `take_damage()` calls; updated `deal_damage_single`, `deal_damage_all`, `deal_damage_random` handlers to use `take_damage()`; added 8 new `match` arms in `_resolve_spell_effect`: `heal_single`, `heal_all`, `shield_minion`, `buff_attack`, `lifesteal_hit`, `mana_drain`, `curse_minion`, `draw_card`.
- `ai/BasicAI.gd`: Replaced 2 direct `health -=` writes with `take_damage()` so minion armor applies in AI combat.

## Documentation Updates

- Updated `docs/agent/battle-system.md` spell_effect table to include the 8 new effect IDs.
