# TID-236: Dead code & config cleanup sweep

**Goal:** GID-064
**Type:** agent
**Status:** pending
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

Dead code to delete:
- `autoloads/GameBus.gd:9, 20` — `map_transition_requested` and `status_applied` never
  emitted nor connected. Delete. (Listener-less but *emitted* signals — `status_ticked`,
  `equipment_dropped`, `corruption_points_changed`, `redemption_points_changed`,
  `story_flag_set`, `essence_changed`, `all_scrolls_collected` — leave declared; they're
  legitimate event-bus surface. But note `all_scrolls_collected` has no achievement hook
  despite docs claiming one — verify against docs/agent/story-narration-scrolls.md and
  either wire the achievement or correct the doc.)
- `scenes/world/GrassBlades.gd:110-143` — legacy `build(world_map)` path never called.
- `assets/shaders/grass.gdshader` (+ its .uid) — referenced nowhere (only `grass_blade`
  and `grass_cluster` are used).
- `game_logic/TextureGen.gd:17-33, 58-127` — only `path()` is used (WorldScene.gd:941);
  delete grass/hill_top/hill_side/wall_side/wall_top generators (~150 lines).
- `game_logic/TerrainMath.gd:22, 76` — `wall_curve_r` params documented "no longer
  used"; remove from signature and call sites (WorldScene.gd:509, ChunkRenderer.gd:67).
  Coordinate with TID-230/231 if they land first (same signatures).
- `scenes/world/entities/Player.gd:18, 72, 76` — `_is_jumping` written, never read.
- `scenes/battle/BattleScene.gd:21` — `var _ai: BasicAI` never assigned (BasicAI is
  static). `game_logic/battle/CardInstance.gd:26, 135, 162` — `armor` field serialized
  but never read (armor lives in status_effects); remove field + serialization (keep a
  from_dict tolerance for old saves).
- `scenes/ui/ChestOpenScene.gd.uid` — orphaned sidecar (also tracked by BID-004 — this
  resolves it; move BID-004 to archive). Check the other BID-004 orphans
  (BundledMaps, ProceduralGen) while here.
- `data/cards/ash_warden.uid` — misnamed sidecar (should be `ash_warden.tres.uid`);
  the current file is dead. Rename/regenerate correctly.

Duplicated constants / lookups:
- `autoloads/SaveManager.gd:592` — local `rarity_order` array duplicates
  `IsoConst.RARITY_ORDER` (IsoConst.gd:54). Use IsoConst.
- `autoloads/CraftingRegistry.gd:30-45` — `get_recipe`/`get_recipes_for_template`
  linear-scan ~180 recipes per lookup (called per crafting-UI row). Key by
  `"%s|%s" % [template_id, rarity]` Dictionary.
- `autoloads/SaveManager.gd:606-610` — `get_instance_by_uid` linear scan invoked in
  loops (:613, :631, InventoryScene.gd:285) → O(deck × collection). Maintain a
  `uid -> instance` Dictionary alongside `owned_cards` (rebuild on load, update on
  add/remove).

Config / polish:
- `project.godot:98-99` — `msaa_3d=2` AND `screen_space_aa=1` (FXAA) both on, no
  `.mobile` override — two AA passes on mobile GPUs. Keep MSAA 2x, drop FXAA (or add
  `.mobile` overrides).
- `autoloads/SceneManager.gd:147` — `_apply_audio_settings()` runs only in
  `continue_game()`, not `start_new_game_with_biome()` → new games play at default
  volumes until next continue. Call it in both.
- `autoloads/AudioManager.gd:116` — `play_sfx` `load()`s per first invocation
  (synchronous disk I/O mid-gameplay). Preload the 11 streams into a const Dictionary.
- `autoloads/SaveManager.gd:762-767` — `unlock_skill()` doesn't verify
  `skill_points > 0` (`max(0, …)` masks underflow). Early-return when `<= 0`.
- `scenes/world/ChunkRenderer.gd:268` — `print()` per NPC spawn during chunk streaming.
  Remove or gate behind a debug flag.
- `scenes/world/WorldScene.gd:1042-1051 + 123-128` — `_dialogue_timer`/`_tip_timer` are
  hand-rolled per-frame countdowns; use `get_tree().create_timer()`. (The
  `_interact_timer`/`_day_night_timer` throttles are fine — leave them.)
- `scenes/world/GrassBlades.gd:432-446` — dirty-rect tracking is dead overhead (full
  64×64 image uploaded anyway). Drop the tracking (upload is only 4 KB; partial update
  not worth it).
- `scenes/ui/MapEditorScene.gd:191-205, 248, 270` and
  `scenes/ui/VirtualJoystick.gd:53-54, 59-60` — hard-coded pixel
  margins/font-sizes/offsets amid vh-relative code. Derive from vh per the project rule.

Verification: project must still parse headless (`godot --headless --editor --quit`),
full test suite green, and grep confirms no remaining references to deleted symbols.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
