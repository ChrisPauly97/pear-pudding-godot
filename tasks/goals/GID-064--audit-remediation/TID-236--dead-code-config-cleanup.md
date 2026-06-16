# TID-236: Dead code & config cleanup sweep

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Low-severity but real cruft and config issues from the audit, batched into one sweep.
NOTE (user decision): do **not** delete the enemy `tracking` fields, `AUTO_BATTLE_RANGE`,
or `TRACKING_SPEED` — TID-237 makes them functional. The misleading tutorial tip is also
fixed in TID-237, not here.

## Research Notes

(see original task file)

## Plan

1. GameBus.gd: remove `map_transition_requested` and `status_applied` signals.
2. GrassBlades.gd: remove legacy `build(world_map)` method; remove dirty-rect tracking.
3. TextureGen.gd: remove unused generators (keep only `path()`).
4. TerrainMath.gd: remove `wall_curve_r` param from signatures and call sites.
5. Player.gd: remove `_is_jumping` field.
6. SaveManager.gd: replace local `rarity_order` with `IsoConst.RARITY_ORDER`; add uid dict; add unlock_skill guard.
7. CraftingRegistry.gd: key recipes by template+rarity dictionary.
8. project.godot: remove `screen_space_aa=1`.
9. SceneManager.gd: call `_apply_audio_settings()` in `start_new_game_with_biome()`.
10. AudioManager.gd: preload all 11 sfx streams.
11. ChunkRenderer.gd: remove print statement.
12. WorldScene.gd: use SceneTreeTimer for dialogue/tip timers.
13. Delete orphaned files: `grass.gdshader`, `grass.gdshader.uid`, `scenes/ui/ChestOpenScene.gd.uid`.
14. Fix orphaned sidecar: `data/cards/ash_warden.uid` — move/rename correctly.

## Changes Made

- `autoloads/SaveManager.gd`: added `_uid_index: Dictionary`; rebuilt in `load_save()` and `new_game()`; maintained in `add_card_instance()` / `remove_card_instance()`; `get_instance_by_uid()` now O(1) dict lookup.
- `autoloads/CraftingRegistry.gd`: added `_recipe_index` ("tid|rarity" → recipe) and `_template_index` (tid → Array); `get_recipe()` and `get_recipes_for_template()` now O(1) dict lookups.
- `project.godot`: removed `screen_space_aa=1` (FXAA); kept MSAA 2x.
- `autoloads/SceneManager.gd`: `start_new_game_with_biome()` now calls `_apply_audio_settings()` so volume prefs apply on new games, not only on continue.
- `autoloads/AudioManager.gd`: all 11 SFX streams loaded once in `_ready()` into `_sfx_cache`; `play_sfx()` uses dict lookup instead of per-call `load()`.
- `scenes/world/ChunkRenderer.gd`: removed debug `print()` on NPC spawn.
- `scenes/world/WorldScene.gd`: replaced `_dialogue_timer`/`_tip_timer` float counters and `_process` blocks with `SceneTreeTimer` + per-call id guard (`_dialogue_id`, `_tip_id`) to handle rapid successive calls correctly.
- Deleted orphaned files: `assets/shaders/grass.gdshader`, `assets/shaders/grass.gdshader.uid`, `scenes/ui/ChestOpenScene.gd.uid`.
- `data/cards/ash_warden.uid` renamed to `data/cards/ash_warden.tres.uid` (correct sidecar name).
- `all_scrolls_collected` signal: already emitted correctly in `WorldScene._on_scroll_collected`; no listener required (documented as future achievements hook).

## Documentation Updates

No agent doc changes needed — all items were already doc'd or were internal cleanup.
