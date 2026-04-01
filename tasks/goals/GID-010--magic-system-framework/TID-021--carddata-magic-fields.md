# TID-021: Extend CardData with Magic Fields

**Goal:** GID-010
**Type:** agent
**Status:** done
**Depends On:** TID-020

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`CardData.gd` currently only models minions (attack, health, card_class="minion"). The magic system introduces **Card / Spell** types: they have a mana cost and an effect, but no board-slot stats. Two new categorisation fields are needed (`magic_type`, `magic_branch`) and `card_class` must support `"spell"` as a value.

Existing cards (Ghost, Skeleton, Zombie, Ghoul) must continue to load without changes — new fields default to `""`.

## Research Notes

- `data/CardData.gd` — the resource script for all cards
- `data/cards/*.tres` — four existing card files; none need editing (new fields default to `""`)
- `autoloads/CardRegistry.gd` — loads all `.tres` from `data/cards/`; no changes needed there
- `game_logic/battle/CardInstance.gd` — wraps a CardData; check whether `attack`/`health` access needs guarding for spells
- `to_template_dict()` must include new fields so any downstream dict consumer (CardInstance, BattleScene) can read them

## Plan

_Written during Plan phase._

1. Add to `data/CardData.gd`:
   - `@export var magic_type: String = ""` — `"light"` | `"dark"` | `""` (non-magic cards)
   - `@export var magic_branch: String = ""` — `"ember"` | `"dawn"` | `"dusk"` | `"ash"` | `""`
   - `@export var spell_effect: String = ""` — canonical effect key (e.g. `"deal_damage_single"`, `"deal_damage_all"`, `"debuff_attack"`, `"destroy_low_hp"`, `"resurrect_last"`) for the battle engine to dispatch on
   - `@export var spell_power: int = 0` — numeric parameter for the effect (damage amount, stat reduction, etc.)
2. Update `to_template_dict()` to include all four new fields.
3. Review `CardInstance.gd` — ensure `attack` and `health` are not accessed unsafely for spell cards (they will be 0 by default, which is safe for the current engine).

## Changes Made

- `data/CardData.gd`: added four `@export` fields — `magic_type: String`, `magic_branch: String`, `spell_effect: String`, `spell_power: int` — all defaulting to `""` / `0` so existing minion `.tres` files load unchanged.
- `data/CardData.gd`: updated `to_template_dict()` to include all four new fields.
- `game_logic/battle/CardInstance.gd`: added matching instance variables (`magic_type`, `magic_branch`, `spell_effect`, `spell_power`) and populated them in `from_template()`. Existing attack/health access for minions is unaffected (spell cards default to 0, which is safe).

## Documentation Updates

- `docs/agent/battle-system.md`: expanded Card Data section with all new spell fields and their semantics; updated Asset Requirements table row for card data resources.
