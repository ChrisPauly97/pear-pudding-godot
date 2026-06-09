# TID-198: Siege Presentation & Flow

**Goal:** GID-054
**Type:** agent
**Status:** pending
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
  - **Cleanup on map exit:** When exiting a town map while a siege is active, the raider NPCs are freed naturally (they're not persisted in the map .tres, just runtime instances). On day rollover (if the siege is abandoned overnight), `increment_day()` in SaveManager will clear the siege via a new check (see TID-199 for cleanup hook).

- **Siege banner HUD:** A persistent label/banner while a siege is active, visible throughout the town.
  - Added to the HUD CanvasLayer (same layer as interact prompt, coin counter, etc.). See **docs/agent/ui-and-scene-management.md** lines 110–126 for HUD construction in WorldScene.
  - Text: `"[Town Name] Under Attack!"` or `"Raiders at the Gate!"`.
  - Position: top-center, font size ~3% vh (cite CLAUDE.md UI sizing section line 169).
  - Color: bright red or orange tint.
  - Visibility: hidden if no siege is active; shown only in named towns (not infinite world).
  - Update in WorldScene._process(): `if SaveManager.get_active_siege().is_empty(): banner.visible = false else: banner.visible = true`.

- **Interact/start flow:** When the player approaches a raider NPC, a standard interact prompt appears (same as for NPCs/chests). Pressing E (or tapping on mobile) launches the first gauntlet battle.
  - **EnemyNPC already has `engage()` logic** — when the player is within INTERACT_RANGE (IsoConst.INTERACT_RANGE = 1.5, line 31 of **autoloads/IsoConst.gd**), the NPC becomes interactable. Raiders are not auto-engaged like normal enemies (no AUTO_BATTLE_RANGE trigger). The player must manually interact (E or tap) to start the siege battle.
  - On interact: `GameBus.enemy_engaged.emit(enemy_data)` fires (normal battle flow). SceneManager routes it to BattleScene, which will load the raider deck and the carry-over HP.

- **Retreat / siege persistence:** The player can walk away from raiders and return; the siege persists until:
  1. **Won:** All 3 stages cleared (TID-199 handles rewards + discount).
  2. **Lost:** Player loses any stage battle (TID-199 handles defeat coin loss).
  3. **Timeout:** An in-game day passes without engagement. If the player never touches the siege on the day it started, `increment_day()` clears it (see TID-199 cleanup hook). This models the town "holding out" until the next day.
  - No special UI for "the siege will expire soon"; the timeout is silent.

- **Between-stage interstitial (gauntlet continuation):** After winning stage 0 or 1, before stage 1 or 2 is launched, a brief overlay appears:
  - Text: `"Wave 2 of 3"` (or Wave 3) + `"Hero HP: [current]/30"` (or max).
  - Duration: visible for ~2 seconds, then auto-dismiss and auto-launch the next battle (via the chaining logic in TID-197).
  - Style: reuse the existing **RunSummaryScene** or **CardInspectOverlay** pattern — a semi-transparent PanelContainer with centered labels. Cite the code examples from those scenes.
  - **Implementation:** After SceneManager captures HP and advances stage, before calling `GameBus.enemy_engaged.emit()`, instantiate a CanvasLayer overlay with the interstitial, wait 2 seconds, then emit the signal.

- **Audio:** If **AudioManager** supports sound effects (check for `AudioManager.play_sfx()` or `play_music()` pattern from **docs/agent/battle-system.md** lines 148–149), play a "siege_warning" or "battle_start" SFX when the banner first appears. Fallback gracefully if the file doesn't exist.

- **Mobile parity:** All raider interactions must be tap-able; the player must not require a keyboard to start a siege. EnemyNPC already emits on interact; add a visible `Button` at the raider's position (floating above, similar to how dialogue prompts work) that calls `_handle_interact()` on Android. Cite **WorldScene.gd** interact button pattern from **docs/agent/ui-and-scene-management.md** lines 113–115.

- **Tests (headless):**
  - `tests/test_siege_spawn.gd` — mock WorldScene with an active siege, verify raider entities are instantiated near the gate tile with correct enemy_type. Verify they are freed on map exit.
  - `tests/test_siege_banner.gd` — verify banner appears when siege active, hidden when none. Verify banner text updates per town.
  - `tests/test_interstitial.gd` — mock SceneManager battle win + gauntlet chain, verify interstitial overlay appears, auto-dismisses, and next battle is queued.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
