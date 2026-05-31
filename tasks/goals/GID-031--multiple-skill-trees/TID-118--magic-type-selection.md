# TID-118: Player Magic Type Selection Flow

**Goal:** GID-031
**Type:** agent
**Status:** pending
**Depends On:** TID-116

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players must pick a home magic type (light or dark) before their skill trees can be shown. This is a one-time, permanent choice stored in `SaveManager.magic_type`. The selection modal appears the first time the player opens the skill tree if the field is still `""`.

## Research Notes

**Where to trigger:** `SkillTreeScene._ready()` — if `SceneManager.save_manager.magic_type == ""`, show the choice modal before building the normal tree UI. The modal blocks interaction with the skill tree until a choice is made.

**Modal design:**
- Full-screen dark overlay (same pattern as `SkillTreeScene._build_ui()` background rect)
- Title: "Choose Your Path"
- Two large buttons side by side: "Light" and "Dark"
- Short flavour line under each:
  - Light: "Ember & Dawn — fire, healing, and clarity"
  - Dark: "Dusk & Ash — shadow, drain, and disruption"
- No cancel option — this choice is required to proceed
- On confirm: call `SceneManager.save_manager.set_magic_type(choice)` (or direct assignment + `save_manager.save()`), hide the modal, rebuild the tree UI

**SaveManager method:**
```gdscript
func set_magic_type(t: String) -> void:
    magic_type = t
    _dirty = true
```
(No signal needed — this fires once, and SkillTreeScene reads the value synchronously after.)

**Magic type → branch mapping** (used by TID-119 UI):
```gdscript
const MAGIC_BRANCHES: Dictionary = {
    "light": ["ember", "dawn"],
    "dark":  ["dusk",  "ash"],
}
```
Define this const inside `SkillTreeScene` — no need to add it to IsoConst.

**Opposing magic** (used for cross-magic tab in TID-119):
```gdscript
func _opposing_magic(mt: String) -> String:
    return "dark" if mt == "light" else "light"
```

**Files to modify:**
- `autoloads/SaveManager.gd` — add `set_magic_type()`
- `scenes/ui/SkillTreeScene.gd` — add modal flow in `_ready()`/`_build_ui()`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
