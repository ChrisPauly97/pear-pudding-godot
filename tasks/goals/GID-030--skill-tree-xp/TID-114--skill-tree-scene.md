# TID-114: Skill Tree Scene UI

**Goal:** GID-030
**Type:** agent
**Status:** pending
**Depends On:** TID-112, TID-113

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The skill tree UI is where players spend skill points. It must show all 10 skills as a grid of nodes, indicate locked/unlocked/available state, enforce prerequisites, and deduct skill points on unlock. It follows the same overlay pattern as CharacterScene (TID-108) and InventoryScene.

## Research Notes

**Opening mechanism:**
- `GameBus` signal: `skill_tree_requested` (no args)
- `WorldScene` emits on `InputMap` action `"skill_tree"` (key S)
- HUD: flat Button "S" beside the character button (TID-108)
- `SceneManager` instantiates `SkillTreeScene` as overlay

**Layout:**
```
VBoxContainer (full screen, dark semi-transparent background)
  HBoxContainer (top bar)
    Label "Skill Tree"
    Label "Skill Points: X"   ← reads SaveManager.skill_points
    Button "Close"
  GridContainer (cols=5, rows=3 — matches tree_row/tree_col from SkillData)
    [one SkillNode panel per skill]
```

**SkillNode panel (per skill):**
- `PanelContainer` with a `VBoxContainer` inside:
  - `Label` — display_name
  - `Label` — description (small font)
  - `Label` — effect summary ("+ 8 HP", "Hero Power: deal 2 to all", etc.)
  - `Button` "Unlock" — disabled if: already unlocked, prerequisites not met, or no skill points
- Visual states:
  - **Unlocked**: green tint or checkmark label
  - **Available** (prereqs met, points available): normal, Unlock button enabled
  - **Locked** (prereqs not met): greyed out, Unlock button disabled
  - **No points**: prereqs met but `skill_points == 0`: Unlock button disabled, tooltip "No skill points"

**Unlock flow:**
```gdscript
func _on_unlock_pressed(skill_id: String) -> void:
    if SceneManager.save_manager.skill_points <= 0:
        return
    if not _prerequisites_met(skill_id):
        return
    SceneManager.save_manager.unlock_skill(skill_id)  # added in TID-112
    _refresh()

func _prerequisites_met(skill_id: String) -> bool:
    var skill: SkillData = SkillRegistry.get_skill(skill_id)
    if skill == null:
        return false
    for prereq_id in skill.prerequisites:
        if not SceneManager.save_manager.has_skill(prereq_id):
            return false
    return true
```

**Prerequisite lines:** Draw a simple line between connected nodes using a `Line2D` or by placing arrow Labels between grid cells. Keep it simple — grid position implies the connection visually.

**SceneManager additions:**
```gdscript
var _skill_tree_scene_packed := preload("res://scenes/ui/SkillTreeScene.tscn")
var _skill_tree_overlay: Node = null
# connect GameBus.skill_tree_requested → _on_skill_tree_requested
```

**UI sizing:**
```gdscript
var _vh: float = get_viewport().get_visible_rect().size.y
node_panel.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.15)
```

**Input action:** add `"skill_tree"` mapped to `KEY_S` in `project.godot`. Check for conflicts with existing actions.

**Files to create:**
- `scenes/ui/SkillTreeScene.gd`
- `scenes/ui/SkillTreeScene.tscn` (minimal wrapper)
- `scenes/ui/SkillTreeScene.tscn.uid`

**Files to modify:**
- `autoloads/GameBus.gd` — add `signal skill_tree_requested`
- `autoloads/SceneManager.gd` — add overlay routing
- `scenes/world/WorldScene.gd` — emit `skill_tree_requested` on S key
- HUD scene/script — add Skill Tree button beside Character button

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
