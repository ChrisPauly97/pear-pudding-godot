# TID-011: Wire World Exploration Sound Effects

**Goal:** GID-004
**Type:** agent
**Status:** pending
**Depends On:** TID-009

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The world scene needs audio feedback for key player interactions: enemy encounters, chest opens, door traversal, and footsteps. All calls go through `AudioManager.play_sfx()`.

## Research Notes

**SFX to wire:**

| Event | Where to hook | SFX name |
|---|---|---|
| Enemy engaged | `GameBus.enemy_engaged` handler in `WorldScene` or `EnemyNPC` | `"enemy_engage"` |
| Chest opened | `Chest.gd` when the chest triggers its open action | `"chest_open"` |
| Door entered | `WorldScene` / `Door.gd` when door traversal fires | `"door_enter"` |
| Footstep | `Player.gd` `_process()` when player is moving, throttled | `"footstep"` |

**Enemy engage hook:**
- Cleanest place: `EnemyNPC.gd` in the Engage state transition, just before `GameBus.enemy_engaged.emit(...)`.
- Alternatively hook in `WorldScene._on_enemy_engaged()` — read both files to choose.

**Chest open hook:**
- `Chest.gd` — find the method that fires when the player opens the chest (likely triggered by `E` key interaction via `WorldScene`). Add `AudioManager.play_sfx("chest_open")` there.

**Door enter hook:**
- `Door.gd` or `WorldScene` where `SceneManager.enter_map()` is called. Add `AudioManager.play_sfx("door_enter")` just before the transition.

**Footstep throttle:**
```gdscript
# In Player.gd _process(delta):
_footstep_timer -= delta
if velocity.length() > 0.1 and _footstep_timer <= 0.0:
    AudioManager.play_sfx("footstep")
    _footstep_timer = 0.4   # seconds between footstep sounds
```
Add `var _footstep_timer: float = 0.0` to Player. Read `Player.gd` to confirm the velocity variable name and `_process` structure before editing.

**3D vs 2D audio:**
- `AudioManager` uses `AudioStreamPlayer` (non-positional). For footsteps and enemy engage, positional audio (`AudioStreamPlayer3D`) would be more realistic but is out of scope for this foundation task. Non-positional is fine for v1.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
