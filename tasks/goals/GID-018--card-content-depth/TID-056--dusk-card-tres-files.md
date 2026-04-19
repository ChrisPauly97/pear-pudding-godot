# TID-056: Create Dusk Branch Card .tres Files

**Goal:** GID-018
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
