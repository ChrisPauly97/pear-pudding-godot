# Ley Lines (GID-068)

## Key Features

- **Visible glowing bands** in the terrain: cyan emissive pulses baked into mesh UV2 data, rendered by the terrain shader.
- **Speed boost**: player moves 15% faster while standing on a ley line in the infinite world.
- **Attuned battle buff**: engaging an enemy while on a ley line grants +1 mana on the first battle turn.
- **Mana Wells**: one-time collectible entities spawned at ley line intersections; yield 15 essence.

## How It Works

### Field Math (`game_logic/TerrainMath.gd`)

Two `FastNoiseLite` simplex noise channels (`_get_ley_noise_a`, `_get_ley_noise_b`) are cached per world seed. The primary channel (frequency 0.008) produces visible bands. The secondary channel (frequency 0.011) is used only for intersection detection.

- `ley_intensity(wx, wz, world_seed) -> float`: returns `clamp(1 - |raw| / 0.05, 0, 1)` — zero away from lines, 1.0 at line centre.
- `is_on_ley_line(wx, wz, world_seed) -> bool`: `ley_intensity > 0`.
- `ley_intersection_strength(wx, wz, world_seed) -> float`: `min(ia, ib)` — positive only where both channels are simultaneously near zero.

### Rendering (`assets/shaders/terrain.gdshader`, `scenes/world/ChunkRenderer.gd`)

Per-vertex ley intensity is baked into `UV2.x` by `ChunkRenderer.prepare_terrain` (worker thread). The shader reads it as `varying float v_ley` and adds a cyan emissive contribution:
```glsl
if (v_ley > 0.01 && !is_wall) {
    float pulse = 0.8 + 0.2 * sin(TIME * 0.8);
    base_emission += v_ley * pulse * 0.45 * vec3(0.05, 0.85, 0.90);
}
```
This guarantees visual/gameplay agreement (same noise, same seed, no GLSL re-implementation needed).

`world_seed` is passed from `WorldScene.WORLD_SEED` to `prepare_terrain` as an explicit parameter — never accessed via `Engine.get_main_loop()` from the worker thread.

### Speed Boost (`scenes/world/entities/Player.gd`)

`_get_move_speed()` multiplies base speed by 1.15 when `SaveManager.current_map == "main"` and `TerrainMath.is_on_ley_line(...)` returns true. One noise sample per call, cached by FastNoiseLite.

### Attuned HUD Indicator (`scenes/world/WorldScene.gd`)

A cyan `Label` (`_ley_indicator`) is added to the HUD in `_update_hud` when `_is_infinite`. It is toggled in `_process` by a per-frame ley query (same result reused from the same per-frame chunk). Sized as `vh * 0.025` font — never fixed pixels.

### Attuned Battle Buff

`WorldScene.get_battlefield_context()` includes `"is_player_attuned": bool`. `SceneManager._on_enemy_engaged` stamps it as `enemy_data["player_attuned"]`. `BattleScene` reads it after `start_turn(1)` and increments `hero.mana` by 1 (capped at 10), then emits a HUD message.

### Mana Wells (`scenes/world/entities/ManaWell.gd/.tscn`)

`InfiniteWorldGen._gen_entities` samples every 2nd tile in the chunk for `ley_intersection_strength > 0` on `TILE_GRASS`, picks the strongest tile, and appends it to `chunk.mana_wells`. `ChunkRenderer._spawn_entities` instantiates `ManaWell.tscn` for uncollected wells. Interaction is handled by `WorldScene._handle_interact` — collecting removes the node and marks the ID in `SaveManager.collected_mana_wells`.

## Integrations with Other Features

| System | Integration |
|---|---|
| TerrainMath | All ley math lives here; consumers call `ley_intensity` / `ley_intersection_strength` / `is_on_ley_line` |
| ChunkRenderer | Bakes UV2.x ley field per chunk on the worker thread; passes `world_seed` as explicit parameter |
| terrain.gdshader | Reads UV2.x as `v_ley`; adds cyan emissive pulse |
| Player | Speed multiplier in `_get_move_speed()` |
| WorldScene | HUD indicator, `get_battlefield_context` attuned flag, mana well register/find/interact |
| SceneManager | Stamps `player_attuned` on enemy_data in `_on_enemy_engaged` |
| BattleScene | +1 mana on turn 1 when `player_attuned` is true |
| SaveManager | `collected_mana_wells: Array[String]`, v38→v39 migration, `is_mana_well_collected` / `mark_mana_well_collected` |
| InfiniteWorldGen | Mana well placement in `_gen_entities` |
| ChunkData | `mana_wells: Array[Dictionary]` field |

## Asset Requirements

- No new textures or audio assets required.
- `scenes/world/entities/ManaWell.tscn` + `.uid` sidecar (`uid://f6svk3gkwd7d`).
- `scenes/world/entities/ManaWell.gd` (procedural mesh — no external assets).
