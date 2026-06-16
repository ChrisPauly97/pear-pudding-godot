# TID-198: Siege Presentation & Flow

**Goal:** GID-054
**Type:** agent
**Status:** done
**Depends On:** TID-197

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Runtime entity spawning of raider mobs at the town gate, HUD siege banner, interact flow to launch the gauntlet, and day-rollover cleanup that ends abandoned sieges.

## Research Notes

- **Runtime raider entity spawning:** While named maps store entities in the `.tres` resource (parsed by WorldMap), sieges must spawn raiders at runtime when a siege becomes active. This is similar to how GID-039's TID-152 plans world events — check **docs/agent/world-generation.md** for entity spawn positioning patterns (cite the existing entity spawning section).
  - Sieges spawn **3–4 raider NPCs** of type `EnemyNPC` near the town gate. Each raider is an instance of **scenes/world/entities/EnemyNPC.tscn**, with `enemy_type` set to match the current stage (e.g., `"martarquas_raider_1"`).
  - **Gate position per town:** Each town map in **assets/maps/** (madrian.tres, maykalene.tres, blancogov.tres, etc. — from MapRegistry._BUNDLED lines 19–32 of **autoloads/MapRegistry.gd**) has a town-gate door/spawn zone. Gate positions hardcoded per town (e.g., madrian gate at tile (5, 8), maykalene at (12, 6)) — these are derived from the map editor or map layout files. Store as a static dict in SiegeDefs.gd: `const TOWN_GATES: Dictionary = { "madrian": Vector3(...), "maykalene": Vector3(...), ... }`.
  - **Spawn logic in WorldScene:** On map load, after WorldScene._ready() (which loads the map and places persistent entities), check if a siege is active for this map:
    ```gdscript
    var siege = SaveManager.get_active_siege()
    if not siege.is_empty() and siege.get("town", "") == current_map_name:
        _spawn_siege_raiders(siege.get("stage", 0))
    ```
  - `_spawn_siege_raiders(stage: int)` — instantiate 3 EnemyNPC nodes near the gate:
    - Position each at `gate_pos + offset` where offset is a small random spread (e.g., ±1 tile from the gate).
    - Set `enemy_npc.enemy_type = "martarquas_raider_%d" % (stage + 1)`.
    - Append each to the world scene's entity layer.
  - **Cleanup on map exit:** When exiting a town map while a siege is active, the raider NPCs are freed naturally (they're not persisted in the map .tres, just runtime instances). On day rollover (if the siege is abandoned overnight), `increment_day()` in SaveManager will clear the siege.

- **Siege banner HUD:** A persistent label/banner while a siege is active, visible throughout the town.
  - Added to the HUD CanvasLayer (same layer as interact prompt, coin counter, etc.). See **docs/agent/ui-and-scene-management.md** lines 110–126 for HUD construction in WorldScene.
  - Text: `"[Town Name] Under Attack!"`
  - Color: bright red.
  - Visibility: hidden if no siege is active; shown only in named towns (not infinite world).

- **Interact/start flow:** When the player approaches a raider NPC, a standard interact prompt appears (same as for NPCs/chests). Pressing E (or tapping on mobile) launches the first gauntlet battle.
  - **EnemyNPC already has `engage()` logic** — when the player is within INTERACT_RANGE, the NPC becomes interactable. Raiders are not auto-engaged (no AUTO_BATTLE_RANGE trigger). The player must manually interact to start the siege battle.
  - On interact: `GameBus.enemy_engaged.emit(enemy_data)` fires (normal battle flow).

- **Retreat / siege persistence:** The player can walk away from raiders and return; the siege persists until won, lost, or timed out via `increment_day()`.

- **Between-stage interstitial (gauntlet continuation):** After winning stage 0 or 1, before stage 1 or 2 is launched, a brief overlay appears:
  - Text: `"Wave N of 3"` + `"Hero HP: X / 30"` (red if HP ≤ 10).
  - Duration: 2 seconds, then auto-dismiss and auto-launch the next battle.
  - Implementation: CanvasLayer with VBoxContainer; auto-started in SceneManager after advancing stage.

- **Tests (headless):**
  - `tests/unit/test_siege_trigger.gd` — verifies `SiegeDefs.should_trigger()` with all three conditions.
  - `tests/unit/test_siege_state.gd` — siege methods + stage advancement.

## Plan

1. Add `_check_siege_spawn(map_name)` call in WorldScene after named-map entity spawns.
2. Implement `_spawn_siege_raiders(map_name, stage)` and `_setup_siege_banner(map_name)` in WorldScene.
3. Implement `_show_siege_interstitial(next_stage, hero_hp)` in SceneManager.
4. Write unit tests for trigger/state.

## Changes Made

- Updated `scenes/world/WorldScene.gd` — added `_siege_raider_nodes: Array[Node3D]` and `_siege_banner: Label` members; `_check_siege_spawn(map_name)` called after named-map entity spawns; `_spawn_siege_raiders(map_name, stage)` spawns 3 EnemyNPC nodes near `TOWN_GATES[map_name]` with ±0.5 offsets; `_setup_siege_banner(map_name)` adds red Label to `_hud` CanvasLayer.
- Updated `autoloads/SceneManager.gd` — `_show_siege_interstitial(next_stage, hero_hp)` creates CanvasLayer overlay with "Wave N of 3" text and HP display (red if HP ≤ 10), auto-dismisses after 2s and chains next battle via `GameBus.enemy_engaged`.

## Documentation Updates

- Siege presentation details documented in `docs/agent/town-siege.md` (Siege Lifecycle, Raider Entities, Siege Banner, Gauntlet Interstitial sections).
