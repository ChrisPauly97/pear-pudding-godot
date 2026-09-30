# Terrain Rendering

## Key Features

- `TerrainMath` is the single shared implementation for all terrain mesh building — used by both named maps and infinite chunks
- Height fields computed from tile grids using smoothstep blending at hill edges
- `ArrayMesh` built on the CPU per chunk: top-surface quads with per-vertex height + colour encoding
- Separate wall mesh for vertical faces on TILE_WALL tiles
- Multi-texture terrain shader blends grass, hill side, hill top, wall side, and wall top by height and gradient
- Per-biome colour tints applied as shader uniforms (no texture swaps needed)
- Grass layer rendered via a separate unshaded FBM noise shader
- `HeightMapShape3D` collision generated from the same height field for physics

---

## How It Works

### TerrainMath API (`game_logic/TerrainMath.gd`)

`TerrainMath` accepts a `Callable` tile lookup so it works identically for named maps and infinite chunks:

```gdscript
# Named-map path
var hfield := TerrainMath.compute_height_field(
    world_map.get_tile, origin_x, origin_z, nvx, nvz, step, HILL_RAMP_R, HILL_PEAK_H)

# Infinite-chunk path
var grid_tile_lookup := func(ttx: int, ttz: int) -> int: ...
var hfield := TerrainMath.compute_height_field(
    grid_tile_lookup, chunk_origin.x, chunk_origin.z, nvx, nvz, step, CURVE_R, PLATEAU_H)
```

#### Packed-Grid Fast Paths (GID-121)

The Callable-per-tile variants cost ~53k dynamic calls per chunk (7×7 neighbourhood
scan × 33×33 vertices), which dominated chunk prep and per-frame height queries on
mobile. TerrainMath therefore also exposes packed variants with **identical output**
that index `PackedInt32Array` tile/height grids directly:

| Function | Used by | Replaces |
|---|---|---|
| `compute_height_field_grid(tile_grid, height_grid, grid_min_x, grid_min_z, grid_w, origin_x, origin_z, nvx, nvz, step, curve_r, peak_h)` | `ChunkRenderer.prepare_terrain` (worker thread + sync startup builds) | `compute_height_field` on the chunk-prep path |
| `get_height_at_grid(wx, wz, tile_grid, height_grid, grid_min_x, grid_min_z, grid_w, curve_r, peak_h)` | `ChunkStreamingManager.get_height_world` (steady-state per-frame queries) | `get_height_at` when the query neighbourhood fits the cached grid |

Out-of-range grid reads fall back to `TILE_WALL` / height `1` — the same values
`WorldMap` returns out of bounds and the old snapshot lambdas returned outside the
snapshot, so both variants are drop-in equivalent. The Callable variants remain the
API for callers without a packed grid (named-map mesh builders, prop scatter,
far-from-player fallback queries); per CLAUDE.md, both live only in TerrainMath.

**Snapshot & height-query caches (`scenes/world/ChunkStreamingManager.gd`):**
- `snapshot_tile_grid_for(key)` block-copies rows straight out of each covered
  `ChunkData.tiles/heights` packed array (one cache lookup per chunk, ≤3×3 chunks)
  instead of calling `get_tile_global`/`get_height_global` per tile — this runs on
  the main thread at chunk-kick time, so it was the walking-hitch hot spot.
- `get_height_world(wx, wz)` answers `WorldScene.get_terrain_height` from a cached
  packed grid: player chunk ±1 for infinite worlds (refreshed on chunk crossing),
  the whole map + `TILE_CHECK` margin for named maps (built once in `setup`).
  Refreshed by `rebuild_terrain_around_tile` after tile edits (cracked-wall break).
  Queries whose 7×7 tile neighbourhood falls outside the cached grid (e.g. entity
  placement in far chunks during commit) take the Callable fallback — same result.

#### Height Field Computation

1. **Vertex grid:** vertex density = 2 (sample every 0.5 tiles); `nvx = chunk_tiles * 2 + 1` vertices per axis.
2. **For each vertex (vx, vz):**
   - Map to tile coordinate: `tx = vx / 2`, `tz = vz / 2`
   - If tile is TILE_HILL: base height = `HILL_PEAK_H` (biome-specific, 1–7 world units)
   - Apply smoothstep radial falloff within `HILL_RAMP_R` tiles of the hill centre
   - Suppress hill height within 1 tile of any TILE_WALL (right-angle wall suppression)
   - TILE_WALL tiles always contribute 0 height to the surface (walls are rendered as vertical quads)
3. Result: `Array[float]` of length `nvx * nvz`

#### Top Surface Mesh

`build_terrain_mesh(hfield, nvx, nvz, step) → ArrayMesh`

- One quad per 2×2 vertex block
- Per-vertex colour encoding:

| Channel | Value | Meaning |
|---------|-------|---------|
| R | 0.0–1.0 | height ratio (0 = flat ground, 1 = hill plateau top) |
| G | 0.0 or 1.0 | wall flag (1 = vertex is on a TILE_WALL tile) |
| B | 0.0 or 1.0 | path flag (1 = vertex is on a TILE_PATH tile) |
| A | 1.0 | unused |

- Normals computed from height field finite differences
- UVs tiled at 1 unit per world unit (matched to texture scale in shader)

#### Wall Face Mesh

`build_wall_mesh(tile_lookup, ...) → ArrayMesh`

- For each TILE_WALL tile, emit one quad per exposed side face (facing an adjacent non-wall tile)
- Quad spans from `y = 0` to `y = IsoConst.WALL_FACE_H`
- UVs tiled to match texture height

#### Collision Shape

`build_collision_shape(hfield, nvx, nvz, step) → HeightMapShape3D`

- Feeds the same `hfield` float array into `HeightMapShape3D.map_data`
- Attached to a `StaticBody3D` so the player can walk on hills without falling through

### Terrain Shader (`assets/shaders/terrain.gdshader`)

The shader reads per-vertex colour channels to decide which textures to blend:

```
height_ratio = VERTEX_COLOR.r
is_wall      = VERTEX_COLOR.g > 0.05
is_path      = VERTEX_COLOR.b > 0.05

if is_path:
    albedo = path_tex * path_tint
elif is_wall:
    albedo = mix(wall_side_tex, wall_top_tex, smoothstep(0.3, 0.7, slope))
else:
    albedo = mix(grass_tex,
             mix(hill_side_tex, hill_top_tex, smoothstep(0.4, 0.8, height_ratio)),
             smoothstep(0.1, 0.4, height_ratio))
    albedo *= mix(grass_tint, hill_tint, height_ratio)
```

Uniforms set per material instance:
- `grass_tint`, `hill_tint`, `wall_tint` — per-biome hue (set by ChunkRenderer from BiomeDef)
- `path_tint` — defaults to `vec3(1,1,1)` (no biome override; paths are always brown)
- `grass_texture`, `hill_side_texture`, `hill_top_texture`, `wall_side_texture`, `wall_top_texture`, `path_texture`

#### HD tiles, per-texel relief and crisp moss
- **Anti-tiling:** two slow noise fields pick one of four rotated + offset copies (`rot` 0–3) of every ground layer (grass, hills, path, wall tops) in irregular blobs; hard switch, no blend. `tan_u`/`tan_v` follow the rotation so the bump stays correct. Tiles are also drawn calm (no single distinctive feature) so the 6.4-unit repeat never reads.
- `tile_sample(tex, uv, out grad, out h)` fetches a tile plus its one-texel alpha step in +u/+v (`TEX_RES = 128`). Only the **dominant** tile of a fragment (weight > 0.5) feeds the bump, so flat grass costs 3 fetches.
- `tan_u` / `tan_v` are the world directions of the sampled tile's axes (ground: +X/+Z, rotated anti-tiling grass: −Z/+X, wall sides: along-face axis / +Y). `n_detail = normalize(n_geo − detail_bump·(grad.x·tan_u + grad.y·tan_v))` feeds `NORMAL`, and the puddle / stream blocks mix from `n_detail`. `detail_bump = 0` gives flat shading.
- Wall moss is decided per tile texel (`floor(uv·TEX_RES)`), biased toward low height (mortar), with a hard threshold plus a little per-texel jitter — pixel-crisp clumps instead of smooth blobs.

#### Softening the tile grid (GID-131 / TID-505)

- **Macro variation:** `v_d0 = fbm(xz × 0.045)`, `v_d1 = fbm(xz × 0.09 + (7.3, 2.1))` per vertex (slow enough to interpolate across a tile). Non-wall ground: `base × mix(0.88, 1.1, d0)`, then up to 60 % toward a drier `× (1.08, 1.03, 0.82)` where `smoothstep(0.5, 0.75, d1)`.
- **Anti-tiling:** inside irregular blobs where `vnoise(xz × 0.23) > 0.5`, grass samples a 90°-rotated, offset copy of the tile (`uv_grass`). A hard switch, not a blend, so the pixel art stays crisp and the 2-unit repeat never lines up.
- **Ragged path edges:** `path_t = smoothstep(0.2, 0.7, v_path + (vnoise(xz × 1.7) − 0.5) × 0.45)`; `is_path` is now `path_t > 0.99`, and the fringe mixes the path texture over the ground (tint-corrected) instead of the old hard `v_path > 0.05` cut.
- **Contact shadows (TID-503):** `ALBEDO` is multiplied by `contact_shadow(world pos)` from `contact_shadow.gdshaderinc` (see visual-polish.md).

### Grass Tufts (`scenes/world/GrassBlades.gd`)

Per-chunk `MultiMeshInstance3D` of **billboard tuft sprites**, built on worker threads (infinite world only — named maps have no tuft grass):
- **Art:** `assets/textures/pixel_art/grass_tufts.png` (from `tools/generate_hd_terrain.py`): 8 short tufts (16×12) and 8 tall tufts (16×24) at the character sprites' pixel size (`PIXEL = 0.05` = `Player.PIXEL_SIZE`). R = tone on the shader's base→mid→tip ramp (0 = dark outline), A = coverage. The shader picks the column and a mirror flip from a hash of the root, and reads the texel with `texelFetch` (no filtering bleed).
- **Density:** ordinary grass is patchy — a squared hash per 4-unit cell (`_short_tufts`) gives 0–4 tufts per tile (mean ~1.25), so there are bare, sparse and fuller stretches; tall-patch tiles (12 % of 3-tile cells) get 6 tall + 2 short. Tufts are stratified on a 3×3 grid within the tile. The instance basis carries the tuft size (x = width, y = height; tall is detected from the height).
- **Cost:** 4 verts per tuft (~5 verts per ordinary tile on average vs ~136 for the old 7-vert 3-D blades + spiky 5-blade cluster quads). It replaced those because they looked jagged, and making them denser had hit the mobile vertex budget.
- **Vertex stage (`grass_tuft.gdshaderinc`, `world_vertex_coords`):** Y-axis billboard rebuilt from the UVs (no per-vertex matrix inverse); wind sway, player push (while walking) and the persistent trample map lean the top edge sideways in billboard space and trample squashes it. Offsets snap to whole texels, so tufts move like pixel-art animation frames instead of smearing. Tufts in puddles sink.
- **Unshaded by default** with the `grass_day_tint` global (sun + ambient + moon approximation, written at 2 Hz by `DayNightCycle`); no shadows cast; culled at 55 units (`VISIBILITY_END`).
- Shared globals (`player_pos`, `player_move_dir`, `trample_*`, `grass_day_tint`, `grass_wind_*`) are registered via `GrassBlades._ensure_global_param()` so one `RenderingServer` write reaches every chunk.

No geometry shader is used (Godot 4 does not support them).

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **WorldScene** | Consumer (named maps) | Calls `TerrainMath.build_terrain_mesh()` once on map load; attaches result to a `MeshInstance3D` |
| **ChunkRenderer** | Consumer (infinite) | Calls `TerrainMath` per chunk on a worker thread; replaces mesh node when done |
| **WorldMap / InfiniteWorldGen** | Tile data source | Provide the `Callable` tile lookup that `TerrainMath` queries |
| **Player** | Physics | `HeightMapShape3D` produced here is what the `CharacterBody3D` stands on |
| **IsoConst** | Constants | `TILE_GRASS`, `TILE_WALL`, `TILE_HILL`, `TILE_PATH`, `TILE_SIZE`, `WALL_FACE_H` |
| **BiomeDef** | Tint source | `BiomeDef.grass_tint`, `hill_tint`, `wall_tint` are passed as shader uniforms by ChunkRenderer |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Terrain shader | `assets/shaders/terrain.gdshader` | Multi-texture blending; requires companion `.uid` sidecar |
| Grass shader | `assets/shaders/grass.gdshader` | FBM noise grass layer; requires `.uid` sidecar |
| Grass tuft shaders | `assets/shaders/grass_tuft.gdshader` / `grass_tuft_lit.gdshader` + `grass_tuft.gdshaderinc` | Billboard pixel-art tufts (unshaded / High-tier lit) |
| Grass tuft atlas | `assets/textures/pixel_art/grass_tufts.png` | 128×36 tone+coverage atlas, generated; lossless, `detect_3d/compress_to=0` |
| Terrain tiles | `assets/textures/pixel_art/{grass,hill_side,hill_top,wall_side,wall_top,path}_pixel.png` | 128×128 RGBA, seamless, sampled at 20 texels per world unit (`uv_scale = 20/128`, set in `WorldScene._make_terrain_material`) — the character sprites' pixel density, so ground and sprites share one pixel scale; original art generated by `tools/generate_hd_terrain.py` (re-run it to regenerate). RGB is ordered-dither pixel art on small palettes, rescaled to the old tiles' mean colour so biome tints stay calibrated. **Alpha is a height map** (0 = mortar/soil/crevice, 1 = raised brick/pebble/blade tip) that drives `detail_bump`. Imports are lossless with `detect_3d/compress_to=0` — VRAM compression would smear the height alpha. Replaced the 16×16 Kenney / 0x72 tiles (GID-118) |
| `.uid` sidecars | `assets/shaders/*.uid` | Required for Android export; must be committed alongside each shader |


#### Lit grass variant (GID-131 / TID-508)

The grass shader is a thin header plus a shared body include (`grass_tuft.gdshaderinc`). `grass_tuft.gdshader` keeps `render_mode ... unshaded` and the `grass_day_tint` approximation. `grass_tuft_lit.gdshader` uses `diffuse_lambert_wrap, specular_disabled` and `#define GRASS_LIT`, so the body writes `ALBEDO = col × 1.3 × contact`, `EMISSION = ALBEDO × 0.08` and a world-up `NORMAL`. That way blades light like the ground under them and receive sun shadows. `GrassBlades.set_lit(on)` swaps the `_mat` shader (parameters carry over). WorldScene calls it from `apply_graphics_quality()` with the `lit_world` knob (High only). Grass still casts no shadows.

#### Grass colour (GID-131 / TID-506)

Tufts map the atlas tone onto `color_base × 0.6 → color_mid → color_tip` (defaults muted to sit on the Grasslands ground: base (0.12, 0.23, 0.07), mid (0.22, 0.35, 0.11), tip (0.34, 0.46, 0.16)) (tones are quantised in the atlas, so the result stays flat pixel-art colour). (Historically the blades used a smooth gradient that replaced three hard bands whose olive base read as dark spikes.) New defaults are base (0.18, 0.38, 0.13), mid (0.32, 0.58, 0.19), tip (0.56, 0.80, 0.30). A hash of the blade root (`v_root_world`) jitters brightness ±10 %, and one in five blades gets a drier tint. Contact shadows darken the lower blade (`mix(contact_shadow(root), 1, UV.y × 0.6)`).

## Stream current (GID-152 / TID-642)

Streams flow. `WaterMath.flow_at(wx, wz, seed)` returns the current as direction × speed: the stream is the zero
contour of the stream noise, so the direction is the noise gradient turned 90° (continuous across the contour, so
one orientation along the whole stream and across chunk borders). Speed = gradient magnitude /
`FLOW_TYPICAL_GRADIENT`, clamped `FLOW_MIN_SPEED..FLOW_MAX_SPEED`, so narrow stretches run faster. Ponds (pond noise
dominating) and dry ground return zero. The only reversals are near noise saddles where two branches meet.

`ChunkRenderer` samples it at every wet vertex (> 0.01) and `TerrainMath.build_terrain_mesh(..., flow_field)` bakes
it into `CUSTOM0.xy` (`ARRAY_CUSTOM_RG_FLOAT`; skirts and meshes without a flow field read zero). The shader's
`v_flow` scrolls ripple streaks as a two-phase flow map (`CYCLE` 1.5 s, `RIPPLE_SPEED` 1.5 u/s at speed 1): each
layer is thresholded then shown only while its weight is ≥ 0.25, so streaks pop in whole rather than smearing, and
the pattern never distorts over time. Still water (`|v_flow| ≤ 0.05`) keeps the old slow wind drift.
