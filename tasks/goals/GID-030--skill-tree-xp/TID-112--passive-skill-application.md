# TID-112: Passive Skill Application

**Goal:** GID-030
**Type:** agent
**Status:** pending
**Depends On:** TID-111

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Unlocked passive skills must translate into actual battle bonuses. This task wires `SaveManager.unlocked_skills` into `BattleScene` so passives are applied to `PlayerState` at battle start, alongside existing weapon/equipment effects. It also adds `unlocked_skills` to the save schema.

## Research Notes

**SaveManager additions:**
```gdscript
var unlocked_skills: Array[String] = []
```
- No new migration version needed if TID-110 claims v12; coordinate — if v12 is taken, this backfill can be folded into the next migration or added as a no-op patch in v12 (`if not data.has("unlocked_skills"): data["unlocked_skills"] = []`).
- Add helpers:
  - `unlock_skill(id: String) -> void` — appends to `unlocked_skills`, decrements `skill_points`, queues save
  - `has_skill(id: String) -> bool`

**BattleScene additions:**
After `_apply_equipment_effects()` (from TID-106) in `_ready()`, call `_apply_passive_skills()`:
```gdscript
const SkillData = preload("res://data/SkillData.gd")

func _apply_passive_skills(player: PlayerState) -> void:
    for skill_id in SceneManager.save_manager.unlocked_skills:
        var skill: SkillData = SkillRegistry.get_skill(skill_id)
        if skill == null or skill.skill_type != "passive":
            continue
        match skill.effect_type:
            "passive_hp":
                player.hero.health += skill.effect_value
                player.hero.max_health += skill.effect_value
            "passive_mana":
                player.hero.mana = mini(player.hero.mana + skill.effect_value,
                                        player.hero.max_mana + skill.effect_value)
                player.hero.max_mana += skill.effect_value
            "passive_atk":
                player.hero.attack += skill.effect_value
            "passive_draw":
                # Draw extra cards into hand after opening hand is dealt.
                # Set a field player.bonus_draw: int; BattleScene reads it after _deal_opening_hand().
                player.bonus_draw = player.get("bonus_draw") + skill.effect_value
```

**`passive_draw` implementation detail:**
`PlayerState` may not have a `bonus_draw` field. Add `var bonus_draw: int = 0` to `game_logic/battle/PlayerState.gd`. In `BattleScene._deal_opening_hand()` (or wherever opening cards are drawn), after dealing the normal hand, draw `player.bonus_draw` additional cards.

**Files to modify:**
- `autoloads/SaveManager.gd` — add `unlocked_skills`, `unlock_skill()`, `has_skill()`
- `game_logic/battle/PlayerState.gd` — add `bonus_draw: int = 0`
- `scenes/battle/BattleScene.gd` — add `_apply_passive_skills()` call and `passive_draw` handling
- `autoloads/SkillRegistry.gd` — must be registered as autoload (done in TID-111)

**GDScript strict-mode:** `SkillData` must be `preload`ed, not referenced by class_name.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
