# TID-111: SkillData Resource, SkillRegistry & Skill Content

**Goal:** GID-030
**Type:** agent
**Status:** done
**Depends On:** TID-110

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Before any skill logic can be wired into BattleScene or the UI, the data shape must exist. This task defines `SkillData.gd`, creates `SkillRegistry.gd` (same pattern as `WeaponRegistry`), and authors 10 skill `.tres` files — a mix of passives and actives — with `.uid` sidecars.

## Research Notes

**SkillData.gd** (new file at `data/SkillData.gd`):
```gdscript
extends Resource
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## "passive" or "active"
@export var skill_type: String = "passive"
## Passive effect types: "passive_hp", "passive_mana", "passive_atk", "passive_draw"
## Active effect types: "active_damage_all", "active_heal", "active_draw", "active_mana"
@export var effect_type: String = ""
@export var effect_value: int = 0
## IDs of skills that must be unlocked before this one can be unlocked.
@export var prerequisites: Array[String] = []
## Row and column in the skill tree grid (for UI positioning).
@export var tree_row: int = 0
@export var tree_col: int = 0
```

**SkillRegistry.gd** (new autoload at `autoloads/SkillRegistry.gd`):
- Same lazy-load pattern as `WeaponRegistry`.
- Scans `data/skills/` for `.tres` files, loads as `SkillData`, indexes by `id`.
- API: `get_skill(id)`, `get_all_ids()`, `get_by_type(skill_type: String) -> Array[String]`
- Register in `project.godot` autoloads section.

**10 skills to create** in `data/skills/`:

Passives (row 0-1):
| ID | display_name | effect_type | value | prerequisites | row | col |
|---|---|---|---|---|---|---|
| tough_skin | Tough Skin | passive_hp | +8 | [] | 0 | 0 |
| keen_mind | Keen Mind | passive_draw | +1 | [] | 0 | 2 |
| battle_focus | Battle Focus | passive_mana | +1 | [] | 0 | 4 |
| iron_will | Iron Will | passive_hp | +15 | [tough_skin] | 1 | 0 |
| swift_hand | Swift Hand | passive_draw | +1 | [keen_mind] | 1 | 2 |
| arcane_surge | Arcane Surge | passive_mana | +2 | [battle_focus] | 1 | 4 |

Actives (row 2):
| ID | display_name | effect_type | value | prerequisites | row | col |
|---|---|---|---|---|---|---|
| battle_cry | Battle Cry | active_damage_all | 2 | [tough_skin] | 2 | 0 |
| healing_touch | Healing Touch | active_heal | 6 | [tough_skin] | 2 | 1 |
| flash_draw | Flash Draw | active_draw | 2 | [keen_mind] | 2 | 2 |
| mana_surge | Mana Surge | active_mana | 3 | [battle_focus] | 2 | 4 |

**Passive effect semantics** (for TID-112):
- `passive_hp`: adds value to `hero.health` and `hero.max_health` at battle start
- `passive_mana`: adds value to turn-1 mana (same as `starting_mana` weapon effect)
- `passive_atk`: adds value to `hero.attack`
- `passive_draw`: player draws extra cards on opening hand

**Active effect semantics** (for TID-113):
- `active_damage_all`: deals `effect_value` damage to every enemy minion on the board
- `active_heal`: restores `effect_value` HP to player hero (capped at max_health)
- `active_draw`: player draws `effect_value` cards immediately
- `active_mana`: grants `effect_value` bonus mana for the current turn

**UID generation per file:**
```bash
python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"
```
Run once per `.tres` file and once per `.tres.uid` file.

**Note:** `class_name` will not be globally available — use `preload("res://data/SkillData.gd")` in `SkillRegistry.gd` instead of referencing `SkillData` directly.

## Plan

1. Create `data/SkillData.gd` + `.gd.uid` sidecar.
2. Create `autoloads/SkillRegistry.gd` + `.gd.uid` — static class, same pattern as WeaponRegistry (no autoload entry needed).
3. Create `data/skills/` directory with 10 skill `.tres` files and `.tres.uid` sidecars.

## Changes Made

- `data/SkillData.gd` + `data/SkillData.gd.uid`: new Resource subclass with id, display_name, description, skill_type, effect_type, effect_value, prerequisites, tree_row, tree_col
- `autoloads/SkillRegistry.gd` + `autoloads/SkillRegistry.gd.uid`: static lazy-loading registry scanning `data/skills/`; API: `get_skill(id)`, `get_all_ids()`, `get_by_type(skill_type)`
- `data/skills/`: 10 skill `.tres` files with `.uid` sidecars — 6 passives (tough_skin, keen_mind, battle_focus, iron_will, swift_hand, arcane_surge) and 4 actives (battle_cry, healing_touch, flash_draw, mana_surge)

## Documentation Updates

No separate agent doc created; skill system documented inline in task and will be referenced by TID-112/113/114.
