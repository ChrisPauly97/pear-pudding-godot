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
- **Battle backdrop**: the card board's background is a per-biome, day/night landscape painted by one full-screen shader out of the world's own terrain tiles and prop sprites — sky, ridge silhouettes, a skyline prop line and a perspective ground plane — instead of the flat `Color(0.1, 0.1, 0.15)` rect it was through GID-125.
- **Chest & door sprites**: `Chest.gd` and `Door.gd` render as billboard `Sprite3D`s (0x72 pack chest/door art, GID-118) instead of flat-colored `BoxMesh` geometry, falling back to the original procedural boxes if the sprites are missing. See `docs/agent/inventory-and-deck.md` (chest open ceremony) and `docs/agent/named-maps-and-dungeons.md` (door rendering).

## How It Works

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

`BattleScene._setup_backdrop()` runs in `_ready()` and hands `$Background` (the
`ColorRect` that used to *be* the background) to
`BattleBackdrop.apply(rect, biome, is_night)`, which installs a `ShaderMaterial`
running `assets/shaders/battle_backdrop.gdshader`. The rect keeps its flat
`color` underneath, so a missing or stripped shader degrades to the old look
rather than to nothing.

The biome and time of day come from `GameState.battlefield_biome` /
`is_night` — the pair Battlefield Resonance (GID-059) already stamps at
engagement — so the backdrop needs no context of its own and cannot disagree
with the rule the side panel is showing.

**No new art.** The ground plane tiles `assets/textures/pixel_art/*.png` (the
seamless 16×16 terrain tiles the 3-D world is built from) and the skyline is
dressed with `assets/textures/props/prop_*.png` (the scatter sprites
`ChunkRenderer` instances), one pair per biome, matching `BiomeDef.PROP_SETS`.

**Shader bands**, in the order `fragment()` paints them:

| Band | What it does |
|---|---|
| Sky | Vertical gradient `sky_top → sky_horizon`; 3-octave fbm cloud banks drifting on `TIME`; a hash-lattice star field gated on `night > 0`; a sun/moon disc with halo, suppressed by `celestial = 0` for roofed battlefields |
| Ridges | Two silhouettes from a 1-D noise profile. `ridge_sharp` folds the profile about its midpoint (`1 - abs(2n-1)`), which is what turns grassland's rolling hills into scorched spires and alpine peaks out of one function. The far range is mixed toward the sky for atmospheric depth |
| Skyline props | 30 cells across the width, ~⅔ occupied, each with jittered position, height and a coin-flip between the biome's two sprites, drawn as flat alpha silhouettes standing on the horizon. Each fragment tests three cells so neighbours can overlap |
| Ground | The biome tile in a shallow reciprocal-depth perspective (`depth` clamped well short of the vanishing point, so it reads as ground and not a corridor), plus broad noise mottling, distance haze and a darkened foreground |
| Board lighting | A soft warm pool over the board, and a pulsing seam along the horizon that doubles as the divider |
| Hold-back | Vignette (weighted to darken the left/right margins, which is what the side panel's label text reads against), then a global `mix` toward `dim_color` so cards stay legible |

**Palette** — `BattleBackdrop.PALETTE`, one entry per biome id plus
`NEUTRAL = -1`. Sky stops, ridge shape, prop pair and `dim` live in the table;
the *tints* do not — ground colour is `BiomeDef.GRASS_TINT[biome] × gain` and
both ridges are `BiomeDef.HILL_TINT[biome]`, so the backdrop cannot drift away
from the terrain it depicts. Only the vault, which has no biome to borrow hills
from, sets a `ridge_base` override.

Three scalars exist because a 2-D backdrop is not a lit 3-D surface:

- `ground_gain` — the `BiomeDef` tints multiply lit terrain; with no light to
  multiply, the darker biomes need lifting back into a readable range.
- `ground_desat` — the terrain PNGs carry a strong hue of their own (the hill
  side is orange dirt), so a snow-white mountain tint over them still reads
  orange. Pulling the sample toward grey first is what lets one 16×16 source
  serve several biomes.
- `NIGHT_GROUND_GAIN` (0.45) — the tints describe sunlit terrain, so without it
  a night battlefield keeps a noon-bright meadow under a star field.

`ground_avg`, which the far field fades to instead of the aliased texel soup a
minified un-mipmapped 16×16 tile gives, is **measured** on the CPU from the
texture rather than guessed at a constant — a constant was far too bright for
the dungeon's stone floor and put a glowing band across the horizon.

**Cost**: no per-frame CPU work at all. `SCREEN_PIXEL_SIZE` gives the shader its
own aspect ratio, so nothing has to be re-pushed on resize. All the fbm work
(clouds, both ridges, props) sits inside `if (uv.y < horizon)` and never runs
for the ~62 % of the screen below the skyline; the ground branch is one texture
fetch plus one noise octave.

**Previewing**: `tools/preview_battle_backdrop.gd` renders one PNG per variant
(5 biomes × day/night + the vault). It needs a real or virtual display — the
headless driver has no rasteriser, so the shader would never execute:

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
  -s tools/preview_battle_backdrop.gd -- --out=/tmp/backdrops
```

Captures pass `animate = false`, which freezes the shader clock so repeated
runs are comparable.

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

- `DayNightCycle` drives both sky material colors and fog light color every half-second.
- `ChunkRenderer.prepare_terrain()` is a static worker-thread function — `_compute_prop_positions()` is also static, accesses only `BiomeDef` const arrays and the passed tile lookup callable.
- `WorldEntityBase` is the shared base for all interactable NPCs; direct `Node3D` entities preload it for the static `build_highlight_ring` helper.
- `CardRegistry` runs `_ensure_loaded()` lazily on first access; illustration assignment happens once per session at that point, cached by `TextureGen._cached()`.
- `BattleBackdrop` consumes Battlefield Resonance's context (`GameState.battlefield_biome` / `is_night`, GID-059) and `BiomeDef`'s terrain tints and prop sets. It writes nothing back and holds no state — `apply()` is a pure function of (rect, biome, night).
- `BattleBackdrop.HORIZON` is tied to `BattleScene.tscn`'s `Divider` anchor; `test_battle_backdrop` fails if the two drift apart.

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
