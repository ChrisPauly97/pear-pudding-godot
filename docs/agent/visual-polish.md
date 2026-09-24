# Visual Polish — World Art, Atmosphere & Props

## Key Features

- **Procedural sky**: `ProceduralSkyMaterial` replaces the old flat `BG_COLOR`; sky gradient shifts with day/night cycle.
- **Distance fog**: Depth fog tied to sky color; updates each `DayNightCycle` tick.
- **Vignette**: Full-screen edge-darkening via `CanvasLayer(127)` + inline `Shader` on a `ColorRect`.
- **Per-biome color grade**: `Environment.adjustment_brightness/contrast/saturation` set per biome when the player crosses a chunk boundary.
- **Biome prop scatter**: GPU-instanced `MultiMeshInstance3D` per prop type per chunk; 15 % spawn rate, ≤12 instances per type; real pixel-art textures (GID-118/TID-447) via `SpriteRegistry.prop_texture()`, falling back to `TextureGen.prop()` if a slot is missing.
- **Interactable highlights**: Pulsing emissive ring (`CylinderMesh` + inline shader) shown on the nearest interactable within 3 world units of the player.
- **Card illustrations**: 32×32 pixel-art textures per card archetype, wired into `CardRegistry` at load time and displayed in `CardViewBuilder`. Real sprites (GID-118/TID-447) via `SpriteRegistry.card_illustration_texture()`, falling back to `TextureGen.card_illustration()`.
- **World terrain textures**: the shared terrain shader's grass, hill-side, wall-side, wall-top, and path/road textures are real, seamlessly-tiling sprite-pack art (GID-118) — see `docs/agent/terrain-rendering.md` Asset Requirements and `CREDITS.md`.
- **Battle backdrop**: the card board's background is a per-biome, day/night patch of ground seen from overhead, painted by one full-screen shader out of the world's own terrain tiles and prop sprites, instead of the flat `Color(0.1, 0.1, 0.15)` rect it was through GID-125.
- **Chest & door sprites**: `Chest.gd` and `Door.gd` render as billboard `Sprite3D`s (0x72 pack chest/door art, GID-118) instead of flat-colored `BoxMesh` geometry, falling back to the original procedural boxes if the sprites are missing. See `docs/agent/inventory-and-deck.md` (chest open ceremony) and `docs/agent/named-maps-and-dungeons.md` (door rendering).

- **Weather drives the atmosphere** (GID-129/TID-486): each weather id reshapes fog density/colour, sky overcast, sun/moon energy, shadow opacity, ambient tint and grass wind (strength + steady lean) through one `WeatherLook` table, blended over 4 s by `DayNightCycle`.
- **Sun arc & golden hour** (GID-129/TID-485): tilted sun arc (NE rise, noon leaning away from the camera, SW set) so shadows read diagonally all day; three-stop golden-hour sun colour; PSSM 2-split sun shadows on High with tuned bias, low-res moon shadows on High.
- **Graphics Quality tiers** (GID-129/TID-484): one Low / Medium / High setting decides which atmosphere effects run; Medium is the phone default, High the desktop default. Forward+-only effects are forced off on the Mobile/Compatibility renderers regardless of tier.

## How It Works

### Graphics Quality Tiers (`game_logic/GraphicsQuality.gd`) — TID-484

The single source of truth for which atmosphere effects run. All-static module (preload it, no `class_name`).

- **Setting:** `save_manager.settings["graphics_quality"]` (`GraphicsQuality.SETTING_KEY`), int 0 Low / 1 Medium / 2 High. Missing, non-numeric or out-of-range values fall back to `default_tier(is_mobile)`: **Medium on mobile/android, High elsewhere** (`tier_from_setting`; floats from JSON are accepted).
- **Table:** `TIERS[tier]` — every tier has the same keys (`test_graphics_quality` asserts it and that no cost knob drops as the tier rises):

| Knob | Low | Medium | High | Read by |
|---|---|---|---|---|
| `sun_shadows` | off | off | on | `apply()` |
| `shadow_mode` | ORTHOGONAL | PSSM_2_SPLITS | PSSM_2_SPLITS | `apply()` |
| `shadow_atlas_size` | 1024 | 2048 | 4096 | `apply()` → `RenderingServer.directional_shadow_atlas_set_size` |
| `soft_shadow_quality` | HARD | SOFT_VERY_LOW | SOFT_LOW | `apply()` → `directional_soft_shadow_filter_set_quality` |
| `shadow_max_distance` | 45 | 50 | 55 | `apply()` — iso ground sits ~24–45 units deep (ortho size 15, camera 34.6 from player) |
| `shadow_split_1` | 0.7 | 0.7 | 0.7 | `apply()` — near cascade ends just past the player's depth |
| `shadow_blend_splits` | off | off | on | `apply()` |
| `shadow_bias` / `shadow_normal_bias` | 0.15 / 1.6 | 0.1 / 1.3 | 0.08 / 1.0 | `apply()` — coarser atlas, more bias (terrain acne) |
| `moon_shadows` | off | off | on | `apply(..., moon)` — orthogonal, bias ×1.5, opacity 0.5 |
| `ssao` *(Forward+ only)* | off | off | on (intensity 1.0, radius 1.0) | `apply()` |
| `volumetric_fog` *(Forward+ only)* | off | off | off | `apply()` — TID-488 turns High on once tuned against the glow threshold |
| `glow` | off | on | on | `apply()` |
| `msaa_3d` | disabled | 4x | 4x | `apply()` → viewport (4x = project.godot default) |
| `particle_scale` | 0.5 | 0.75 | 1.0 | `scaled_amount()` — weather particles now; TID-493 ambient particles |
| `ambient_particles` | off | on | on | TID-493 |
| `sun_rays` | OFF | SCREEN | VOLUMETRIC | TID-488 (`SUN_RAYS_*`) |
| `max_night_lights` | 0 | 4 | 8 | TID-489 (Mobile per-mesh limit is 8) |
| `night_light_shadows` | off | off | off | TID-489 |

- **Renderer clamp:** `clamp_to_renderer(knobs, method)` turns every `FORWARD_PLUS_ONLY` key (`ssao`, `volumetric_fog`) off and downgrades `sun_rays` VOLUMETRIC → SCREEN unless the method is `"forward_plus"`. `knobs_for(tier, method)` returns a clamped **copy**; `current_knobs(setting)` uses the platform and `RenderingServer.get_current_rendering_method()`.
- **Apply:** `apply(knobs, env, sun, viewport, moon = null)` writes glow/SSAO/volumetric fog to the Environment, shadow enable/mode/distance/split/blend/bias to the sun, shadow enable + an orthogonal low-res map to the moon, MSAA to the viewport and the shadow atlas size + soft-filter quality to the RenderingServer (global). Any argument may be null.
- **WorldScene wiring:** `apply_graphics_quality()` runs in `_ready()` right after `_setup_environment()` (it replaced the old `OS.has_feature("mobile")` sun-shadow switch — Medium keeps that exact behaviour) and again on `GameBus.graphics_quality_changed(tier)`, emitted by the Settings "Graphics Quality" option row, so a change applies live. The resolved knobs are cached; effects read them via `WorldScene.graphics_knobs()` — **never check the platform or renderer per effect**. `_on_weather_changed` scales the weather `GPUParticles3D.amount` by `particle_scale` before adding it.
- **Adding a knob:** add the key to all three tier dicts (the test fails otherwise); if it needs Forward+, add it to `FORWARD_PLUS_ONLY`.

### Sun Arc & Golden Hour (`DayNightCycle`) — TID-485

- **Tilted arc:** `DayNightCycle.sun_direction(time_of_day)` (static, unit vector toward the sun) replaces the old single-X-axis rotation, which rose due south, went straight overhead at noon (shadows hidden under objects) and cast dawn shadows along the iso camera's depth axis. The sun now rises along `SUN_RISE_DIR` (NE, −Z is north), sets opposite (SW), and at noon leans `NOON_TILT` = 30° toward `SUN_NOON_LEAN` (NW = the camera's horizontal forward), so dawn/dusk shadows stretch sideways across the screen and midday shadows fall toward the viewer. Its height has the sign of `sin((t − 0.25)·TAU)`, so it crosses the horizon exactly when `is_night()` flips; energy still uses that sine (cap 1.1, glow-threshold note unchanged).
- **Light bases:** `light_basis(travel)` = `Basis.looking_at(travel, UP)` (falls back to FORWARD as up when near-vertical). Sun gets `light_basis(-sun_dir)`, the moon `light_basis(sun_dir)` (opposite the sun). Written only when the direction changes (`_cached_sun_dir`), like the other cached writes. Never `look_at` on these nodes.
- **Golden ramp:** `sun_color_for(sun_h)` — three stops `SUN_HORIZON_COLOR` (0.95, 0.40, 0.14) → `SUN_GOLDEN_COLOR` (1.0, 0.74, 0.42) → `SUN_DAY_COLOR` (1.0, 0.95, 0.85) over `sun_h < GOLDEN_BAND` (0.45), smoothstepped; the old ramp only warmed below `sun_h` 0.2. The sun colour also feeds `grass_day_tint`, so the unshaded grass warms with it.
- **Shadow casters:** terrain chunks and entity `MeshInstance3D`s cast; Player/Avatar/mount sprites, grass, props and beacons opt out (`SHADOW_CASTING_SETTING_OFF`). Unshaded meshes don't receive shadows (BID-060).
- **Tests:** `tests/unit/test_day_night_sun.gd` pins the arc against the iso camera (unit length, horizon ↔ `is_night`, noon not overhead and leaning away from camera, dawn along screen-right, sunrise/sunset opposite, basis −Z = travel, ramp monotonic). `test_graphics_quality` covers the shadow knobs and moon apply.
- **Visual check:** a Compatibility-renderer (llvmpipe/xvfb) capture ran clean but is not representative — it over-saturates versus Forward+ and the spawn meadow has no shadow casters — so tune by eye on a real GPU.

### Weather Look (`game_logic/WeatherLook.gd`, `DayNightCycle`) — TID-486

- **Table:** `WeatherLook.CLEAR` holds every key at its neutral value; `OVERRIDES[weather_id]` lists only what that weather changes. `look_for(id)` returns a fresh CLEAR-merged copy (unknown / `""` = clear). Keys:

| Key | Clear | Applied by `DayNightCycle._apply_lighting()` as |
|---|---|---|
| `tint` | white | multiplies the day/night ambient colour (was `WeatherParticles.get_screen_tint`, now a delegate) |
| `fog_density_mult` | 1.0 | × the env's setup-time fog density (0.004); clamped to `MAX_FOG_DENSITY_MULT` 3.0 so the player stays readable |
| `fog_color`, `fog_color_weight` | grey, 0 | fog light colour = sky-derived colour lerped toward `fog_color` (dimmed at night) |
| `sky_overcast` | 0 | sky top/horizon colours grey toward `fog_color` (dimmed by the day curve so stormy nights stay dark) |
| `sun_energy_mult` | 1.0 | × sun **and** moon energy (also darkens `grass_day_tint`) |
| `shadow_opacity_mult` | 1.0 | × the sun's base `shadow_opacity` (0.2, set in `WorldScene._ready` before DNC setup) — overcast light, softer shadows |
| `wind_direction` | (0.94, 0.33) | grass `wind_direction` uniform via `GrassBlades.set_wind_direction` (WorldScene, on change). Clear used to be `Vector2.ZERO`, which `normalize()`d to NaN in the grass shaders after rain ended |
| `wind_scale` | 1.0 | global shader param `grass_wind_scale` (× per-material `wind_strength`) |
| `wind_lean` | 0.0 | global shader param `grass_wind_lean` — steady downwind bend at the blade tip, so storms push grass over instead of only swaying faster |

  Heavy variants (heavy_rain, sandstorm, volcanic, blizzard) are foggier, darker and at least as windy as their light pair; `test_weather_look` pins that, key-set consistency, ranges and the fog cap.
- **Blend:** `DayNightCycle.set_weather(id, instant = false)` starts a `WEATHER_BLEND_SECONDS` (4 s) smoothstep blend from the currently applied look (`WeatherLook.blend(a, b, t)` lerps float / Color / Vector2 keys; anything else snaps at t = 0.5). `tick(delta)` (the old `weather_tint` argument is gone) advances the blend **per frame** and re-applies lighting immediately while blending; the 2 Hz time-of-day update continues as before. Every write is behind a write-on-change cache (`_cached_fog_density`, `_cached_fog_color`, `_cached_shadow_opacity`, `_cached_wind_scale/_lean`, …). `weather_look()` exposes the applied look to later tasks.
- **Wiring:** `WorldScene._on_weather_changed(id)` swaps particles, calls `_dnc.set_weather(id)` and sets the grass direction. Co-op clients already route the host-synced weather id there (`CoopSession`), so there is no extra RPC. Globals `grass_wind_scale`/`grass_wind_lean` are registered by both `GrassBlades._init_material()` and `DayNightCycle.setup()`.
- **Tiers:** only Environment/light params and two global floats — works identically on every tier and renderer.
- **Extending (TID-487 wetness, lightning, …):** add the key with its neutral value to `CLEAR`, add per-weather values to `OVERRIDES`, read `look["key"]` in the consumer (`DayNightCycle` or `dnc.weather_look()`). The blend and the key-set test pick it up automatically.

### Sky & Fog (`WorldScene._setup_environment`, `DayNightCycle`)

`_setup_environment()` creates a `ProceduralSkyMaterial` at startup, assigns it to a `Sky` resource, and sets `env.background_mode = BG_SKY`. Fog is enabled on the same `Environment` with `fog_density=0.004`. `DayNightCycle._apply_lighting()` calls `_get_sky_mat()` (lazy getter that resolves the sky chain) and updates `sky_top_color`, `sky_horizon_color`, `ground_horizon_color`, and `fog_light_color` each half-second tick.

### Vignette (`WorldScene._setup_vignette`)

A `CanvasLayer` at layer 127 holds a `ColorRect` covering the full viewport. An inline `Shader` on its `ShaderMaterial` computes `d = length(UV - 0.5)` and darkens the corners: `ALPHA = smoothstep(0.35, 0.75, d) * 0.45`. No `.gdshader` file, no `.uid` required.

### Per-biome Color Grade (`WorldScene._apply_biome_color_grade`)

`BiomeDef.ADJ_PARAMS[biome_id]` stores per-biome `{brightness, contrast, saturation}` dicts. `WorldScene._on_player_chunk_changed()` calls `_apply_biome_color_grade(biome_id)` which writes these to `env.adjustment_*`. `BiomeDef` is preloaded with `const BiomeDef = preload(...)` — never use class_name.

### Prop Scatter (`ChunkRenderer`)

`prepare_terrain()` (worker thread) calls `_compute_prop_positions()` which iterates `TILE_GRASS` cells, applies a seeded LCG hash, and samples a 15 % spawn chance. Up to 12 positions per prop type are collected, returned in the `"props"` dict alongside the mesh/hmap results. `build_visual()` calls `_build_props()` on the main thread, which creates one `MultiMeshInstance3D` per prop type with a billboard `StandardMaterial3D` + `TextureGen.prop(key)` texture. Visibility capped at `ENTITY_VISIBILITY_END`.

Prop types per biome:
| Biome | Types |
|---|---|
| Grasslands | rock, flower |
| Forest | mushroom, fern |
| Desert | cactus, thorn |
| Scorched | ash_pile, ember |
| Mountains | boulder, lichen |

### Interactable Highlights (`WorldEntityBase`, entity scripts, `Player`)

`WorldEntityBase.build_highlight_ring(parent, radius)` creates a thin `CylinderMesh` (cap_top=false, cap_bottom=false) with an inline spatial shader that pulses emissive yellow via `sin(TIME * 4.0)`. Returns the `MeshInstance3D` (hidden by default). `WorldEntityBase.set_highlighted(on)` shows/hides `_ring`.

All 6 interactable entities call `add_to_group("interactable")` in `_ready()` and store `_ring`. Entities extending `WorldEntityBase` (Merchant, Townsperson, BountyBoard) call `build_highlight_ring(self, r)` directly (inherited). Entities extending `Node3D` (Chest, Door, Waystone) preload `_WEB = preload(WorldEntityBase)` and call `_WEB.build_highlight_ring(...)`.

`Player._scan_interactables()` runs at 7 Hz (`_SCAN_INTERVAL = 1/7`), iterates the `"interactable"` group, finds the nearest node within `_INTERACT_RADIUS = 3.0` world units, and calls `set_highlighted(true/false)`.

### Battle Backdrop (`BattleBackdrop`, `battle_backdrop.gdshader`) — GID-126

`BattleScene.arena._setup_backdrop()` runs in `_ready()` and hands `$Background` (the
`ColorRect` that used to *be* the background) to
`BattleBackdrop.apply(rect, biome, is_night)`, which installs a `ShaderMaterial`
running `assets/shaders/battle_backdrop.gdshader`. The rect keeps its flat
`color` underneath, so a missing or stripped shader degrades to the old look
rather than to nothing.

The biome and time of day come from `GameState.battlefield_biome` /
`is_night` — the pair Battlefield Resonance (GID-059) already stamps at
engagement — so the backdrop needs no context of its own and cannot disagree
with the rule the side panel is showing.

**The framing is overhead**, not a landscape behind the board. TID-475 shipped
a horizon-and-sky vista first; it fought the layout, because the board is a
flat arrangement of cards and the vista implied a camera looking across the
scene the cards were standing up in. TID-476 replaced it with a patch of
ground seen from directly above — the surface the cards are laid out on.
Nothing in the shader is a horizon any more.

**No new art.** The ground tiles `assets/textures/pixel_art/*.png` (the
seamless 16×16 terrain tiles the 3-D world is built from) and the scatter is
`assets/textures/props/prop_*.png` (the sprites `ChunkRenderer` instances), one
pair per biome, matching `BiomeDef.PROP_SETS`.

**Shader layers**, in the order `fragment()` paints them:

| Layer | What it does |
|---|---|
| Ground | The biome tile repeated flat in "square units" (`p = vec2(uv.x * aspect, uv.y)`), so tiles stay square on any aspect ratio. Per-tile brightness jitter plus broad value noise breaks the period |
| Arena | A rounded-rectangle SDF under the board. Inside is tinted toward bare earth and lifted slightly; the falloff is wide and soft on purpose |
| Props | The biome's two sprites on a jittered grid, upright, with a soft contact shadow, thinned to a quarter inside the arena so cards sit on clean ground |
| Battle line | The enemy/player divider drawn as a line scored into the earth: thin lit core, wide soft bloom, tapered at both ends |
| Lighting | A pool of biome-coloured light over the arena, a faint cast of the same light over everything, and drifting motes after dark |
| Hold-back | Vignette (weighted to darken the left/right margins, which is what the side panel's label text reads against), then a global `mix` toward `dim_color` so cards stay legible |

**Palette** — `BattleBackdrop.PALETTE`, one entry per biome id plus
`NEUTRAL = -1`. Scatter density, light colours and `dim` live in the table; the
*tints* do not — ground colour is `BiomeDef.GRASS_TINT[biome] × gain` and the
trodden arena is `BiomeDef.WALL_TINT[biome]`, the game's own bare-stone/earth
palette. Only the vault, which has no biome to borrow from, sets an
`arena_tint` override.

Four scalars exist because a 2-D backdrop is not a lit 3-D surface:

- `ground_gain` — the `BiomeDef` tints multiply lit terrain; with no light to
  multiply, the darker biomes need lifting back into a readable range.
- `ground_desat` — the terrain PNGs carry a strong hue of their own (the hill
  side is orange dirt), so a snow-white mountain tint over them still reads
  orange. Pulling the sample toward grey first is what lets one 16×16 source
  serve several biomes.
- `NIGHT_GROUND_GAIN` (0.58) — the tints describe sunlit terrain, so without it
  a night battlefield keeps a noon-bright meadow under a moonlit sky.
- `NIGHT_PROP_LIGHT` / `DAY_PROP_LIGHT` — props need the same darkening as the
  ground or they float over it instead of standing on it.

`ground_avg`, which detail fades to instead of the aliased texel soup a
minified un-mipmapped 16×16 tile gives, is **measured** on the CPU from the
texture rather than guessed at a constant — a constant was far too bright for
the dungeon's stone floor.

**Things that were tried and are worse**, so they do not get reintroduced:

- *Cross-fading a second, rotated sampling of the ground tile* to break the
  repeat. On anything with strong seams — flagstones especially — you see both
  grids at once and it reads as a rendering bug. Per-tile hash jitter does the
  same job with one fetch.
- *A stroked arena edge.* A crisp outline reads as a UI frame drawn over the
  ground rather than as earth trodden flat. The edge is a wide soft falloff.
- *Tinting the arena without lifting it.* On a biome whose bare earth is close
  to its ground colour (sand on sand) the tint alone is invisible.

**Cost**: no per-frame CPU work at all. `SCREEN_PIXEL_SIZE` gives the shader its
own aspect ratio, so nothing has to be re-pushed on resize. The prop layer
resolves in a single cell test and a single texture fetch — `prop_scale ≤ 0.5`
plus the jitter bounds keep every prop wholly inside its own cell, so no
neighbouring cell can ever reach the pixel being shaded. `test_battle_backdrop`
enforces the `prop_scale` bound.

**Previewing**: `tools/preview_battle_backdrop.gd` renders one PNG per variant
(5 biomes × day/night + the vault). It needs a real or virtual display — the
headless driver has no rasteriser, so the shader would never execute:

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
  -s tools/preview_battle_backdrop.gd -- --out=/tmp/backdrops
```

Captures pass `animate = false`, which freezes the shader clock so repeated
runs are comparable.

**A compile guard is necessary.** A shader that fails to compile still loads as
a `Resource` and still accepts `set_shader_parameter` for anything, so nothing
about `apply()` looks wrong — the scene just silently shows its fallback
colour. Godot exposes no compile status to GDScript, but a failed parse
registers no uniforms, so `test_the_shader_actually_compiles` compares
`Shader.get_shader_uniform_list()` against the `uniform` declarations in the
source file. That is what caught a sampler used in a ternary, which Godot's
shader language rejects.

### Card Illustrations (`SpriteRegistry`, `TextureGen`, `CardRegistry`, `CardViewBuilder`)

`CardRegistry._ensure_loaded()` assigns illustrations after loading each card resource,
via `SpriteRegistry.card_illustration_texture(illus_key, magic_branch)` first
(GID-118/TID-447), falling back to `TextureGen.card_illustration(illus_key, magic_branch)`
if the registry returns `null`. Spell cards use key `"spell"` with the card's
`magic_branch`; creature archetypes use the card's `id` (`ghost`/`skeleton`/`zombie`/`ghoul`).

`SpriteRegistry` maps creature keys directly to real pixel-art PNGs
(`assets/textures/cards/card_{ghost,skeleton,zombie,ghoul}.png`) and spell keys to
per-branch rune PNGs (`rune_{dawn,dusk,ember,ash}.png`, sourced from game-icons.net,
CC BY 3.0 — see `CREDITS.md`). `TextureGen`'s procedural generators (wisp silhouette,
bone figure, green shambler, hunched creature, swirling rune circle) remain as the
fallback for any key/branch the registry doesn't recognize.

`CardData.to_template_dict()` includes `"illustration": illustration` in both light and dark face dicts. `CardViewBuilder.build_card_vbox()` adds a `TextureRect` (`_vh * 0.06` height) when illustration is non-null.

## Integrations with Other Features

- `DayNightCycle` drives both sky material colors and fog light color every half-second, and applies the current `WeatherLook` (fog density/colour, overcast, sun/moon energy, shadow opacity, grass wind globals) — per frame while a weather change blends in.
- `ChunkRenderer.prepare_terrain()` is a static worker-thread function — `_compute_prop_positions()` is also static, accesses only `BiomeDef` const arrays and the passed tile lookup callable.
- `WorldEntityBase` is the shared base for all interactable NPCs; direct `Node3D` entities preload it for the static `build_highlight_ring` helper.
- `CardRegistry` runs `_ensure_loaded()` lazily on first access; illustration assignment happens once per session at that point, cached by `TextureGen._cached()`.
- `BattleBackdrop` consumes Battlefield Resonance's context (`GameState.battlefield_biome` / `is_night`, GID-059) and `BiomeDef`'s terrain tints and prop sets. It writes nothing back and holds no state — `apply()` is a pure function of (rect, biome, night).
- `BattleBackdrop.DIVIDER_Y` is tied to `BattleScene.tscn`'s `Divider` anchor, and `ARENA_CENTER`/`ARENA_HALF` to the card area's extent (which ends at x = 0.86, where the side panel starts); `test_battle_backdrop` fails if either drifts.

- `GraphicsQuality` is read by `WorldScene` (environment, sun, weather particles) and written by `SettingsScene` (option row + `GameBus.graphics_quality_changed`). Later GID-129 effects (shadows, sun rays, night lights, ambient particles) read their knobs from `WorldScene.graphics_knobs()`.

## Asset Requirements

The battle backdrop (GID-126) adds `assets/shaders/battle_backdrop.gdshader`
and its `.uid` sidecar, and no image files at all — it reuses
`assets/textures/pixel_art/*.png` for the ground and
`assets/textures/props/prop_*.png` (plus `burial_mound.png` for the vault) for
the skyline. Those PNGs are imported without mipmaps, which the shader handles
itself by fading texel detail out with `fwidth()`; do **not** turn mipmaps on
for them just for the backdrop, since the 3-D terrain shader samples the same
files with `filter_nearest`.

Originally all textures were generated procedurally at runtime via `TextureGen._cached()`.
Since GID-118, **character/enemy/NPC sprites use real pixel art** from
`assets/textures/characters/*.png` via `game_logic/SpriteRegistry.gd` (see
`docs/agent/art-sprites.md`); `TextureGen` remains the fallback for unmapped types
and still generates props, mount, and card illustrations until TID-447 wires those
slots. No `.gdshader` or `.uid` sidecars are needed (PNGs get `.import` sidecars from
the editor/headless import; those are committed).
