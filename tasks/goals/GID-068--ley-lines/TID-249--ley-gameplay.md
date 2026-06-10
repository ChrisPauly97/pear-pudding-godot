# TID-249: Ley Gameplay — Speed Boost, Attuned Battle Buff, Mana Wells

**Goal:** GID-068
**Type:** agent
**Status:** pending
**Depends On:** TID-247

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Makes ley lines mechanical, not just pretty: route choice (follow the line for speed), combat positioning (engage while Attuned for a turn-one mana edge), and intersection rewards (Mana Wells). All three consume TID-247's pure field functions; this task can proceed in parallel with rendering (TID-248).

## Research Notes

**Speed boost:**
- `scenes/world/entities/Player.gd` (CharacterBody3D, WASD mapped to iso directions, VirtualJoystick override on mobile) — multiply the horizontal move speed by ~1.15 when `TerrainMath.is_on_ley_line(global_position.x, global_position.z, SaveManager.world_seed)` in `_physics_process`. One cached-noise call per frame is cheap (TID-247 caches FastNoiseLite per seed).
- Optional juice: tiny particle trail or sprite glow while boosted — keep minimal, no new asset requirements.

**Attuned battle buff:**
- Battle entry: `GameBus.enemy_engaged(enemy_data: Dictionary)` fires when the player overlaps an EnemyNPC within `IsoConst.AUTO_BATTLE_RANGE` (see WorldScene interaction checks). At emit/handle time, check the player's ley status and set `enemy_data["player_attuned"] = true` — same dictionary-flag pattern as the blight enemy buff (GID-066/TID-242), and both flags must coexist safely.
- Battle side: `game_logic/battle/GameState.gd` manages mana (grows 1/turn, capped 10). On battle setup with the flag, grant the player +1 mana crystal on turn 1 (i.e. start at 2 instead of 1, still capped). Check how GID-059 Battlefield Resonance plans turn-1 modifiers to keep the hooks compatible — both goals route modifiers through battle setup data rather than scene lookups.
- Feedback: battle intro line / `hud_message_requested` ("Attuned: +1 mana this turn") so the buff is legible.

**HUD indicator:**
- Small glowing icon (TextureRect or Label) near the minimap/HUD shown while the player stands on a line — tells them "engage NOW for the bonus". Sized as % of viewport height (`get_viewport().get_visible_rect().size.y`), never fixed pixels; visible on both desktop and mobile (it's display-only, no input — mobile parity trivially satisfied).
- Update from WorldScene `_process` alongside the existing per-frame interaction checks; reuse the same per-frame ley query result as the speed boost where possible (compute once per frame, share).

**Mana Wells:**
- Placement: in `game_logic/world/InfiniteWorldGen.gd`'s entity-spawn stage, scan the chunk's tiles for `TerrainMath.ley_intersection_strength > 0` (sample per tile, 256 calls per chunk build — acceptable at build time, or sample every 2nd tile). If an intersection tile exists (pick the strongest, deterministic tie-break) and the tile is TILE_GRASS, append `{ "type": "mana_well", "id": "well_<cx>_<cz>", "tx": …, "tz": … }` to `ChunkData.entities` — follow the merchant spawn block pattern. Skip if `id` is in the collected set.
- Entity: new `scenes/world/entities/ManaWell.gd/.tscn` patterned on `Chest.gd` (Sprite3D billboard — bottom edge must clear y=0, `pixel_height * pixel_size * 0.5 + margin` per CLAUDE.md — interaction prompt via WorldScene `_check_interactions()` + INTERACT_RANGE; works with E key AND touch prompt, mobile parity).
- Reward: essence (emit `GameBus.essence_changed`) or coins — modest, since wells are common-ish; one-time per well.
- Persistence: new SaveManager field `collected_mana_wells: Array[String]` with migration default `[]`, mirroring `opened_chests: Array[String]` (SaveManager.gd:34); mark dirty on collect.

**Testing:**
- Headless: well placement determinism for a fixed seed; collected-well skip logic; Attuned flag injection (pure dict logic); GameState turn-1 mana with/without the flag.
- `godot --headless --path . -s tests/runner.gd` must exit 0.
- GDScript strict mode: explicit types where RHS is `max`/`min`/`clamp`/untyped index.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
