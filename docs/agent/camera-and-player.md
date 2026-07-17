# Camera and Player

## Key Features

- Fixed isometric camera at elevation −35.264° / azimuth −45° — rotation never changes at runtime
- Orthographic projection (size 15 world units) for a clean pixel-art look
- Camera tracks the player by translating position only; `look_at()` is never called
- Player moves on a `CharacterBody3D` with WASD mapped to diagonal isometric directions
- Gravity and jump physics via Godot's built-in character controller
- 4-frame walking animation on a billboard `Sprite3D` (pixel art, 32 px)
- Chunk streaming: WorldScene loads/unloads 16×16 tile chunks around the player every frame
- Mobile support via `VirtualJoystick` overlay (touchscreen detection)

---

## How It Works

### Isometric Camera Setup

The camera's baked rotation in `WorldScene.tscn`:
- Elevation: `−35.264°` (= `arcsin(tan(30°))` ≈ `−arctan(1/√2)`) — gives the classic 1:1:1 axonometric ratio
- Azimuth: `−45°` — aligns the cardinal axes with screen diagonals
- Projection: `PROJECTION_ORTHOGONAL`, size 15
- Near/far: `0.1 / 1000`

The camera **must not** be rotated at runtime. Its look direction is `(−1, −1, −1)` normalised. To centre the viewport on the player, the offset in the opposite direction is `(+1, +1, +1)` normalised × distance. At size ~34.6 that becomes:

```gdscript
_camera.position = _player.position + Vector3(20, 20, 20)
```

This is set every frame in `WorldScene._process()`. No `look_at()` call is made.

### Player Movement (`scenes/world/entities/Player.gd`)

WASD keys map to isometric world directions:

| Key | Screen direction | World delta |
|---|---|---|
| W | North-East | `(+1, 0, −1)` normalised |
| S | South-West | `(−1, 0, +1)` normalised |
| A | North-West | `(−1, 0, −1)` normalised |
| D | South-East | `(+1, 0, +1)` normalised |

Diagonals (e.g. W+D) sum correctly to a cardinal axis.

Physics:
- `velocity.y` accumulates gravity each frame (`ProjectSettings` gravity, default 9.8 m/s²)
- Jumping adds an upward impulse when `is_on_floor()` and Space is pressed
- `move_and_slide()` handles terrain collision via the `HeightMapShape3D` from `TerrainMath`

### Slope Handling (hill climbing)

Generated hills reach ~72° at max height (Mountains `max_hill_h` 7 × `HILL_FACE_H` 1.0 blended over `HILL_CURVE_R` 3.5). Three `CharacterBody3D` settings in `Player._ready()` make them walkable and smooth:

- `floor_max_angle = deg_to_rad(75.0)` — the default 45° treated steep hill faces as walls; the player only ascended because the WorldScene software floor teleported them upward, stalling velocity each time. Wall faces are vertical (90°) and stay unwalkable.
- `floor_snap_length = 0.6` — sticks the body to the surface on descents and over crests instead of repeated micro-falls.
- `floor_constant_speed = true` — uniform movement speed regardless of slope.

The **WorldScene software floor** (`_process`) is a rescue for physics genuinely losing the terrain (chunk collider not yet built, tunneling). It fires only when `not _player.is_on_floor()` **and** the player is > 0.05 below the analytic height. It must never fire while grounded: the analytic smoothstep height sits up to ~0.4 units above the `HeightMapShape3D` facets on steep hills (the collision/visual mesh interpolates linearly between 1-unit-spaced vertices), so an unconditioned `y < floor_y` check triggers every frame on slopes. `Player.cancel_fall()` zeroes only vertical velocity — horizontal is preserved so a rescue doesn't stop the player dead.

### Locomotion Feel (TID-428)

- **Accel/decel:** `velocity.x`/`velocity.z` ramp toward the target via `move_toward(velocity.x, dir.x * move_speed, accel * delta)` instead of snapping — `ACCEL = 40.0` while there's steering intent (manual input or an active tap-to-move path), `DECEL = 50.0` once intent drops to zero. ACCEL applies for the *entire* path-following duration (not just the first tick), so the waypoint-arrival check (`_WP_ARRIVE_DIST_SQ`) keeps full steering authority and doesn't orbit the destination under a sluggish decel. `_is_moving` (drives the walk/idle swap) is keyed off steering intent (`dir`), never residual velocity, so idle doesn't lag the actual stop.
- **Walk dust:** `_dust_particles` now emits whenever `_is_moving and is_on_floor()`, on foot or mounted — previously mount-only. Two `ParticleProcessMaterial` presets (`_dust_mat_foot` lighter/fewer, `_dust_mat_mount` heavier) are swapped (plus `amount` 10 vs 20) by `_update_mount_visuals()` on mount toggle only, not per-frame.
- **Landing feedback:** a frame-to-frame airborne→grounded transition (`_was_on_floor` tracked each `_physics_process`) with fall speed ≥ `_LAND_FALL_SPEED` (4.0 u/s) triggers `_on_landed()`: a dedicated one-shot `_landing_dust` burst (`GPUParticles3D.restart()`), `play_sfx("land")`, and a sprite squash (`_squash_sprite(1.08, 0.9, 0.15)`). Jump takeoff gets a symmetric stretch (`0.94, 1.06`). `_squash_sprite` tweens `scale` as a `Vector3` — `AnimatedSprite3D` is a `Node3D`, so scale is never `Vector2` (CLAUDE.md sprite-scale caution).
- **Anim-synced footsteps:** `_footstep_timer` is gone. `_sprite.frame_changed` (connected once in `_build_sprite()`) fires `play_sfx("footstep")` on the walk animation's contact frames (0 and 2 of the 4-frame cycle), suppressed while mounted. At `ANIM_FPS = 6`, that's a step every ~0.33s while walking, now locked to the actual foot-down frame instead of an independent timer.

### Sprite Animation

The `Sprite3D` uses `BILLBOARD_ENABLED` so it always faces the camera:
- Frame index cycles through 0–3 based on `move_timer` accumulator (one new frame every 0.15 s while moving)
- Sprite is positioned at `Vector3(0, 1.1, 0)` relative to the `CharacterBody3D` origin to lift it above the tile floor
  - Formula: `pixel_height * pixel_size * 0.5 + margin = 48 * 0.04 * 0.5 + 0.14 ≈ 1.1`
- Idle state shows frame 0

### Chunk Streaming (`scenes/world/WorldScene.gd`)

Every frame WorldScene checks if the player has crossed a chunk boundary:

```
player_chunk = Vector2i(floor(player.position.x / (CHUNK_SIZE * TILE_SIZE)),
                        floor(player.position.z / (CHUNK_SIZE * TILE_SIZE)))

if player_chunk != last_chunk:
    _update_loaded_chunks(player_chunk)
```

`_update_loaded_chunks`:
1. For each chunk within **load radius 6**, request `ChunkData` from `InfiniteWorldGen` (cached or built)
2. Schedule mesh build on `WorkerThreadPool` (up to 4 concurrent) if not yet rendered
3. For each chunk beyond **unload radius 7**, free the `ChunkRenderer` node
4. Evict `ChunkData` from `_chunk_data_cache` beyond **eviction radius 10**

### Mobile Controls

`VirtualJoystick` (`scenes/ui/VirtualJoystick.gd`) is added to the HUD when `DisplayServer.is_touchscreen_available()` returns `true`:
- Renders a circular pad and thumb at bottom-left
- Converts thumb offset to the same `(dx, dz)` movement vector as WASD
- Injected directly into `Player._process()` as an override when active

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **TerrainMath** | Physics dependency | `HeightMapShape3D` built by `TerrainMath` is attached under each chunk's `StaticBody3D`; player stands on it |
| **InfiniteWorldGen** | Data source | `WorldScene` calls `get_chunk(cx, cz)` which may trigger async `ChunkData` build |
| **ChunkRenderer** | Rendering | Each loaded chunk has a `ChunkRenderer` node that builds and holds the `MeshInstance3D` nodes |
| **IsoConst** | Constants | `CHUNK_SIZE`, `TILE_SIZE`, `AUTO_BATTLE_RANGE`, `INTERACT_RANGE` |
| **EnemyNPC / Chest / Door** | Interaction | `WorldScene._check_interactions()` called every frame; proximity within `INTERACT_RANGE` shows prompt; E key triggers action |
| **GameBus** | Signals | `enemy_engaged` emitted when player overlaps an `EnemyNPC` within `AUTO_BATTLE_RANGE` |
| **SaveManager** | Position persistence | Player `position.x / position.z` written to save on map exit |
| **VirtualJoystick** | Mobile input | Replaces WASD on touchscreen devices |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Player scene | `scenes/world/entities/Player.tscn` | `CharacterBody3D` + `Sprite3D` + `CollisionShape3D` |
| Walking frames | `assets/textures/pixel_art/wizard_walk_0.png` … `wizard_walk_3.png` | 4 frames, 32 px wide, 48 px tall |
| WorldScene | `scenes/world/WorldScene.tscn` | Contains `Camera3D`, `DirectionalLight3D`, player spawn marker |
| ChunkRenderer scene | `scenes/world/ChunkRenderer.tscn` | Template instantiated per loaded chunk |
| VirtualJoystick scene | `scenes/ui/VirtualJoystick.tscn` | Touchscreen overlay; added at runtime when touchscreen detected |
