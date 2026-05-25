# TID-107: New Equipment Content

**Goal:** GID-029
**Type:** agent
**Status:** pending
**Depends On:** TID-106

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-106 adds the `slot` field to `WeaponData`. This task creates the actual armor, ring, and trinket items using that field so TID-108 and TID-109 have real equipment to display and award.

## Research Notes

**Existing weapons for reference** (`data/weapons/`):
| ID | Effect type | Value |
|---|---|---|
| rusty_dagger | deck_inject | 3× dagger_throw |
| berserker_axe | passive_atk | +3 |
| dawn_staff | deck_inject | dawn cards |
| dusk_blade | deck_inject | dusk cards |
| ember_wand | starting_mana | +2 |
| iron_shield | starting_hp | +8 |
| mana_crystal | starting_mana | +3 |

**Items to create:**

Armor (slot = "armor") — maps naturally to `starting_hp` and defensive effects:
| ID | display_name | battle_effect_type | value |
|---|---|---|---|
| leather_vest | Leather Vest | starting_hp | +6 |
| chainmail | Chainmail | starting_hp | +12 |
| warded_cloak | Warded Cloak | starting_hp | +4 (+ future ward keyword) |

Ring (slot = "ring") — mana and draw effects:
| ID | display_name | battle_effect_type | value |
|---|---|---|---|
| ring_of_focus | Ring of Focus | starting_mana | +1 |
| scholar_band | Scholar's Band | deck_inject | 2× a new "insight" 0-cost auto-resolve draw card |
| obsidian_loop | Obsidian Loop | passive_atk | +2 |

Trinket (slot = "trinket") — miscellaneous utility:
| ID | display_name | battle_effect_type | value |
|---|---|---|---|
| lucky_coin | Lucky Coin | starting_mana | +2 |
| bone_charm | Bone Charm | passive_atk | +1 |
| ember_flask | Ember Flask | deck_inject | 3× dagger_throw (same as rusty_dagger, thematic variant) |

**File format** — copy from an existing `.tres`:
```
[gd_resource type="WeaponData" script_class="WeaponData" load_steps=2 format=3 uid="uid://..."]
[ext_resource type="Script" path="res://data/WeaponData.gd" id="1_xxxxx"]
[resource]
script = ExtResource("1_xxxxx")
id = "leather_vest"
display_name = "Leather Vest"
description = "A worn but reliable vest."
slot = "armor"
battle_effect_type = "starting_hp"
battle_effect_value = 6
injected_card_id = ""
injected_card_count = 0
```

**UID generation:** for each file run:
```bash
python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"
```

**Location:** all files go in `data/weapons/` — WeaponRegistry already scans this directory.

**scholar_band** injects an "insight" card — this requires creating `data/cards/insight.tres` (cost=0, auto_resolve=true, spell_effect="draw_card", spell_power=1) with a `.uid` sidecar if that card doesn't already exist. Check `data/cards/` first.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
