# TID-255: Scene Transition Fades

**Goal:** GID-070
**Type:** agent
**Status:** done
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

New `autoloads/TransitionManager.gd` CanvasLayer (layer 100, `PROCESS_MODE_ALWAYS`) with a full-screen black `ColorRect`. Exposes `transition(change_fn: Callable)` that fades out, calls `change_fn`, awaits one process frame, then fades in. Tweens use `TWEEN_PAUSE_PROCESS` so they survive `get_tree().paused = true`. Wrap every `change_scene_to_*` call in `SceneManager.gd` inside a transition lambda. Register in `project.godot` `[autoload]`.

## Changes Made

- **NEW `autoloads/TransitionManager.gd`**: CanvasLayer at layer 100 with `PROCESS_MODE_ALWAYS`. `ColorRect` covers full screen, starts fully transparent, `MOUSE_FILTER_IGNORE`. `transition(change_fn)` fire-and-forget: fades to black (0.2s), calls change_fn, awaits process frame, fades back in. `_transitioning` guard prevents overlapping transitions. Both tweens set to `TWEEN_PAUSE_PROCESS`.
- **MODIFIED `autoloads/SceneManager.gd`**: All scene-swap calls (go_to_menu, go_to_menu_direct, _load_world, _restore_world, _on_enemy_engaged, _on_duel_requested, _on_battle_lost, _on_puzzle_requested) wrapped in `TransitionManager.transition(func() -> void: ...)` lambdas. State assignments (e.g. `_state = State.WORLD`) moved inside lambdas to avoid race conditions where state said WORLD before the world was active. Achievement unlock adds haptic call on Android.
- **MODIFIED `project.godot`**: Added `TransitionManager="*res://autoloads/TransitionManager.gd"` to `[autoload]`.

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md` — TransitionManager section added.
