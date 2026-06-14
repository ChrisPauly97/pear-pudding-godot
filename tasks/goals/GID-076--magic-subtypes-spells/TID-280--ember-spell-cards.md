# TID-280: Ember Spell Cards — 10 `.tres` Files

**Goal:** GID-076
**Type:** agent
**Status:** pending
**Depends On:** TID-279

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Create the 10 Ember-branch spell card resources. Ember is fire/burn/tempo — deals direct damage, applies poison burns, speeds up minions, and scales into large AoE.

## Research Notes

### File conventions
- Path: `data/cards/<id>.tres`
- UID sidecar: `data/cards/<id>.tres.uid` containing `uid://<12 random alphanumeric chars>`
- Generate UID: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`
- Template (spell card):

```
[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/CardData.gd" id="1_carddata"]

[resource]
script = ExtResource("1_carddata")
id = "<id>"
display_name = "<Name>"
description = "<flavour>"
cost = <N>
attack = 0
health = 0
card_class = "spell"
magic_type = "light"
magic_branch = "ember"
spell_effect = "<effect>"
spell_power = <N>
```

### Existing Ember spells to avoid duplicating
`spark` (cost 1, deal_damage_single 1), `flicker` (cost 2, deal_damage_all 1), `ember` (cost 3, deal_damage_single 3), `scorch` (cost 5, deal_damage_single 5)

### 10 New Ember Spells

| ID | Display Name | Cost | Effect | Power | Description |
|---|---|---|---|---|---|
| `ember_cinder` | Cinderspark | 1 | `deal_damage_hero` | 2 | A cinder of flame strikes the enemy hero. |
| `ember_flame_lance` | Flame Lance | 2 | `deal_damage_single` | 3 | A piercing bolt of fire. |
| `ember_brand` | Searing Brand | 2 | `apply_poison_single` | 2 | Burns a minion — it takes 2 fire damage each turn. |
| `ember_rush` | Ember Rush | 3 | `grant_surge` | 0 | Flood a minion with fire, letting it strike immediately. |
| `ember_heat_wave` | Heat Wave | 3 | `deal_damage_all` | 2 | A wave of heat scorches all enemy minions. |
| `ember_backdraft` | Backdraft | 3 | `deal_damage_hero` | 4 | An explosive backblast hits the enemy hero for 4. |
| `ember_wildfire` | Wildfire | 3 | `deal_damage_random` | 4 | Uncontrolled fire strikes a random enemy for 4. |
| `ember_fury` | Ember Fury | 4 | `double_attack` | 0 | A minion burns with fury, attacking twice this turn. |
| `ember_molten_fury` | Molten Fury | 5 | `buff_attack_all` | 2 | Molten energy floods your minions, granting +2 attack. |
| `ember_solar_flare` | Solar Flare | 6 | `deal_damage_all` | 5 | A blinding burst of solar fire deals 5 to all enemies. |

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
