# TID-242: Blight Rendering — Terrain Tint, Ambience, Enemy Buff

**Goal:** GID-066
**Type:** agent
**Status:** done
**Depends On:** TID-241

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Blight must be readable at a glance and mechanically meaningful before the cleansing loop (TID-243) lands. This task makes blighted chunks look corrupted (dark purple desaturated terrain tint), darkens them on the minimap, and buffs enemies encountered inside them. After this task, a player wandering into a blighted region immediately understands "this place is dangerous and wrong" — the payoff of fixing it comes next.

## Research Notes

**Terrain tinting:**
- `scenes/world/ChunkRenderer.gd` already passes per-biome tint uniforms (grass/hill/wall hues from `BiomeDef`) into `assets/shaders/terrain.gdshader`. Add one new uniform, e.g. `uniform float blight_amount : hint_range(0.0, 1.0)`, that lerps the final color toward a dark desaturated purple.
- Set the uniform at chunk build time from `BlightField.blight_intensity(cx, cz, world_seed, SaveManager.days_elapsed, SaveManager.blight_cleansed_hearts)` (pure function from TID-241).
- Each ChunkRenderer should use a per-chunk material (check whether materials are currently shared — if shared, duplicate the ShaderMaterial per chunk or use instance uniforms) so neighbouring blighted/clean chunks render differently.
- If a new shader file is created instead of editing terrain.gdshader: it MUST get a `.uid` sidecar (`uid://` + 12 lowercase alphanumerics) and be referenced via `preload()`, never `load()` — Android export rule. No geometry shaders exist in Godot 4.

**Refresh on state change:**
- Blight state only changes on a day tick (days_elapsed increments) or when a heart is cleansed. Both are rare events — on either, iterate currently loaded ChunkRenderers and re-set the `blight_amount` uniform (no mesh rebuild needed, uniform update only).
- Suggest a GameBus signal `blight_changed()` emitted by WorldScene on day rollover and by the cleanse flow (TID-243); WorldScene listens and refreshes loaded chunk uniforms.

**Minimap:**
- `scenes/world/Minimap.gd` draws chunk/tile pixels around the player. Darken/purple-shift pixels for blighted chunks by calling the same `BlightField` query per drawn chunk. Keep the call count bounded (per chunk, not per texel).

**Enemy buff in blighted chunks:**
- Battle entry flows through `GameBus.enemy_engaged(enemy_data: Dictionary)` (emitted from WorldScene proximity checks; EnemyNPC carries its data dict).
- Keep the hook small: when WorldScene (or the engage path) detects the player's current chunk is blighted, set a flag in the enemy_data dictionary, e.g. `enemy_data["blighted"] = true`. The battle setup (BattleScene / game_logic/battle/GameState.gd) reads the flag and applies a modest buff — suggest +5 enemy hero HP, or +1 enemy starting mana (mana normally grows 1/turn capped 10).
- Surface it to the player: a one-line note in the battle intro or a `hud_message_requested` ("The blight empowers your foe…").

**Ambience (cheap, optional polish within this task):**
- WorldScene's day/night shader tint path can deepen the ambient tint while the player stands in a blighted chunk. Keep subtle; skip particles if scope grows.

**Testing:**
- Headless tests can cover the intensity→uniform mapping helper and the enemy_data flag injection (pure parts). Visual tint verified manually / via the existing test runner (`godot --headless --path . -s tests/runner.gd` must stay green).

**GDScript reminders:** explicit types when RHS is `max`/`min`/`clamp`/untyped array index (strict mode treats Variant inference as error).

## Plan

1. Add `instance uniform float blight_amount` to `assets/shaders/terrain.gdshader`; fragment blends toward dark desaturated purple at full blight.
2. In `ChunkRenderer.gd`: cache `_terrain_mi` and `_wall_face_mi` MeshInstance3D refs; add `set_blight_amount(intensity)` using `set_instance_shader_parameter()`; apply initial tint in `build_visual()` after entity spawn.
3. In `WorldScene.gd`: preload `BlightField`; add `_blight_heart_nodes` dict; connect `GameBus.blight_changed` → `_refresh_blight_tints()` (iterates chunk renderers); emit `blight_changed` on day rollover; stamp `is_blighted` into `get_battlefield_context()`.
4. In `SceneManager._on_enemy_engaged`: stamp `enemy_data["is_blighted"]` from `get_battlefield_context()`.
5. In `BattleScene`: after boss HP override, if `is_blighted == true` and not a `blight_heart_id`, add +5 HP to enemy hero and emit HUD message.

## Changes Made

- **`assets/shaders/terrain.gdshader`**: Added `instance uniform float blight_amount : hint_range(0.0, 1.0) = 0.0;`. Fragment: if `blight_amount > 0`, desaturate toward dark purple with `blight_amount * 0.75` blend factor.
- **`scenes/world/ChunkRenderer.gd`**: Added `_terrain_mi: MeshInstance3D` and `_wall_face_mi: MeshInstance3D` instance vars; saved in `_apply_terrain_visual()`; added `set_blight_amount(intensity: float)` using `set_instance_shader_parameter`; in `build_visual()`, apply initial blight tint from `BlightField.blight_intensity()` after `_spawn_entities()`.
- **`scenes/world/WorldScene.gd`**: Added `BlightField` preload; added `_blight_heart_nodes: Dictionary`; `get_battlefield_context()` now includes `"is_blighted"`; connected `GameBus.blight_changed → _refresh_blight_tints()`; added `_refresh_blight_tints()` iterating `_chunk_renderers`; emits `GameBus.blight_changed` on day rollover in `_update_day_night()`.
- **`autoloads/SceneManager.gd`**: In `_on_enemy_engaged`, stamps `enemy_data["is_blighted"]` from `get_battlefield_context()`.
- **`scenes/battle/BattleScene.gd`**: After boss HP override, blighted-zone buff: `+5 HP` to enemy hero when `enemy_data.is_blighted == true` and no `blight_heart_id`.

## Documentation Updates

- `docs/agent/blight-system.md` created.
