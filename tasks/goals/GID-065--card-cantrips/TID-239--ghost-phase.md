# TID-239: Ghost Phase — One-Tile Wall Pass

**Goal:** GID-065
**Type:** agent
**Status:** done
**Depends On:** TID-238

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Ghost Phase is the first concrete cantrip — it lets the player phase through a single wall tile (TILE_WALL) in the direction they're facing. This creates shortcuts through ruins and canyon mazes when a player's deck is heavy on Ghost cards. Implementation includes movement, collision disabling, visual feedback (ghostly effect), and cooldown integration from TID-238.

## Research Notes

**Tile system and detection:**
- The overworld is made of tiles with type constants defined in `autoloads/IsoConst.gd` (TILE_GRASS, TILE_HILL, TILE_WALL, etc.).
- For the named-map path (WorldMap), tile lookup is `world_map.get_tile(tx, tz)`.
- For the infinite-chunk path (ChunkRenderer), tiles are stored in `ChunkData.tile_grid: Array[int]` (256 entries, row-major: `li = tz * 16 + tx`).
- Implementation should work for both paths. Suggest adding a helper to WorldScene or a standalone function that queries the appropriate path (check how existing code handles both paths, e.g., `game_logic/TerrainMath.gd` or `scenes/world/WorldScene.gd`).

**Movement and collision:**
- Player is a CharacterBody3D in `scenes/world/entities/Player.gd`.
- When Ghost Phase is activated, check one tile ahead in the player's facing direction (can use Player's current facing vector or a direction passed from the activation context).
- Verify the tile sequence: current tile is TILE_GRASS (or other walkable), next tile is TILE_WALL, tile after that is TILE_GRASS (or walkable).
- Only allow the phasing if exactly one TILE_WALL blocks the path (don't allow skipping multiple walls or falling off the map).
- Tween the player across the wall tile while disabling collision temporarily:
  - Set `player.collision_layer = 0` and `player.collision_mask = 0` (or just the terrain layer) to avoid clipping through collision geometry.
  - Tween `player.position` from current to target position (roughly one tile away) over ~0.3 seconds (adjust for feel).
  - Re-enable collision when the tween completes.
  - Alternative: use a short-lived Area3D to detect collision and abort if the player hits something mid-phase.

**Visual feedback:**
- Ghostly effect: modulate the player sprite's `modulate.a` (alpha) to ~0.5 during the phase, then fade back to 1.0.
- Optional: apply a shader effect or particle trail (shader approach preferred to avoid Godot 4's lack of geometry shaders).
- Optional: emit a subtle sound cue via AudioStreamPlayer when the cantrip is activated.
- Emit a HUD message via `GameBus.hud_message_requested` if the cantrip is unavailable (on cooldown or insufficient cards).

**Cooldown:**
- Integration with TID-238: when Ghost Phase is activated, call `CantripManager.can_use("ghost_phase", last_use_time, current_time)` to check cooldown.
- If allowed, mark last_use_time in SaveManager.cantrip_last_use_time["ghost_phase"] = Time.get_ticks_msec() / 1000.0 (or similar Unix-time format).
- Suggest 10–15 second cooldown to prevent spam (tunable during playtesting).

**Camera handling (critical):**
- CLAUDE.md hard rule: **Never call `camera.look_at()` on the isometric camera**. The camera rotation is baked in.
- Only update camera position, never rotation, when the player moves (Ghost Phase included).
- Camera offset is Vector3(20, 20, 20) (not (0, 20, 20)) to match the view center.

**Edge cases and restrictions:**
- Player must be on the ground (not mid-air or in a dialog/battle).
- Cannot phase through walls adjacent to ruins or dungeon entrances if special rules apply (game design decision — suggest allowing it freely for now, then restrict in playtesting if needed).
- If the target position is occupied by an NPC or chest, the phase should abort (don't teleport the player into an entity).
- Phasing should not work in dungeons or named maps if the designer prefers (can add a flag in map metadata, but default is allow everywhere).

## Plan

Implemented as WorldScene methods `_activate_ghost_phase`, `_do_ghost_phase`, `_start_ghost_phase_tween`, `_on_ghost_phase_done`, `_set_player_alpha`. Tile check via `get_tile_global`. Tween with collision disable/restore. Camera untouched (position only).

## Changes Made

- `scenes/world/WorldScene.gd` — `_ghost_phase_active: bool`, `_ghost_tween: Tween` state vars; `_activate_ghost_phase()` (availability + cooldown check); `_do_ghost_phase()` (tile scan + tween start); `_start_ghost_phase_tween()` (collision disable, alpha fade, 0.3s position tween); `_on_ghost_phase_done()` (restore collision + alpha); `_set_player_alpha()` (finds Sprite3D children)

## Documentation Updates

- `docs/agent/card-cantrips.md` — Ghost Phase section
