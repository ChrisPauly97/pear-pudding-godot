# TID-255: Scene Transition Fades

**Goal:** GID-070
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every scene change is currently a hard cut: `SceneManager` calls `get_tree().change_scene_to_packed()` / `change_scene_to_node()` directly. Hard cuts are the single biggest "prototype" tell in the game. This task adds a global fade-to-black/fade-in driven by SceneManager so all transitions (world ↔ battle ↔ inventory ↔ menus ↔ map changes) inherit it automatically.

## Research Notes

- `autoloads/SceneManager.gd` — owns all scene routing and the map stack. All transitions funnel through it, so wrapping its scene-change calls covers the whole game.
- Implement as a new autoload (e.g. `autoloads/TransitionManager.gd`) holding a full-screen `ColorRect` on a high `CanvasLayer` (layer 100+) with `mouse_filter = MOUSE_FILTER_IGNORE` when idle and blocking input mid-transition.
- Use a `Tween` on the ColorRect alpha: fade out (~0.2s), await, swap scene, fade in (~0.2s). Expose `await TransitionManager.fade_out()` / `fade_in()` so SceneManager can await them.
- SceneManager methods are mostly synchronous today; converting call sites to async needs care — prefer keeping SceneManager's public API unchanged and making the internals async.
- Battle overlay push/pop also goes through SceneManager — decide whether the overlay transition uses the same fade or a quicker one.
- New autoload must be registered in `project.godot` `[autoload]` section.
- Per CLAUDE.md: GDScript strict mode — annotate types explicitly where RHS returns Variant; UI sizing relative to viewport (ColorRect uses full-rect anchors, so no fixed pixels involved).
- The screen-shake-respecting pause logic in `scenes/battle/BattleScene.gd` shows the existing overlay/tween idioms to match.
- TID-260 adds a comfort setting that may later expose transition speed; keep durations as named constants.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
