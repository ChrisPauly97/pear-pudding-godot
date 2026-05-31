# TID-120: Stub Corruption/Redemption Earn Hooks

**Goal:** GID-031
**Type:** agent
**Status:** pending
**Depends On:** TID-116

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The actual dialogue wiring for earning corruption/redemption points is deferred (dialogue system is extended in a future goal). This task installs the plumbing — SaveManager earn methods + GameBus signals — so future tasks can just call `save_manager.add_corruption_points(1)` at dialogue choice sites without any further infrastructure work.

## Research Notes

**SaveManager additions** (`autoloads/SaveManager.gd`):
```gdscript
func add_corruption_points(amount: int) -> void:
    corruption_points += amount
    _dirty = true
    GameBus.corruption_points_changed.emit(corruption_points)

func add_redemption_points(amount: int) -> void:
    redemption_points += amount
    _dirty = true
    GameBus.redemption_points_changed.emit(redemption_points)
```

**GameBus additions** (`autoloads/GameBus.gd`):
```gdscript
signal corruption_points_changed(new_amount: int)
signal redemption_points_changed(new_amount: int)
```

**Design note on earning:** Dark dialogue choices earn corruption points; light dialogue choices earn redemption points. This is symmetric and player-agnostic — both currencies are available to any player. The currency that matters for cross-magic purchasing depends on the player's home magic type (see TID-119 research notes).

**No callers yet.** These methods are only called by dialogue scripts in a future goal. No wiring to existing dialogue scenes in this task.

**Files to modify:**
- `autoloads/GameBus.gd`
- `autoloads/SaveManager.gd`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
