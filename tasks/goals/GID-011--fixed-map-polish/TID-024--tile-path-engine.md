# TID-024: Add TILE_PATH Engine Support

**Goal:** GID-011
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The terrain system has three tile types: TILE_GRASS (0), TILE_WALL (1), TILE_HILL (2). Fixed town maps need brown packed-earth path tiles between building doors, but no TILE_PATH type exists. This task adds the type to the engine (constants, rendering, shader) without touching any map files — that is TID-025.

TILE_PATH tiles are flat (y=0), walkable (not wall collision), and render with a brown dirt texture. The terrain shader already uses vertex COLOR channels for per-tile data (R=height-blend, G=wall flag, B currently always 0), so adding B=path flag is the minimal extension.

## Research Notes

### Files to change

**`autoloads/IsoConst.gd`** — Add after TILE_HILL:
```gdscript
const TILE_PATH: int = 3
```

**`game_logic/world/WorldMap.gd`** — Add alias (line ~12, alongside existing aliases):
```gdscript
const TILE_PATH: int = IsoConst.TILE_PATH
```
`is_wall_at_world` already guards `== TILE_WALL` so PATH tiles are walkable with no other change.
`load_from_string` already stores raw int from the digit char, so `'3'` → `3` works automatically.
`save_to_file` writes `str(tiles[tz][tx])` so `3` is written back as `'3'` automatically.

**`game_logic/TerrainMath.gd`** — In `build_terrain_mesh`, line 162–163:
```gdscript
# Current:
var is_wall: float = 1.0 if tile_lookup.call(tx, tz) == IsoConst.TILE_WALL else 0.0
colors[i] = Color(blend, is_wall, 0.0, 1.0)

# Replace with:
var ttype: int = tile_lookup.call(tx, tz)
var is_wall: float = 1.0 if ttype == IsoConst.TILE_WALL else 0.0
var is_path: float = 1.0 if ttype == IsoConst.TILE_PATH else 0.0
colors[i] = Color(blend, is_wall, is_path, 1.0)
```
No change needed to `compute_height_field` — the `continue` on non-HILL/non-WALL already treats PATH as flat ground correctly (same as TILE_GRASS).

**`assets/shaders/terrain.gdshader`** — Three additions:
1. New uniforms after `wall_top_texture`:
```glsl
uniform sampler2D path_texture : source_color, filter_nearest, hint_default_white;
uniform vec3 path_tint = vec3(1.0, 1.0, 1.0);
```
2. New varying in declarations:
```glsl
varying float v_path;
```
3. In `vertex()`, after `v_wall = COLOR.g;`:
```glsl
v_path = COLOR.b;
```
4. In `fragment()`, before the `if (is_wall)` block:
```glsl
bool is_path = v_path > 0.05;
```
Then add path branch at the start of the base_col selection, before `if (is_wall)`:
```glsl
if (is_path) {
    base_col = texture(path_texture, uv_xz).rgb;
    tint = path_tint;
} else if (is_wall) {
    // ... existing wall code unchanged ...
```

**`game_logic/TextureGen.gd`** — Add static function after `hill_side()`:
```gdscript
static func path(seed: int = 77777) -> ImageTexture:
    return _cached("path_%d" % seed, _make_path_tex.bind(seed))

static func _make_path_tex(seed: int) -> ImageTexture:
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = seed
    noise.frequency = 0.18
    var grad := Gradient.new()
    grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
    grad.colors = PackedColorArray([
        Color8(105, 80, 45, 255),   # dark packed earth
        Color8(130, 100, 58, 255),  # mid earth
        Color8(148, 118, 68, 255),  # light earth / gravel
        Color8(160, 130, 78, 255),  # pale sandy path
    ])
    return _noise_to_texture(noise, grad, 64)
```

**`scenes/world/WorldScene.gd`** — In `_ready()` (or wherever `_terrain_mat` is set up with other textures), add after setting wall textures:
```gdscript
_terrain_mat.set_shader_parameter("path_texture", TextureGen.path())
```
`path_tint` defaults to `vec3(1,1,1)` in the shader so no per-chunk tint override is needed.

Note: WorldScene preloads PNG textures from `assets/textures/pixel_art/` for grass/hill/wall, but path texture is generated at runtime via TextureGen (same as the existing TextureGen usage pattern — no PNG needed, no .uid sidecar needed for a runtime-generated ImageTexture).

### Terrain shader COLOR channel summary after this task
| Channel | Value | Meaning |
|---------|-------|---------|
| R | 0.0–1.0 | height blend (0=flat grass, 1=hill plateau) |
| G | 0.0 or 1.0 | wall flag |
| B | 0.0 or 1.0 | path flag |
| A | 1.0 | unused |

### Height/physics correctness
PATH tiles pass through `compute_height_field` as "neither HILL nor WALL" → flat ground (h=0). The `is_wall_at_world` collision check also returns false for PATH. Behaviour is identical to TILE_GRASS for movement and physics.

### Test impact
`tests/unit/test_terrain_math.gd` uses tile lookups that return 0 (TILE_GRASS) or TILE_WALL/TILE_HILL. No PATH tiles appear in existing tests, so they are unaffected. No new tests are required for this task (pure rendering change).

## Plan

1. Add `TILE_PATH = 3` to `IsoConst.gd` and alias in `WorldMap.gd`
2. Update `TerrainMath.build_terrain_mesh` to set `COLOR.b = 1.0` for path vertices
3. Update `terrain.gdshader`: add `path_texture` / `path_tint` uniforms, `v_path` varying, fragment branch before `is_wall`; suppress micro-bump on path tiles
4. Add `TextureGen.path()` + `_make_path_tex()` to `TextureGen.gd`
5. Add `TextureGen` preload and `path_texture` shader param to `WorldScene._make_terrain_material()`

## Changes Made

- `autoloads/IsoConst.gd`: added `const TILE_PATH: int = 3`
- `game_logic/world/WorldMap.gd`: added `const TILE_PATH: int = IsoConst.TILE_PATH` alias
- `game_logic/TerrainMath.gd`: updated `build_terrain_mesh` vertex color (line 162–164) — call `tile_lookup` once into `ttype`, set `COLOR.b = is_path`
- `assets/shaders/terrain.gdshader`:
  - Added `path_texture` + `path_tint` uniforms
  - Added `varying float v_path`
  - Added `v_path = COLOR.b` in `vertex()`
  - Suppressed micro-bump when `v_path >= 0.5` (paths stay flat)
  - Added `is_path` bool + `if (is_path)` branch before `if (is_wall)` in `fragment()`
  - Updated tint selection to check `is_path` first
- `game_logic/TextureGen.gd`: added `path()` public func + `_make_path_tex()` with brown packed-earth gradient
- `scenes/world/WorldScene.gd`: added `const TextureGen = preload(...)` and `mat.set_shader_parameter("path_texture", TextureGen.path())` in `_make_terrain_material()`

## Documentation Updates

Updated `docs/agent/terrain-rendering.md` with TILE_PATH vertex color channel table and path texture details.
