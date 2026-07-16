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

### Grass Shader (`assets/shaders/grass.gdshader`)

Separate `MeshInstance3D` on top of flat grass tiles:
- Fragment shader applies layered fBm (fractal Brownian motion) noise to produce procedural blade variation
- Wind uniform `wind_direction: vec2` + turbulence noise offsets UV slightly per-pixel per frame
- Player position `player_pos: vec3` passed every frame; blades within `player_radius` shift UV radially outward

No geometry shader is used (Godot 4 does not support them). The visual density is achieved entirely in the fragment stage on a flat plane.

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
| Grass blade shader | `assets/shaders/grass_blade.gdshader` | Variant for individual blade rendering |
| Grass cluster shader | `assets/shaders/grass_cluster.gdshader` | Variant for cluster rendering |
| Grass pixel texture | `assets/textures/pixel_art/grass_pixel.png` | Sampled in terrain shader grass layer. Real sprite art (GID-118): Kenney Tiny Town `tile_0001`, seamless-tiled — see `CREDITS.md` |
| Hill side texture | `assets/textures/pixel_art/hill_side_pixel.png` | Steep slope faces. Real sprite art (GID-118): Kenney Tiny Dungeon `tile_0049`, seamless-tiled |
| Hill top texture | `assets/textures/pixel_art/hill_top_pixel.png` | Plateau surfaces. Original hand-drawn art, unchanged by GID-118 |
| Wall side texture | `assets/textures/pixel_art/wall_side_pixel.png` | Vertical wall faces. Real sprite art (GID-118): 0x72 `wall_mid` brick tile, seamless-tiled |
| Wall top texture | `assets/textures/pixel_art/wall_top_pixel.png` | Top of walls. Real sprite art (GID-118): 0x72 `floor_1` stone tile, seamless-tiled |
| Path texture | `assets/textures/pixel_art/path_pixel.png` | Real sprite art (GID-118): Kenney Tiny Dungeon `tile_0048` flat packed-earth. Replaced the old `TextureGen.path()` procedural noise generator, which was removed (no remaining callers) |
| `.uid` sidecars | `assets/shaders/*.uid` | Required for Android export; must be committed alongside each shader |
