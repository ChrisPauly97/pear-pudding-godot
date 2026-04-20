# TID-056: Create Dusk Branch Card .tres Files

**Goal:** GID-018
**Type:** agent
**Status:** done
**Depends On:** TID-054

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Dusk branch represents dark/lifesteal/drain magic — the aggressive counterpart to Dawn. This task creates the .tres card resources and their .uid sidecars. Spell effect handlers must exist first (TID-054).

## Research Notes

- Same .tres format and .uid sidecar requirement as TID-055 (see that task's Research Notes)
- `magic_type`: `"dusk"`, `magic_branch`: `"shadow"`
- Dusk spells are aggressive: they damage, drain, or curse enemy minions

**Planned Dusk cards (8 total):**

| ID | Display Name | Cost | Attack | Health | Class | Spell Effect | Spell Power |
|---|---|---|---|---|---|---|---|
| dusk_wraith | Dusk Wraith | 2 | 2 | 2 | minion | — | 0 |
| dusk_vampire | Dusk Vampire | 4 | 3 | 3 | minion | — | 0 |
| drain | Drain | 2 | 0 | 0 | spell | lifesteal_hit | 3 |
| wither | Wither | 1 | 0 | 0 | spell | curse_minion | 1 |
| siphon | Siphon | 3 | 0 | 0 | spell | mana_drain | 3 |
| shadow_bolt | Shadow Bolt | 2 | 0 | 0 | spell | deal_damage_single | 4 |
| soul_rend | Soul Rend | 4 | 0 | 0 | spell | lifesteal_hit | 5 |
| dark_pact | Dark Pact | 3 | 0 | 0 | spell | curse_minion | 2 |

## Plan

Create 8 .tres files and 8 .uid sidecars in `data/cards/` following ember.tres format. Use `magic_type = "dark"`, `magic_branch = "dusk"` (research notes had these swapped vs actual CardData schema), Color(0.5, 0.2, 0.7, 1) (deep purple). For spell cards: attack=0, health=0. For minion cards: no spell_effect/spell_power.

## Changes Made

Created 8 Dusk card .tres files and 8 .uid sidecars in `data/cards/`:
- `dusk_wraith.tres` — 2-cost minion (2/2), dark/dusk
- `dusk_vampire.tres` — 4-cost minion (3/3), dark/dusk
- `drain.tres` — 2-cost spell, lifesteal_hit 3
- `wither.tres` — 1-cost spell, curse_minion 1
- `siphon.tres` — 3-cost spell, mana_drain 3
- `shadow_bolt.tres` — 2-cost spell, deal_damage_single 4
- `soul_rend.tres` — 4-cost spell, lifesteal_hit 5
- `dark_pact.tres` — 3-cost spell, curse_minion 2

Note: Used `magic_type = "dark"`, `magic_branch = "dusk"` (research notes had these reversed vs actual CardData schema; same correction as TID-055).

## Documentation Updates

No doc changes needed.
