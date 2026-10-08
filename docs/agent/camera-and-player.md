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

### Pixel Snapping (`game_logic/PixelSnap.gd`) — GID-131 / TID-504

Nearest-filtered pixel art at ~3.2 screen px per texel shimmers when the camera glides by sub-pixel amounts. Each frame `WorldScene._snap_to_pixel()` rounds the smoothed camera target to whole screen pixels on the camera's right/up axes (depth along the view axis untouched): one pixel = `PixelSnap.pixel_world_size(_camera.size, viewport_h)` = `size / height`. **`Camera3D.size` is the full view height** — the pre-GID-131 code used `CAM_ORTHO_SIZE × 2` and snapped in 2-pixel steps. Then `Player.snap_visuals_to_pixels(basis, px)` offsets the rider and mount sprites (`_pixel_offset`, added to `_sprite_pose_pos` / `_mount_pose_pos`) so the player also lands on whole pixels; the physics body never moves. A custom smooth-pixel-art sprite shader was ruled out: `Sprite3D.material_override` does not receive the sprite texture automatically, so every animated sprite would need per-frame texture wiring. Tests: `test_pixel_snap.gd`.

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
- **Jump buffer & coyote time (TID-464):** the jump condition is
  `_jump_buffer_timer > 0.0 and _coyote_timer > 0.0`, not a same-frame
  `is_action_just_pressed and is_on_floor()` match. `_coyote_timer` resets to
  `_COYOTE_TIME` (0.12s) every frame `_was_on_floor` is true and otherwise
  ticks down, so a jump pressed just after walking off a ledge still fires.
  `_jump_buffer_timer` resets to `_JUMP_BUFFER_TIME` (0.12s) on
  `is_action_just_pressed("jump")` and otherwise ticks down, so a jump
  pressed just before landing still fires on touchdown. Both timers are
  consumed (`= 0.0`) the instant a jump fires, so one buffered press can't
  double-jump across two landings. This only widens the input timing window
  — `floor_max_angle`/`floor_snap_length`/`floor_constant_speed` (the slope
  rules above) are unchanged.

### Sprite Animation

The `Sprite3D` uses `BILLBOARD_ENABLED` so it always faces the camera:
- Frame index cycles through 0–3 based on `move_timer` accumulator (one new frame every 0.15 s while moving)
- Sprite is positioned at `Vector3(0, 1.1, 0)` relative to the `CharacterBody3D` origin to lift it above the tile floor
  - Formula: `pixel_height * pixel_size * 0.5 + margin = 48 * 0.04 * 0.5 + 0.14 ≈ 1.1`
- Idle state shows frame 0

### Swimming (GID-172 / TID-696)

Deep water — the sea off the piers and a river off its bridges (`Rivers.deep_water`, ≥ `Coast.WADE_DEPTH` 1.5
tiles) — is swum, not blocked. The `Coastline` world module checks the hero's tile every physics frame
(priority 100, after the move) and calls `Player.set_swimming(deep)`; entering deep water also dismisses the mount.
Tuning lives in `game_logic/world/Swimming.gd`:

| | |
|---|---|
| Speed | `SPEED × SPEED_MULT` (0.55); mounts and ley lines don't apply (`_get_move_speed`) |
| Look | the sprite pose sinks `SINK` (0.62 u), so the terrain occludes legs and hips (set in `_update_mount_visuals`) |
| Animation | `HeroAnim.pick(..., swimming)` → `swim` (4-frame crawl, 6 fps) moving, `tread` (2 frames) idle; back views `swim_back` / `tread_back`; PaperDoll draws them (arms only matter) |
| Sound | `footstep_water` on stroke frames (`STROKE_FRAMES` 0, 2) |
| Splashes | foot dust keeps emitting while swimming; AmbientTouches already turns it into water droplets on wet ground |
| Refused | jump; mounting (`Mounts.toggle` toast); Skeleton Dig (`Cantrips`) |
| Tap-to-move | `TapToMove.step_cost` → `Pathfinder.find_path(..., cost_lookup)`: deep water costs `PATH_COST` (4) per step, and path smoothing won't straighten a walk back across water that costs more than its ends |

Stamina and drowning: TID-697.

### Occluded Silhouette (GID-146)

Scenery is never cut away. `SpriteOutline.apply_xray(sprite)` chains
`assets/shaders/sprite_xray.gdshader` as the `next_pass` of the sprite's outline
material (local `Player` and `RemotePlayer`). The pass draws with depth testing
off, reads `hint_depth_texture`, and paints only where the scene depth is more
than `occlusion_bias` (0.8) nearer than the sprite: a two-texel warm rim around
the silhouette plus a 15 % fill. `SpriteOutline.refresh` feeds both passes the
current frame. The shader converts depth for Compatibility (`depth * 2 - 1`), as
devices without Vulkan fall back to it. The old terrain-shader wall cutaway
(`occlusion_focus` global) was removed.

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

**Frame pacing** (`ChunkStreamingManager`): job *kicks* carry main-thread prep cost (3×3 neighbour tile generation, a 529-tile grid snapshot, entity generation), so at most `MAX_KICKS_PER_FRAME` (2) jobs are dispatched per frame even when 4 worker slots are free. Commits are paced one per frame, and each commit builds only the **visual** phase; the physics phase (`HeightMapShape3D` + merged wall boxes, `ChunkRenderer.build_physics()`) is deferred to a later frame and drained one per frame by `_drain_deferred_physics()`. The WorldScene software floor covers the rare case of the player outrunning a pending collider. Synchronous builds (startup 5×5 ring, named maps) still build physics immediately.

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
| Hero frames | none — drawn at runtime by `game_logic/character/PaperDoll.gd` | 16×28 idle + 4 walk, layered body + gear (GID-137); redrawn on `GameBus.equipment_changed` |
| WorldScene | `scenes/world/WorldScene.tscn` | Contains `Camera3D`, `DirectionalLight3D`, player spawn marker |
| ChunkRenderer scene | `scenes/world/ChunkRenderer.tscn` | Template instantiated per loaded chunk |
| VirtualJoystick scene | `scenes/ui/VirtualJoystick.tscn` | Touchscreen overlay; added at runtime when touchscreen detected |

## Paper-doll hero (GID-137)

The player sprite is drawn in code so gear changes the body. Files (an
`extends` chain, so statics are inherited unqualified):
`game_logic/character/PaperDollPixels.gd` (pixel helpers, grime dither,
shadow/highlight tones) ← `PaperDollGear.gd` (cloak, shoulders, helmets, boots, trinkets,
held items + rotation) ← `PaperDoll.gd` (tables, API, body parts).
`HeroAnim.gd` picks the animation each physics frame.

**Frame:** 32×28 px. The body is drawn in a centred 16-px column (`OX` = 8,
applied by `_px` via static `_ox`), the same height as the old pack art, so
`PLAYER_HEIGHT` 1.4, mount ride offsets and contact shadow keep their tuning;
the spare width is room for a forward swing. Facing right; `flip_h` mirrors.
Body-column rows: hair 1–3, head 3–8 (5 wide — small head, adult proportions),
neck 9, torso/arms 10–17, hands 18, legs 18–24, boots 25–27.

**Palette:** base/appearance and `GEAR_VISUALS` colours are picked from the master pixel palette (`game_logic/PixelPalette.gd`, the 0x72 pack's 49 colours + 3), and `render_pose` ends with `PixelPalette.quantize(img)`, so every derived shade and grime pixel lands on a pack colour — the hero shares colours with the NPC/enemy sprites (`test_pixel_palette` checks every frame). A custom `appearance` colour is snapped too.

**Look (grounded, not cartoon):** three-tone shading (`_shadow`
darkens and cools, `_light` lightens and warms), and `_fill`'s deterministic
per-pixel grime (`_grain(x, y)` hash, so walking frames don't shimmer). Face:
brow shadow over a single dark eye pixel, stubble dither, set mouth, ear.

**Animations (`ANIMS`: name → fps, loop, poses):** `idle` (1), `walk` (8 @ 12
fps: contact, down, pass, reach per leg), `swing` (4 @ 12, one-shot: backswing
held behind the body, strike, follow-through, recover), `jump` (crouch, rise;
one-shot, holds rise), `fall` (1), `land` (2, one-shot). A pose overrides
`_REST` keys: `bob` (body drop, may be −1), `leg_l/leg_r` (boot lift),
`step_l/step_r` (foot shift), `hand_l/hand_r` (hand offsets — arms are 2-px
Bresenham limbs from shoulder to hand, so raised/punching arms stay attached),
`wpn` (main-hand angle, degrees clockwise from up; drawn upright in a 44-px
scratch image and nearest-neighbour rotated about the grip), `wpn_behind`
(draw the weapon before the torso). `l` = far/back side, `r` = near/front.

**Back view (TID-618):** `BACK_ANIMS` adds `idle_back` / `walk_back`, rendered
from the `idle` / `walk` poses with `back: true` (`render_frame(..., back)`):
no face (`_draw_head_back` — hair over the head, ears), no collar/buckle/vest
seam/trinket, held items drawn behind the body, the cloak hangs over it
(`_draw_cloak_over`), helmets skip face-side details. `HeroAnim.faces_away(dir,
was_back)` is true when a ground direction heads up-screen (camera forward
`(−1, 0, −1)`) more than half as much as sideways; a stop keeps the last facing.
`HeroAnim.facing(anim, back)` maps idle/walk to their twin (one-shots stay
side-on); `is_walk()` covers both walks (footsteps, `IdleLife.hero_bob`).
Player keeps `_back_facing` (never while mounted — the horse is side-on);
RemotePlayer derives it from its XZ net velocity.

**Driving it (Player.gd):** `HeroAnim.pick(mounted, on_floor, vel_y, air_time,
moving, current, playing)`: mounted → idle; airborne → `jump` while rising,
`fall` after `FALL_GRACE` (0.1 s, so slope hops don't flicker); a playing
one-shot (`swing`, `land`) finishes; else walk/idle. `_on_landed` plays `land`
(hard landings only). `GameBus.player_attack_started` (emitted by
`EnemyNPC.engage()` at the start of its 0.4 s alert beat) plays `swing`.
Footsteps fire on walk frames 0 and 4; `IdleLife.hero_bob` lifts the sprite
on passing frames 2–3 / 6–7 (frames bake their own dip on 1 and 5).

**Gear:** `GEAR_VISUALS` maps item id → `{style, main, trim}`. Styles: armour
`vest`/`mail`/`cloak`; shoulders `pauldron`/`plate`/`spiked`; helmet
`cap`/`helm`/`cowl` (`_draw_helmet`, over the hair; frame row 0 spare for
crests); boots `boots`/`greaves`/`spurred` (the item's `main` replaces the
appearance boot colour, then `_draw_boot_gear` adds a shaft, shin plates or
spurs per leg); held
`dagger`/`sword`/`axe`/`staff`/`wand`/`crystal`/`orb`/`buckler`/`shield`;
trinket `necklace`/`flask`/`coin`. Rings are not drawn. Adding an item = one
entry (reuse a style or add a `match` branch); `test_paper_doll` fails if an
item in a `VISIBLE_SLOTS` slot lacks one or draws nothing.

**Draw order:** cloak back → legs (+ boot gear) → (weapon if `wpn_behind`) → torso → trinket
→ back arm, front arm → head → helmet → cloak mantle → shoulders → off-hand → weapon.

**Appearance:** optional Dictionary overriding `DEFAULT_APPEARANCE` colours
(skin, hair, eyes, shirt, trousers, boots, belt). The player picks skin and hair at
New Game (TID-562, `HeroAppearanceScene`) from `SKIN_TONES` / `HAIR_COLOURS`
(palette colours, index 0 = default). Saved as indices in
`SaveManager.hero_appearance` (`{"skin": i, "hair": j}`); `appearance_from()`
turns indices into colours and drops junk, `appearance_of(save)` reads a save,
`frames_for(save)` = `build_frames(gear_of(save), appearance_of(save))` for the
local hero (Player, and the battle token via `idle_texture`).

**API:** `build_frames(gear, appearance)` (every animation; cached per look —
co-op avatars in the same gear share textures), `idle_texture(gear)` (battle
token), `render_frame(gear, look, anim, index)`, `render_pose(gear, look,
pose)`, `gear_of(save_obj)`, `gear_of_record(record)`.

**Live updates:** `SaveManager.equip_item/equip_weapon` emit
`GameBus.equipment_changed(slot, id)`; `Player._on_equipment_changed` calls
`HeroAnim.wear()` (swap frames, keep animation, `SpriteOutline.refresh()`).
