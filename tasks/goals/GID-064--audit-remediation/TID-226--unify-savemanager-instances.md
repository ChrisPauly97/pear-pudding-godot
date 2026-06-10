# TID-226: Unify the split-brain SaveManager instances

**Goal:** GID-064
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Two live SaveManager instances exist: `SaveManager` is registered as an autoload in
`project.godot:28`, *and* SceneManager instantiates its own private copy at
`autoloads/SceneManager.gd:69` (`save_manager = _SaveManagerScript.new()`). All game
flow (load/new_game/save) runs on `SceneManager.save_manager`, but several scripts call
the **autoload** instance, which never has `load_save()`/`new_game()` called — its
`_loaded` flag stays false so its `save()` (SaveManager.gd:411-413) no-ops forever.

Player-visible impact:
- Scroll pickups are never persisted (lost on restart); scrolls respawn because
  ChunkRenderer.gd:277 reads the *other* instance.
- The all-scrolls check at WorldScene.gd:1253 can never pass.
- The Journal shows session-only data (empty after every restart).
- TownspersonNPC post-flag dialogue gating reads flags that are always false.

## Research Notes

Callers of the **autoload** instance (the wrong one):
- `scenes/world/entities/StoryScroll.gd:42,52,54`
- `scenes/ui/JournalScene.gd:132,146,169`
- `scenes/world/entities/TownspersonNPC.gd:92`

Everything else uses `SceneManager.save_manager` (created at SceneManager.gd:69).

Two viable directions:
1. **Make SceneManager use the autoload** (preferred): delete
   `save_manager = _SaveManagerScript.new()` and point `SceneManager.save_manager`
   at the autoload singleton (e.g. `@onready var save_manager := SaveManager` or a
   getter). Keeps the `SceneManager.save_manager` access path so the ~dozens of
   existing call sites don't change. Verify autoload init order in project.godot —
   SaveManager must be registered before SceneManager (check `[autoload]` section).
2. Remove the autoload registration and fix the three wrong callers — touches fewer
   lines but leaves no globally accessible instance and breaks any future
   `SaveManager.` direct references.

Watch out for:
- Tests under `tests/` that instantiate SaveManager directly — they construct their own
  instances and should be unaffected, but verify.
- `SaveManager._notification` handlers (WM_CLOSE_REQUEST etc.) only work on a node in
  the tree — the autoload is in the tree; SceneManager's private `.new()` instance is
  added as a child (check SceneManager.gd around :69 for `add_child`). After unification
  there must be exactly one instance in the tree receiving notifications.
- TID-227 (Android save robustness) builds directly on this — land this first.

Run the full test suite after the change.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
