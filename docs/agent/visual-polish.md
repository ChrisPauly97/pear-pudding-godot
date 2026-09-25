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

- **Ambient touches** (GID-129/TID-493): fireflies blink around the player on grassland/forest nights (still air only, blooming past the glow threshold); forest leaves tumble down the current weather wind; the player kicks a dust puff on moving off and trails soft dust (which never rendered before — no draw pass). Scaled by `particle_scale`, ambient parts off on Low.
- **Night lights** (GID-129/TID-489): door lanterns, waystones, mana wells and the wilderness camp fire glow from dusk to dawn with per-style flicker. Warm light pools (Medium 4 / High 8) light terrain, grass, props and sprites alike through a depth-reconstructing additive volume; Low keeps just the glowing lamp dots.
- **Sun rays** (GID-129/TID-488): warm light shafts at dawn and dusk that fade out before midday and under heavy weather. Medium draws cheap screen-space shafts (10 taps, hidden when off); High adds Forward+ volumetric fog lit only by the shadowed sun.
- **Rain wetness & storm lightning** (GID-129/TID-487): rain darkens and glosses the terrain (puddle patches, soaks in ~20 s, dries over ~90 s); heavy rain and volcanic weather flash (blue-white / red) every 8–25 s with delayed, distance-pitched thunder; a Reduce Flashing setting keeps the thunder but drops the flash.
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
| `volumetric_fog` *(Forward+ only)* | off | off | on | `apply()` enables it; `SunRaysFx` (TID-488) then drives density and switches it off whenever the rays are off |
| `glow` | off | on | on | `apply()` |
| `msaa_3d` | disabled | 4x | 4x | `apply()` → viewport (4x = project.godot default) |
| `particle_scale` | 0.5 | 0.75 | 1.0 | `scaled_amount()` — weather particles, fireflies, leaves, player dust (TID-493) |
| `ambient_particles` | off | on | on | `AmbientTouches` fireflies/leaves; player foot trail + move-start puff (TID-493) |
| `sun_rays` | OFF | SCREEN | VOLUMETRIC | `SunRaysFx.set_mode` (TID-488, `SUN_RAYS_*`) |
| `max_night_lights` | 0 | 4 | 8 | `NightLights` module: rigs that draw a light pool (TID-489) |
| `night_light_shadows` | off | off | off | `NightLights`: adds a shadowed `OmniLight3D` per pool rig (reserved, off everywhere) |
| `ray_samples` | 0 | 10 | 16 | `SunRaysFx.set_quality` → `sun_rays.gdshader` `samples` (TID-496) |
| `moon_rays` | off | off | on | `SunRaysFx.set_quality` — faint cool screen rays at night (TID-496) |
| `ground_mist` | off | on | on | `AmbientTouches` ground mist emitter (TID-497) |
| `fake_shafts` | 0 | 6 | 10 | `FakeVolumetrics` beam count (TID-495); zeroed by `FAKE_VOLUMETRIC` wherever real `volumetric_fog` runs |
| `light_halos` | off | on | on | `NightLights` depth-faded halo per rig (TID-495) |
| `depth_fog` | off | off | on | `FakeVolumetrics` full-screen depth-fog pass (TID-498); zeroed by `FAKE_VOLUMETRIC` wherever real `volumetric_fog` runs |
| `fxaa` | off | on | on | `apply()` → `viewport.screen_space_aa` FXAA — smooths alpha-cut sprite and shader edges MSAA misses (GID-131 / TID-501) |
| `taa` *(Forward+ only)* | off | off | on | `apply()` → `viewport.use_taa` (TID-501) |
| `debanding` | off | on | on | `apply()` → `viewport.use_debanding` — dithers sky/fog/mist gradient steps on 8-bit panels (TID-502) |
| `lit_world` | off | off | on | `GrassBlades.set_lit` (lit grass shader variants) + `ChunkRenderer.set_lit_world` (props/landmarks per-pixel + receive shadows) — BID-060 (GID-131 / TID-508) |
| `height_fog` | off | on | on | `DayNightCycle.set_height_fog` — valley mist (GID-130 / TID-494) |

- **Renderer clamp:** on Forward+ with `volumetric_fog` on, `clamp_to_renderer` merges `FAKE_VOLUMETRIC` (`fake_shafts: 0`, `depth_fog: false`) so the stand-ins never stack with the real fog (desktop Medium keeps them). Otherwise it turns every `FORWARD_PLUS_ONLY` key (`ssao`, `volumetric_fog`, `taa`) off and downgrades `sun_rays` VOLUMETRIC → SCREEN unless the method is `"forward_plus"`. `knobs_for(tier, method)` returns a clamped **copy**; `current_knobs(setting)` uses the platform and `RenderingServer.get_current_rendering_method()`.
- **Apply:** `apply(knobs, env, sun, viewport, moon = null)` writes glow/SSAO/volumetric fog to the Environment, shadow enable/mode/distance/split/blend/bias to the sun, shadow enable + an orthogonal low-res map to the moon, MSAA to the viewport and the shadow atlas size + soft-filter quality to the RenderingServer (global). Any argument may be null.
- **WorldScene wiring:** `apply_graphics_quality()` runs in `_ready()` right after `_setup_environment()` (it replaced the old `OS.has_feature("mobile")` sun-shadow switch — Medium keeps that exact behaviour) and again on `GameBus.graphics_quality_changed(tier)`, emitted by the Settings "Graphics Quality" option row, so a change applies live. The resolved knobs are cached; effects read them via `WorldScene.graphics_knobs()` — **never check the platform or renderer per effect**. `_on_weather_changed` scales the weather `GPUParticles3D.amount` by `particle_scale` before adding it.
- **Opt-in Forward+ on mobile (GID-130 / TID-499, `game_logic/RendererOptIn.gd`):** the renderer is fixed at boot, so project.godot sets `application/config/project_settings_override = "user://renderer_override.cfg"`. Settings (mobile only) shows an "Advanced Renderer (restart)" toggle whose state **is** that file: `set_enabled(true)` writes `[rendering] renderer/rendering_method.mobile="forward_plus"` (only the `.mobile` key, so desktop is untouched), `set_enabled(false)` deletes it. The next launch runs Forward+, `clamp_to_renderer` passes the Forward+-only knobs through, and High gets real volumetric fog/SSAO (the GID-130 stand-ins then yield via `FAKE_VOLUMETRIC`). Crash guard in `SceneManager._guard_renderer_opt_in()` (mobile only): `on_boot(running_method)` reverts the override when the previous Forward+ boot left `user://renderer_boot.lock` behind (`REVERT_CRASH`) or when Godot fell back to another renderer (`REVERT_FALLBACK` — `fallback_to_opengl3` lands on Compatibility, worse than Mobile); otherwise it drops the lock and a `BOOT_OK_SECONDS` (20 s) timer calls `mark_boot_ok()`. Tests: `test_renderer_opt_in.gd`.
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
| `wetness` | 0.0 | ground wetness **target** (rain 0.6, heavy_rain 1.0) — not blended over 4 s; see "Rain Wetness" below |
| `lightning` | 0.0 | storm strength (heavy_rain 1.0, volcanic 0.7); > 0 runs the strike scheduler — see "Storm Lightning" |
| `lightning_color` | blue-white | colour the flash pulls ambient and sky toward (volcanic: red-orange) |

  Heavy variants (heavy_rain, sandstorm, volcanic, blizzard) are foggier, darker and at least as windy as their light pair; `test_weather_look` pins that, key-set consistency, ranges and the fog cap.
- **Blend:** `DayNightCycle.set_weather(id, instant = false)` starts a `WEATHER_BLEND_SECONDS` (4 s) smoothstep blend from the currently applied look (`WeatherLook.blend(a, b, t)` lerps float / Color / Vector2 keys; anything else snaps at t = 0.5). `tick(delta)` (the old `weather_tint` argument is gone) advances the blend **per frame** and re-applies lighting immediately while blending; the 2 Hz time-of-day update continues as before. Every write is behind a write-on-change cache (`_cached_fog_density`, `_cached_fog_color`, `_cached_shadow_opacity`, `_cached_wind_scale/_lean`, …). `weather_look()` exposes the applied look to later tasks.
- **Wiring:** `WorldScene._on_weather_changed(id)` swaps particles, calls `_dnc.set_weather(id)` and sets the grass direction. Co-op clients already route the host-synced weather id there (`CoopSession`), so there is no extra RPC. Globals `grass_wind_scale`/`grass_wind_lean` are registered by both `GrassBlades._init_material()` and `DayNightCycle.setup()`.
- **Tiers:** only Environment/light params and two global floats — works identically on every tier and renderer.
- **Extending:** add the key with its neutral value to `CLEAR`, add per-weather values to `OVERRIDES`, read `look["key"]` in the consumer (`DayNightCycle` or `dnc.weather_look()`). The blend and the key-set test pick it up automatically.

### Ambient Touches (`game_logic/AmbientParticles.gd`, `scenes/world/modules/AmbientTouches.gd`, `Player`) — TID-493

- **Factories (`AmbientParticles`, static, `WeatherParticles.make()` shape):** `make_fireflies()` (36, 5 s, world-space box 22×1.6×22 around the player, turbulence drift, blink `color_ramp` with two pulses, additive unshaded billboard with albedo ×3 so `FIREFLY_COLOR` peaks well above the 1.2 glow threshold), `make_leaves()` (28, 6 s, box 28×1×28 at +7, random angle + spin, turbulence flutter, `color_initial_ramp` green→amber→rust), `make_dust_puff(amount)` (one-shot, explosive). Draw meshes (dust 1×1, firefly 0.22, leaf 0.16×0.10) with their materials (`BILLBOARD_PARTICLES`, `vertex_color_use_as_albedo`, radial soft-dot texture) and ramp textures are built once in `_ensure_shared()` and shared by every emitter. `dust_mesh()` + `style_dust(pm)` (alpha fade-in/out ramp, swell curve) are what `Player` uses. `apply_wind(pm, dir, scale)` points leaf drift along the WeatherLook grass-wind direction, speed and sideways gravity scaling with `wind_scale` (0.5–3); a zero vector falls back to +X, never NaN.
- **Rules:** `firefly_level(night, biome, weather)` — grassland (0) / forest (1) only, 0 in any precipitation or blowing weather, `clamp((night − 0.4) / 0.5)` so they arrive after the lamps (night from `NightLightMath.night_factor`). `leaf_level(biome, weather, wind_scale)` — forest only, `0.45 + 0.25 × wind_scale` capped at 1, none in snow/blizzard.
- **Module (`AmbientTouches`, `WorldScene.ambient`):** every 0.5 s `refresh()` reads `graphics_knobs()`, `_current_biome` (infinite world only; named maps get nothing), `WeatherManager.current_weather`, the night factor and the blended `_dnc.weather_look()` wind. Emitters are created lazily on first need, parented to `_world._entity_root`, and never freed (reused). Density fades via `amount_ratio`; `amount` is only rewritten when the knobs change (writing it restarts the system). `emitting`/`visible` go off at level 0, so Low, deserts and daytime cost nothing. `_process` keeps both emitters on the player. When the knob dictionary's hash changes it calls `Player.apply_particle_knobs(knobs)`.
- **Player dust:** foot/mount/landing dust now has the shared draw pass (it had none, so it was invisible), fades and swells, and sits 0.2 above the feet so puffs don't clip into the ground. New `_start_dust` puff (8) fires when the player starts moving on the floor. `apply_particle_knobs` scales foot 10 / mount 20 / landing 14 / start 8 by `particle_scale`; the foot trail and start puff are ambient and go off with `ambient_particles`, landing and mount dust stay as movement feedback.
- **Ground mist (GID-130 / TID-497):** `make_mist()` — 14 large (5×2.6) faint billboard puffs, 12 s lifetime, world-space box 30×0.5×30 lifted 0.4 above the player, proximity fade 1.2 so they melt into the ground, alpha ramp peaking at `MIST_ALPHA` 0.16. `apply_mist_wind()` creeps them along the WeatherLook wind (0.15–0.45 × wind scale). `mist_level(sun_h, biome, weather)`: `MIST_BIOMES` grass 0.7 / forest 1.0 / mountains 0.8 (none in desert or scorched), × `(1 − smoothstep(0.1, 0.35, sun_h))` (night + dawn, gone by mid-morning), × `MIST_WEATHER` (rain 1.25, heavy rain 1.1, snow 0.6, ash 0.7), 0 in `MIST_BLOCKING` (sandstorm, dust devil, volcanic, blizzard). `set_mist_tint(mist_color(sun_h))` recolours the shared draw pass from night blue-grey to pale warm white. AmbientTouches gates it on the `ground_mist` knob (not `ambient_particles`) and the infinite world, fades via `amount_ratio` like the others, and exposes `mist_level()`.
- **Also fixed:** `WeatherParticles.make()` built its tinted billboard `StandardMaterial3D` but never assigned it; the mesh now carries it.
- **Tests:** `tests/unit/test_ambient_particles.gd` (firefly/leaf gates, wind mapping incl. zero wind, every factory has draw pass + material + process material, shared mesh reuse, firefly HDR above the glow threshold, tier knobs).

### Night Lights (`game_logic/NightLightMath.gd`, `scenes/world/modules/NightLights.gd`, `night_light_pool.gdshader`) — TID-489

- **Why a fake light:** grass, props, landmarks, WorldItem and most billboards are `unshaded` (BID-060), so a real `OmniLight3D` would only touch the terrain, and Mobile caps real lights at 8 per mesh. A flat ground quad clips on hills and never touches sprites. Instead each pool is an ellipsoid (`SphereMesh`, 12×6, scaled to `radius × 1.08` wide, `radius / 0.75 × 1.08` tall) with `night_light_pool.gdshader`: `unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_front`. The fragment reads `hint_depth_texture`, rebuilds the world position of the opaque surface behind the pixel (`INV_PROJECTION_MATRIX` / `INV_VIEW_MATRIX`, with a `CURRENT_RENDERER == RENDERER_COMPATIBILITY` branch for the −1..1 NDC depth) and adds `light_color × energy × t²`, `t = 1 − |d| / radius` with `d.y × vertical_squash` (0.75, so sprites standing in the pool light up the whole way). Every covered pixel runs exactly once (front faces culled, no depth test). Works on Forward+, Mobile and Compatibility (verified rendering under xvfb/Compatibility); costs one depth copy plus the pools' small screen footprint, and only while a pool is visible.
- **Rules (`NightLightMath`, pure/static):** `STYLES` — `lantern` (warm, r 4.5, e 0.55, flicker 0.14), `campfire` (orange, r 6, e 0.8, flicker 0.32, fast), `waystone` (teal, r 4, e 0.45, slow 0.06 pulse), `mana_well` (blue, r 4, e 0.45, 0.1); each also has `speed` and the glow-dot `height`. `night_factor(sun_h) = 1 − smoothstep(−0.05, 0.15, sun_h)` — lights warm up while the sun is still just above the horizon and are full once it sets. `flicker(t, phase, amount, speed)` — three incommensurate sines, result in `[1 − amount, 1]`. `phase_for(pos)` keeps a light's rhythm stable when it changes rig. `nearest(sources, origin, count, max_dist)` — ground-plane distance, nearest first, input untouched.
- **Manager (`NightLights` module, `WorldScene.night_lights`):** every 0.5 s `refresh()` reads the night factor (from `DayNightCycle.sun_direction(time).y`) and the `max_night_lights` / `night_light_shadows` knobs from `WorldScene.graphics_knobs()` (so a Settings tier change lands within 0.5 s, no signal needed), gathers sources from WorldScene's live dicts via `_valid_node3d` (`_door_nodes` → lantern, `_waystone_nodes`, `_mana_well_nodes`, `_wilderness_camp_node` → campfire; hidden or out-of-tree nodes skipped) and assigns the nearest 8 within 30 units to pooled rigs. Rig = additive billboarded glow dot (radial `GradientTexture2D`, on every tier, nudged 0.4 units along the iso view axis so it draws in front of its own sprite) + pool (first `max_night_lights` rigs) + optional shadowed `OmniLight3D`. `_process` writes each active rig's flicker (pool `energy`, dot alpha, omni energy) — at most 8 uniform writes per frame. In daylight (`night_factor < 0.01`) or with no player every rig is hidden and nothing is gathered. Rigs are parented with `_world.add_child`, so they go away with the scene.
- **Co-op / battles:** purely local (time is already synced). The detached WorldScene isn't in the tree during battles, so nothing runs then.
- **Tests:** `tests/unit/test_night_lights.gd` (night factor, flicker band, style shape, nearest cap/order/range, phase stability, tier caps).

### Sun Rays (`game_logic/SunRayMath.gd`, `scenes/world/SunRaysFx.gd`, `sun_rays.gdshader`) — TID-488

- **Strength (`SunRayMath.strength(sun_h, weather_mult)`):** `smoothstep(0, 0.06, sun_h) × (1 − smoothstep(0.2, 0.6, sun_h)) × weather`. `sun_h` is DayNightCycle's `sin((t − 0.25)·TAU)`: zero at night and below the horizon, near full through the golden hour (t ≈ 0.25–0.30 and 0.70–0.75), gone by sun height 0.6 (t ≈ 0.35 / 0.65) so **midday never hazes** (the glow threshold notes in `_setup_environment` stay untouched: the screen pass is added after tonemapping, the fog is off at midday).
- **Weather:** WeatherLook key `sun_rays` (CLEAR 1.0; rain 0.4, snow 0.5, dust_devil 0.7, ash_fall 0.35, sandstorm 0.2, volcanic 0.1, heavy_rain / blizzard 0.0). Read from `DayNightCycle.weather_look()`, so rays fade with the 4 s weather blend.
- **Orthographic camera:** the sun is never on screen (a point far along the sun direction projects arbitrarily far off-screen). `screen_direction(sun_dir, cam_basis)` projects the sun direction onto the camera plane (x right, y down, plus a fade when it lies along the view axis); `source_uv(dir, aspect)` puts a virtual source 1.2× past the screen edge that direction leaves through. With the TID-485 arc, dawn (NE) shafts stream in from screen-right, dusk (SW) from screen-left, a higher sun from the top.
- **Screen pass (`assets/shaders/sun_rays.gdshader`, Medium + High):** `CanvasLayer` layer 0 (under the HUD at 1, so HUD pixels neither feed nor receive rays; the vignette at 127 still darkens them) with a full-rect `ColorRect`, `blend_add`. Per pixel: angular value-noise shafts around the source (two drifting octaves + a 0.25 soft floor), `exp(−1.6·dist)` falloff, and a 10-tap occlusion march toward the source over 35 % of the distance on `hint_screen_texture` (dark pixels — canopies, cliffs, shade — break the shaft). Peak added brightness `intensity` 0.32 × strength. On High the pass runs at `VOLUMETRIC_SCREEN_WEIGHT` 0.6.
- **Volumetric (High, Forward+ only):** `set_mode(VOLUMETRIC)` configures the Environment once — albedo warm white, anisotropy 0.7 (forward scattering), length 96 (past the iso view's ~45-unit far ground), emission black and ambient/GI/sky injection 0, so **only the sun lights the fog** and shafts form where sun shadows (on at High) cut it. Sun `light_volumetric_fog_energy` 1.5, moon 0, the WorldScene fill light 0 (unshadowed, it would only haze). Density = `0.018 × strength`; below `MIN_STRENGTH` 0.01 the fog is switched off entirely.
- **Cost:** `SunRaysFx` updates at 10 Hz. When the screen strength is below `MIN_STRENGTH` the `CanvasLayer` is hidden, so midday, night and storms cost neither the screen copy nor the taps. Low (`SUN_RAYS_OFF`) never builds the layer.
- **Wiring:** WorldScene creates `SunRaysFx` (node `SunRays`) right after the DayNightCycle, `setup(camera, sun, moon, env, dnc)` + `set_mode(knobs.sun_rays)`; `apply_graphics_quality()` re-calls `set_mode`, so Settings changes apply live. `GraphicsQuality.apply()` writes `volumetric_fog_enabled = knob` first; `set_mode` → `refresh()` corrects it in the same call. Co-op: purely local (time and weather id are already synced).
- **HQ taps + moon rays (GID-130 / TID-496):** the march length is the `samples` uniform (loop to `MAX_SAMPLES` 24 with an early break), set from the `ray_samples` knob via `set_quality(samples, moon_rays)` — so Mobile High (VOLUMETRIC demoted to SCREEN) gets 16 taps instead of Medium's 10. With `moon_rays` on, when the sun strength is below `MIN_STRENGTH` the pass uses `SunRayMath.moon_strength(-sun_h, weather)` (rise over 0.06, fade 0.5→1.0, × `MOON_RAY_SCALE` 0.45) from the opposite direction, `MOON_RAY_COLOR` (0.62, 0.72, 1.0) and `lit_threshold` 0.08 instead of 0.35 (the night screen is dark everywhere). Moon rays never drive volumetric fog and run at full screen weight. `is_moon_source()` reports it.
- **Tests:** `tests/unit/test_sun_rays.gd` (strength curve, moon strength + moon-ray toggle, weather dampening, screen direction vs the real camera basis, off-screen source, fog density, SunRaysFx screen/volumetric modes).

### Rain Wetness (`DayNightCycle`, `terrain.gdshader`) — TID-487

- **State:** `DayNightCycle._wetness` eases toward the *target* look's `wetness` every frame via `Lightning.step_wetness` — full soak in `WET_SECONDS` (20 s), full dry in `DRY_SECONDS` (90 s), so puddles outlast the rain. The first weather id after `setup()` (world entry, co-op join) snaps wetness to its target, so re-entering mid-rain starts wet; `setup()` also writes 0, because the global outlives scenes (a named map entered from a rainy world would otherwise be wet). `set_weather(id, true)` snaps too. `wetness()` getter.
- **Shader param:** global `terrain_wetness`, declared in `project.godot` `[shader_globals]` (so it exists before any shader compiles — do **not** also `global_shader_parameter_add` it at runtime). Written by `DayNightCycle._write_wetness()` quantised to 1/128 steps, only on change.
- **Terrain shader:** when `terrain_wetness > 0.001` (uniform branch; dry weather pays nothing): wetness weighted by how upward-facing the ground is (`smoothstep(0.55, 0.95, normal.y)`, vertical wall faces get 25 %) darkens albedo up to 35 %, drops roughness 0.9 → 0.35 and raises specular 0.1 → 0.45; `fbm` noise patches (only once wetness passes ~0.35) become puddles — another 10 % darker, roughness 0.08. Emission floor uses the darkened colour. Plain PBR params: works on Forward+, Mobile and Compatibility at every tier.

### Storm Lightning (`game_logic/Lightning.gd`, `DayNightCycle`) — TID-487

- **Rules (`Lightning.gd`, pure/static):** `next_interval(rng, strength)` 8 s … 8 + 17/strength s; `flash_envelope(t)` over `FLASH_SECONDS` 0.5 — sharp main flash, dip, weaker re-strike, fade; `thunder_delay(rng)` 0.5–3.5 s (the strike's distance); `thunder_pitch(delay)` 1.05 close → 0.75 distant; `step_wetness`.
- **Scheduler (`DayNightCycle._tick_lightning`, per frame from `tick`):** while the *target* look's `lightning > 0`, counts down a local-random interval, then `strike_lightning()`: starts the flash (unless `flashing_allowed` returns false) and queues thunder. Every `set_weather` resets the countdown; a storm ending stops new strikes but queued thunder still rolls. `thunder_rumbled(pitch)` fires after the delay.
- **Flash:** `_apply_lighting()` runs every frame while a flash is live and adds `flash × FLASH_AMBIENT_BOOST` (1.6) to ambient energy and pulls ambient colour and sky (hence fog colour and the unshaded grass tint) toward `lightning_color` by `flash × 0.7`. The sun is untouched, so flashes read at night too. `flash_level()` getter.
- **Wiring (WorldScene `_ready`, infinite world only):** `_dnc.thunder_rumbled` → `AudioManager.play_sfx_varied("thunder", pitch, 0.05)`; `_dnc.flashing_allowed` reads the `reduce_flashing` setting live (Settings → Accessibility & Comfort → Reduce Flashing): with it on, strikes keep their thunder and never flash.
- **Co-op:** peers share only the weather id (already synced); strike timing is local-random per client — no RPC.
- **Battles:** the detached WorldScene isn't in the tree, so no strikes or thunder play during a battle.

### Sky & Fog (`WorldScene._setup_environment`, `DayNightCycle`)

`_setup_environment()` creates a `ProceduralSkyMaterial` at startup, assigns it to a `Sky` resource, and sets `env.background_mode = BG_SKY`. Fog is enabled on the same `Environment` with `fog_density=0.004`. `DayNightCycle._apply_lighting()` calls `_get_sky_mat()` (lazy getter that resolves the sky chain) and updates `sky_top_color`, `sky_horizon_color`, `ground_horizon_color`, and `fog_light_color` each half-second tick.

### Height Fog (`game_logic/AtmosphereMath.gd`, `DayNightCycle`) — GID-130 / TID-494

Mobile-safe valley mist using `Environment.fog_height` / `fog_height_density` (supported on every renderer). `set_height_fog(on)` (forwarded from `WorldScene.apply_graphics_quality`) sets `fog_height = AtmosphereMath.HEIGHT_FOG_TOP` (0.8 — flat ground at y≈0 sits in the mist, hilltops at 1.5 poke out). `_apply_lighting()` writes `fog_height_density = AtmosphereMath.height_fog_density(sun_h, look.height_fog)` (cached): 0.28 at night, 0.06 at midday, +0.18 bump around sunrise/sunset, capped at 0.7; 0 when the knob is off. WeatherLook `height_fog` multiplier: rain 1.6, heavy rain 2.0, snow 1.4, blizzard 1.2, ash 1.3, volcanic 1.5, dust devil 0.5, sandstorm 0.3.

### Fake Volumetrics (`scenes/world/modules/FakeVolumetrics.gd`, `AtmosphereMath`) — GID-130

World module `fake_volumetrics` (created in `_ensure_world_modules`). Stand-ins for Forward+ volumetric fog that run on Mobile and Compatibility.

- **Light shafts (TID-495):** every 0.25 s `refresh()` reads `fake_shafts` (infinite world only — named maps include interiors), strength = `SunRayMath.strength(sun_h, look.sun_rays)` (same dawn/dusk curve as the screen rays; hidden below `MIN_STRENGTH`). `AtmosphereMath.shaft_anchors(player_xz, count)` hashes world cells (`SHAFT_CELL` 7, 45 % chance, ±3 cells) into ground points sorted nearest-first, so shafts stay put as the player walks; each carries a 0..1 seed (width 2.0–3.6, length 10, shimmer phase). Pooled `MeshInstance3D`s (shared unit `QuadMesh`, per-shaft `ShaderMaterial`, `custom_aabb` because the vertex shader stretches the quad) sit at `get_terrain_height`. `fake_light_shaft.gdshader` lays the quad along `shaft_axis(sun_dir)` (toward the sun, y clamped ≥ 0.5 so dawn beams stay steep), turns it about that axis to face the camera, and fades edges², both ends, a slow low-contrast swell (TID-500 removed a banded term that read as wavy lines) and — via the depth texture — the last 1.5 units before any surface, so beams never cut the ground. Additive, `intensity` 0.22 × strength, sun colour.
- **Depth fog (TID-498):** one `DepthFog` `MeshInstance3D` (QuadMesh, `extra_cull_margin` 16384) whose `depth_fog.gdshader` vertex writes clip space directly (`POSITION = vec4(VERTEX.xy*2, 0.5, 1)`, `skip_vertex_transform`, depth test off, `blend_mix`). Per pixel it rebuilds the world position from the depth texture (Compatibility NDC handled; far-plane/sky pixels skipped), fogs surfaces below `DEPTH_FOG_TOP` 1.2 over `DEPTH_FOG_DEPTH` 1.6, modulated by two octaves of world-space value noise drifting with `wind_direction × 0.25 × wind_scale`, and clears within `clear_radius` 3.5 of the player. Colour = `env.fog_light_color` (DayNightCycle's) + light × (0.15 + 0.45 × scatter) × noise, where scatter compares the camera heading with the light heading (the iso camera always looks down); light = sun colour by day, `SunRaysFx.MOON_RAY_COLOR` from the opposite direction at night. Alpha = `AtmosphereMath.depth_fog_density(sun_h, look.height_fog)` = height-fog curve / `HEIGHT_FOG_MAX` × `DEPTH_FOG_MAX_ALPHA` 0.55; hidden below 0.005. Knob `depth_fog`, infinite world only. `fog_density()` / `is_fog_visible()` for tests.
- **Visual check:** under `xvfb-run` with `--rendering-driver opengl3 --rendering-method gl_compatibility`, instantiate `WorldScene.tscn` after `new_game`, hide HUD CanvasLayers (1–126), set tier/time/weather, call each module's `refresh()` and save `root.get_texture().get_image()`. Headless (dummy renderer) never compiles shaders — use the same xvfb run to catch `SHADER ERROR`s.
- **Halos (TID-495, in `NightLights`):** each rig gets a `Halo` quad (the shared dot mesh, scaled to `radius × 0.9`) with `light_halo.gdshader`: billboard with node scale, `(1 − r)^2.2` radial glow, depth soft fade 1.2. Visible while `light_halos` is on; energy = pool flicker energy × `HALO_ENERGY` 0.35. `halo_count()` for tests.

### Contact Shadows (`game_logic/ContactShadow.gd`, `scenes/world/modules/CharacterPresence.gd`, `contact_shadow.gdshaderinc`) — GID-131 / TID-503

Soft dark pools under characters on every tier (Medium has no sun shadows, so billboards floated). **Not decal geometry:** a flat soft-disc quad was tried first and lost to the terrain shader's flat-ground vertex jitter (up to +0.12 y) and to dense grass. Instead the surfaces darken themselves:

- `contact_shadow.gdshaderinc` declares six `global uniform vec4 contact_shadow_0..5` (world xyz + radius; radius 0 = unused) and `contact_shadow_opacity`, all in `project.godot` `[shader_globals]`. `contact_shadow(p)` multiplies `1 − opacity × (1 − smoothstep(0.15, 1, |Δxz/r|²)) × (1 − smoothstep(0.4, 1.4, |Δy|))` over the slots.
- `terrain.gdshader` multiplies `ALBEDO` by it at the fragment's world position; `grass_blade` / `grass_cluster` by `mix(contact_shadow(blade root), 1, UV.y × 0.6)` so blades darken at the base and stay lighter at the tip.
- Casters call `ContactShadow.register(self, ContactShadow.radius_for_height(h))` in `_ready` (group `contact_shadow_caster` + radius meta): Player, RemotePlayer, MaitelnFollower, EnemyNPC, MerchantNPC, TownspersonNPC, ScoutAmbush. Radius = height × 0.45, clamped 0.35–1.6, × node scale (bosses).
- `CharacterPresence` module (`character_presence`, formerly ContactShadows) writes the nearest six visible casters to the player each frame (`pick_slots`, only changed slots), clears the slots in `_exit_tree`, and `apply_knobs()` (from `apply_graphics_quality`) sets opacity 0.55, or 0.3 when `sun_shadows` is on.

### Idle Life (`game_logic/IdleLife.gd`, `CharacterPresence`) — GID-132 / TID-511

World billboards used to stand frozen. `IdleLife.register(sprite, style)` stores the sprite's rest position, style and a per-instance phase as metadata (group `idle_life`). Each frame `CharacterPresence._update_idle_life()` poses every visible registered sprite within `MAX_DISTANCE` (32) of the player, so far-off chunks cost only the distance check.
- **Styles** `[speed rad/s, bob, squash]`: `STYLE_BREATHE` [2.2, 0, 0.035] (townsfolk, merchants), `STYLE_BOB` [3.4, 0.05, 0.03] (enemies), `STYLE_FLOAT` [1.6, 0.12, 0] (nocturnal spectres).
- `apply()` scales `(1 − 0.6 s, 1 + s, 1)` and sets `y = base.y × scale_y + bob`, so the feet stay planted (base y is the sprite's half height).
- **Enemies:** `EnemyNPC._process` sets `META_FAST` while CHASING (×2.6 speed), and `_show_alert()` calls `IdleLife.hop()`: a 0.35 s, 0.35-unit parabolic jump with a squash, timed on `Time.get_ticks_msec()`.
- Nothing else may write these sprites' `position`/`scale`; use a child node for extra offsets. Tests: `test_idle_life.gd`.

### Vignette (`scenes/world/ScreenVignette.gd`)

`ScreenVignette.make()` (added by `WorldScene._setup_environment`) returns a `CanvasLayer` at layer 127 holding a `ColorRect` covering the full viewport. An inline `Shader` on its `ShaderMaterial` computes `d = length(UV - 0.5)` and darkens the corners: `ALPHA = smoothstep(0.35, 0.75, d) * 0.45`. No `.gdshader` file, no `.uid` required.

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
- `NightLights` (world module) reads time of day from `DayNightCycle`, knobs from `WorldScene.graphics_knobs()` and light sources from WorldScene's door / waystone / mana-well dicts and the wilderness camp node; it writes only its own rig nodes.
- `AmbientTouches` (world module) reads knobs, biome, night factor and weather wind; it writes only its own two emitters and pushes knobs into `Player.apply_particle_knobs`.
- `SunRaysFx` reads time of day and the blended `WeatherLook` from `DayNightCycle`, the sun colour from `DayNightCycle.sun_color_for`, and its mode from `GraphicsQuality`; it writes only its own CanvasLayer and the Environment's volumetric fog.

## Asset Requirements

Ambient touches (GID-129/TID-493) add no files: all textures (soft dot, ramps) are code-built.

Night lights (GID-129/TID-489) add `assets/shaders/night_light_pool.gdshader` and its `.uid` sidecar; the glow dot uses a code-built radial `GradientTexture2D`, no image files.

Sun rays (GID-129/TID-488) add `assets/shaders/sun_rays.gdshader` and its `.uid` sidecar; no textures (the shafts are procedural noise over the screen texture).

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
