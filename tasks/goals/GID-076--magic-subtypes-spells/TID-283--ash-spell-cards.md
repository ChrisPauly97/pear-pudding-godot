# TID-283: Ash Spell Cards — 10 `.tres` Files

**Goal:** GID-076
**Type:** agent
**Status:** pending
**Depends On:** TID-279

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Create the 10 Ash-branch spell card resources. Ash is decay/undeath/destruction — poisons enemies over time, raises skeleton tokens, reinforces undead minions, and ends with a massive AoE that hits everything including the hero.

## Research Notes

### File conventions
Same `.tres` template with `magic_type = "dark"` and `magic_branch = "ash"`.

### Existing Ash spells to avoid duplicating
`ash` (cost 1, debuff_attack 2), `brittle` (cost 2, deal_damage_single 2), `char` (cost 3, destroy_low_hp 3), `alight` (cost 4, resurrect_last 1)

### 10 New Ash Spells

| ID | Display Name | Cost | Effect | Power | Description |
|---|---|---|---|---|---|
| `ash_rot` | Rot | 1 | `apply_poison_single` | 1 | A minion begins to decay — takes 1 damage each turn. |
| `ash_desecrate` | Desecrate | 2 | `deal_damage_all` | 1 | Dark energy desecrates all enemy minions for 1. |
| `ash_plague` | Plague Cloud | 3 | `apply_poison_all` | 1 | A cloud of plague settles — all enemy minions decay for 1/turn. |
| `ash_bone_spear` | Bone Spear | 3 | `deal_damage_single` | 4 | A shard of bone pierces a single target for 4. |
| `ash_raise_dead` | Raise Dead | 3 | `summon_token` | 2 | Raise two 1/1 Skeleton tokens from the grave. |
| `ash_wither_away` | Wither Away | 3 | `destroy_low_hp` | 3 | Wither away all enemy minions with 3 or less HP. |
| `ash_defile` | Defile | 4 | `curse_minion` | 4 | Defile a minion — its attack and HP each fall by 4. |
| `ash_bone_wall` | Bone Wall | 4 | `buff_health_all` | 3 | Reinforce your minions with bone — each gains +3 health. |
| `ash_mass_decay` | Mass Decay | 5 | `apply_poison_all` | 2 | Accelerated plague — all enemy minions decay for 2/turn. |
| `ash_annihilate` | Annihilate | 6 | `deal_damage_all_full` | 4 | Annihilate everything — deal 4 to all enemy minions and their hero. |

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
