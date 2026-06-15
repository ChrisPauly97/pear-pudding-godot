# TID-226: Unify the split-brain SaveManager instances

**Goal:** GID-064
**Type:** agent
**Status:** done
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

1. Move `SaveManager` before `SceneManager` in `project.godot` autoload list so SaveManager initializes first and is present in the tree when SceneManager._ready() runs.
2. In `SceneManager.gd`: delete `const _SaveManagerScript` preload, change `save_manager = _SaveManagerScript.new(); add_child(save_manager)` to `save_manager = SaveManager`.
3. No changes to the three "wrong" callers (StoryScroll, JournalScene, TownspersonNPC) — they already use `SaveManager` (the autoload global), which is now the same instance as `SceneManager.save_manager`.

## Changes Made

- **`project.godot`**: Moved `SaveManager` autoload entry before `SceneManager` (was line 28, now line 25). Ensures SaveManager is in-tree when SceneManager._ready() fires.
- **`autoloads/SceneManager.gd`**: Removed `const _SaveManagerScript = preload(...)`. Changed `_ready()` to `save_manager = SaveManager` (one line) instead of `.new()` + `add_child()`. SaveManager is now the single autoload instance; all callers (via `SceneManager.save_manager` or `SaveManager.` directly) share the same initialized object.

## Documentation Updates

None required — the split-brain was an implementation bug, not a documented design.
