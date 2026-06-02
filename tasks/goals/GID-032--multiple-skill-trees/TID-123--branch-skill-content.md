# TID-123: Create 24 Branch-Specific Skill .tres Files

**Goal:** GID-032
**Type:** agent
**Status:** done
**Depends On:** TID-122

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Replace the 10 generic skills with 24 branch-themed skills — 6 per branch. Each branch's skills reinforce its card identity. A few skills per branch are tagged with `alt_cost > 0` and are designed to be genuinely useful to players of the opposing magic type.

## Research Notes

**Branch identities (from `data/CardData.gd` and `docs/agent/magic-system.md`):**
- **ember** (light) — aggressive direct damage, attack boosts
- **dawn** (light) — healing, card draw, mana restoration
- **dusk** (dark) — lifesteal, drain, mana disruption
- **ash** (dark) — disruption, debuffs, necromancy (resurrection, curse)

**Grid layout per branch:** Each branch owns its own 3-row × 5-col space (same coordinate system as before, reused independently per branch). Suggested positions: row 0 = entry (no prereqs), row 1 = mid (require row 0), row 2 = capstone (require row 1).

**Skill ID convention:** prefix with branch name, e.g. `ember_searing_focus`, `dawn_wellspring`, `dusk_soul_rend`, `ash_brittle_curse`.

**Suggested skill roster:**

*Ember (6 skills):*
| id | display_name | type | effect_type | value | prereqs | row,col | alt_cost |
|----|--------------|------|-------------|-------|---------|---------|----------|
| ember_searing_focus | Searing Focus | passive | passive_atk | 1 | — | 0,0 | 0 |
| ember_torch_bearer | Torch Bearer | passive | passive_mana | 1 | — | 0,3 | 0 |
| ember_inferno_surge | Inferno Surge | passive | passive_atk | 2 | ember_searing_focus | 1,0 | 0 |
| ember_flame_tempo | Flame Tempo | passive | passive_draw | 1 | ember_torch_bearer | 1,3 | 0 |
| ember_pyroblast | Pyroblast | active | active_damage_all | 3 | ember_inferno_surge | 2,0 | 2 |
| ember_blazing_draw | Blazing Draw | active | active_draw | 3 | ember_flame_tempo | 2,3 | 0 |

*Dawn (6 skills):*
| id | display_name | type | effect_type | value | prereqs | row,col | alt_cost |
|----|--------------|------|-------------|-------|---------|---------|----------|
| dawn_inner_light | Inner Light | passive | passive_hp | 8 | — | 0,0 | 0 |
| dawn_wellspring | Wellspring | passive | passive_mana | 1 | — | 0,3 | 0 |
| dawn_radiant_shield | Radiant Shield | passive | passive_hp | 15 | dawn_inner_light | 1,0 | 0 |
| dawn_clarity | Clarity | passive | passive_draw | 1 | dawn_wellspring | 1,3 | 0 |
| dawn_restoration | Restoration | active | active_heal | 8 | dawn_radiant_shield | 2,0 | 2 |
| dawn_arcane_clarity | Arcane Clarity | active | active_draw | 2 | dawn_clarity | 2,3 | 2 |

*Dusk (6 skills):*
| id | display_name | type | effect_type | value | prereqs | row,col | alt_cost |
|----|--------------|------|-------------|-------|---------|---------|----------|
| dusk_dark_pact | Dark Pact | passive | passive_atk | 1 | — | 0,0 | 0 |
| dusk_shadow_well | Shadow Well | passive | passive_mana | 1 | — | 0,3 | 0 |
| dusk_lifetap | Lifetap | passive | passive_hp | 10 | dusk_dark_pact | 1,0 | 0 |
| dusk_void_tempo | Void Tempo | passive | passive_draw | 1 | dusk_shadow_well | 1,3 | 0 |
| dusk_soul_siphon | Soul Siphon | active | active_heal | 6 | dusk_lifetap | 2,0 | 2 |
| dusk_mana_drain | Mana Drain | active | active_mana | 3 | dusk_void_tempo | 2,3 | 0 |

*Ash (6 skills):*
| id | display_name | type | effect_type | value | prereqs | row,col | alt_cost |
|----|--------------|------|-------------|-------|---------|---------|----------|
| ash_cinderheart | Cinderheart | passive | passive_hp | 8 | — | 0,0 | 0 |
| ash_entropy | Entropy | passive | passive_atk | 1 | — | 0,3 | 0 |
| ash_bone_armour | Bone Armour | passive | passive_hp | 15 | ash_cinderheart | 1,0 | 0 |
| ash_brittle_edge | Brittle Edge | passive | passive_atk | 2 | ash_entropy | 1,3 | 0 |
| ash_brittle_curse | Brittle Curse | active | active_damage_all | 2 | ash_brittle_edge | 2,3 | 2 |
| ash_grave_call | Grave Call | active | active_draw | 2 | ash_bone_armour | 2,0 | 0 |

**Cross-magic design intent (alt_cost > 0 skills):**
- `ember_pyroblast` (damage all 3) — dark players want AoE damage output they lack
- `dawn_restoration` (heal 8) — dark players lack healing; a safety valve for lifesteal builds
- `dawn_arcane_clarity` (draw 2) — dark players want card draw to fuel disruption combos
- `dusk_soul_siphon` (heal 6 active) — light players can use lifesteal as a second heal option
- `ash_brittle_curse` (damage_all 2) — light players want cheap AoE to set up lethal turns

**Removing old skills:** Delete all 10 files in `data/skills/` (tough_skin, battle_focus, etc.) before writing the new ones. Old IDs in `unlocked_skills` save arrays will be silently ignored — `has_skill` checks the array, and `SkillRegistry.get_skill` returns null for missing IDs, which the passive application loop already handles gracefully.

**`.uid` sidecar requirement (from CLAUDE.md):** Generate a random 12-char uid for every new `.tres` file:
```bash
python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"
```

**Files to create:** 24 `.tres` + 24 `.tres.uid` files in `data/skills/`.
**Files to delete:** The 10 old `data/skills/*.tres` and `data/skills/*.tres.uid` files.

## Plan

1. Delete 10 old generic `.tres` + `.uid` files from `data/skills/`.
2. Write 24 new `.tres` files and 24 `.uid` sidecars via a Python script using the roster from Research Notes.

## Changes Made

- Deleted `data/skills/` old files: `tough_skin`, `battle_focus`, `keen_mind`, `iron_will`, `swift_hand`, `arcane_surge`, `battle_cry`, `healing_touch`, `flash_draw`, `mana_surge` (10 × .tres + .uid = 20 files removed).
- Created 24 `.tres` + 24 `.tres.uid` files in `data/skills/`:
  - **Ember** (4 passive + 2 active): `ember_searing_focus`, `ember_torch_bearer`, `ember_inferno_surge`, `ember_flame_tempo`, `ember_pyroblast` (alt_cost=2), `ember_blazing_draw`
  - **Dawn** (4 passive + 2 active): `dawn_inner_light`, `dawn_wellspring`, `dawn_radiant_shield`, `dawn_clarity`, `dawn_restoration` (alt_cost=2), `dawn_arcane_clarity` (alt_cost=2)
  - **Dusk** (4 passive + 2 active): `dusk_dark_pact`, `dusk_shadow_well`, `dusk_lifetap`, `dusk_void_tempo`, `dusk_soul_siphon` (alt_cost=2), `dusk_mana_drain`
  - **Ash** (4 passive + 2 active): `ash_cinderheart`, `ash_entropy`, `ash_bone_armour`, `ash_brittle_edge`, `ash_brittle_curse` (alt_cost=2), `ash_grave_call`
- All files include `magic_branch` and `alt_cost` fields; prerequisites correctly reference branch-prefixed IDs.

## Documentation Updates

No agent docs updated in this task — TID-127 covers documentation for the full goal.
