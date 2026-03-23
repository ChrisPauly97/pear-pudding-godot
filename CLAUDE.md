# Pear Pudding TCG — Godot Rewrite: Claude Notes

Patterns and pitfalls learned during development. Read this before writing any GDScript.

---

## GDScript: Variant Inference Errors

### The problem
GDScript's `:=` operator infers the variable type from the right-hand side. If the RHS returns `Variant` (untyped), Godot 4 with strict mode treats this as a compile error:

```
Parse Error: Cannot infer the type of "x" variable because the value doesn't have a set type.
Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
```

### Common causes
| Expression | Returns | Fix |
|---|---|---|
| `array[i]` | Variant | `var x: int = array[i]` |
| `max(a, b)` | Variant | `var x: int = max(a, b)` |
| `min(a, b)` | Variant | `var x: float = min(a, b)` |
| `lerp(a, b, t)` | Variant | `var x: float = lerp(a, b, t)` |
| `clamp(v, a, b)` | Variant | `var x: int = clamp(v, a, b)` |
| Typed array `Array[int]` index | int | OK with `:=` |

### The fix
Use explicit type annotation whenever the RHS is one of the above:
```gdscript
# Bad — Variant inference error
var step := max(1, (max_depth - 20) / 8)
var d := chest_depths[i] + rng.randi_range(-5, 5)

# Good — explicit type
var step: int = max(1, (max_depth - 20) / 8)
var d: int = chest_depths[i] + rng.randi_range(-5, 5)
```

Use typed arrays to allow `:=` on indexed access:
```gdscript
# Bad
var depths := [10, 20, 30]
var d := depths[i]  # Variant error

# Good
var depths: Array[int] = [10, 20, 30]
var d := depths[i]  # OK — inferred as int
```

Dictionary values are always plain `Array` — use `assign()` to convert to a typed array:
```gdscript
# Bad — dict value is plain Array
player.build_deck(enemy_data["enemy_deck"])  # runtime type error

# Good — assign() copies into the typed array
var deck: Array[String] = []
deck.assign(enemy_data["enemy_deck"])
player.build_deck(deck)
```

Array literals are always plain `Array` — annotate them when passing to a typed parameter:
```gdscript
# Bad — passes plain Array to a func expecting Array[String]
var deck := ["ghost", "skeleton"]
player.build_deck(deck)  # runtime type error

# Good
var deck: Array[String] = ["ghost", "skeleton"]
player.build_deck(deck)
```

---

## GDScript: class_name Not Immediately Available

### The problem
When a new `.gd` file with `class_name Foo` is created outside the Godot editor (e.g. by Claude via file writes), Godot hasn't scanned it yet. Any script that references `Foo` directly will fail:

```
Parse Error: Identifier "TextureGen" not declared in the current scope.
```

### The fix
Always `preload` scripts in the file that uses them. Don't rely on `class_name` being globally available in files Claude creates:

```gdscript
# At the top of the file that uses it
const TextureGen = preload("res://game_logic/TextureGen.gd")

# Then call static methods normally
var tex := TextureGen.grass()
```

---

## Camera: Isometric Follow Without look_at

### The problem
`camera.look_at(target, Vector3.UP)` overrides the camera's rotation every frame, destroying the baked isometric rotation in the `.tscn`.

### The fix
Never call `look_at` on the isometric camera. The camera rotation is fixed — only update its position:

```gdscript
# Bad — destroys iso rotation
_camera.position = _player.position + Vector3(0, 20, 20)
_camera.look_at(_player.position, Vector3.UP)

# Good — preserves iso rotation
_camera.position = _player.position + Vector3(20, 20, 20)
```

### Why (20, 20, 20)?
The camera's look direction is `(-0.577, -0.577, -0.577)` (i.e. `(-1,-1,-1)` normalized). To center the view on the player, the camera must be offset in the exact opposite direction: `(+1,+1,+1)` normalized × distance. At distance ~34.6 units that gives offset `(20, 20, 20)`. Using `(0, 20, 20)` shifts the view center 20 units off in X, putting the map off-screen.

---

## Sprite3D: Depth Clipping Into Floor

### The problem
A `Sprite3D` with `billboard = BILLBOARD_ENABLED` has its origin at the texture centre. If the origin Y is too low, the bottom half of the sprite dips below `y = 0` (the tile plane) and gets clipped by the opaque tile geometry.

### The fix
Position the sprite so its bottom edge clears the floor:

```gdscript
# sprite is 48px tall at pixel_size=0.04 → 1.92 world units, half = 0.96
sprite.position = Vector3(0, 1.1, 0)  # bottom edge at y = 0.14, above tiles at y = 0
```

General formula: `sprite.position.y = pixel_height * pixel_size * 0.5 + small_margin`

---

## Grass / Environmental Physics

Grass blades should respond to **actual forces**, not random baked-in directions:
- **Natural variation** — tiny ±random offset (≤0.08 units) just to break up perfect symmetry
- **Wind** — a `wind_direction: vec2` uniform shared by all blades; spatial turbulence noise modulates it slightly per blade
- **Player displacement** — pass `player_pos: vec3` each frame via `set_shader_parameter`; blades within `player_radius` get pushed radially away

Update player pos every frame from `_process()` — not from physics — to keep it smooth:
```gdscript
_grass.set_player_pos(_player.position)
```

## Geometry Shaders

Godot 4 **does not support geometry shaders**. Use these alternatives:

- **Grass / foliage density:** fragment shader with fBm noise on tile planes
- **Outlines:** second material pass with back-face culling flipped, vertex expansion in vertex stage
- **Procedural geometry:** `ArrayMesh` built on the CPU
- **Particles / trails:** `GPUParticles3D` with trail settings

---

## UI Sizing: Relative to Viewport, Never Fixed Pixels

### The problem
Hard-coded pixel sizes (e.g. `custom_minimum_size = Vector2(80, 30)`) produce tiny, unusable controls on typical resolutions. Buttons in tool UIs like the map editor have been too small because of this.

### The fix
Always size UI controls as a fraction of the viewport:

```gdscript
# Bad — fixed pixels, looks tiny at 1080p+
button.custom_minimum_size = Vector2(80, 30)

# Good — relative to viewport height
var vh: float = get_viewport().get_visible_rect().size.y
button.custom_minimum_size = Vector2(vh * 0.12, vh * 0.05)
```

### Recommended fractions
| Control | Width | Height |
|---|---|---|
| Standard button | 12–18 % vh | 5–6 % vh |
| Icon/square button | 5–6 % vh | 5–6 % vh |
| Panel / sidebar | 20–25 % vw | — |
| Font size | — | 2–2.5 % vh |

Use `get_viewport().get_visible_rect().size` — not `DisplayServer.window_get_size()` — so it respects sub-viewports and editor embeds.

Re-apply sizes in `_notification(NOTIFICATION_RESIZED)` if the window can be resized at runtime.

---

## Godot Resource .uid Files

### The problem
Every Godot resource file (`.gdshader`, `.tres`, `.material`, etc.) needs a companion `.uid` file. The Godot editor generates these when it scans the project. Files created by Claude via code tools **skip that scan**, so they have no `.uid`. On Android exports, `load("res://path/to/file.gdshader")` can return `null` for untracked files.

### The fix — three parts

**1. Always create the `.uid` sidecar immediately after creating a resource file:**

```
# Format: uid:// followed by exactly 12 lowercase alphanumeric characters
uid://a1b2c3d4e5f6
```

Generate a random 12-char string using `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`.

**2. Use `preload()` not `load()` for shaders and resources in scripts:**

```gdscript
# Bad — runtime load, can return null if file untracked
mat.shader = load("res://assets/shaders/terrain.gdshader") as Shader

# Good — compile-time, guaranteed in export packs
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")
mat.shader = _TerrainShader
```

**3. The CI workflow already runs `godot --headless --editor --quit` before export** (line 163 of `.github/workflows/android-build.yml`). This scans the project and fills in any missing `.uid` files for the build. The `.uid` file committed to git is still needed so the local editor and the CI both use the same stable UID.

### Which file types need .uid files
`.gdshader`, `.tres`, `.material`, `.theme`, `.gdextension`, and any binary resource Godot imports (textures, audio, meshes). Plain `.gd` scripts and `.tscn` scenes manage their own UIDs inside the file itself — no separate sidecar needed.

---

## TerrainMath: No Duplicate Terrain Code

### The problem
Terrain height computation, mesh building, wall mesh building, and entity spawning were
duplicated between WorldScene (named-map path) and ChunkRenderer (infinite-chunk path).
Any bug fix or parameter change had to be applied in 2–3 places.

### The fix
All shared terrain logic lives in `game_logic/TerrainMath.gd`. Both paths delegate to it
via `Callable`-based tile lookups:

```gdscript
# Named-map path — WorldScene passes WorldMap.get_tile directly
var hfield := TerrainMath.compute_height_field(
    world_map.get_tile, 0.0, 0.0, nvx, nvz, step, HILL_RAMP_R, HILL_PEAK_H)

# Infinite-chunk path — ChunkRenderer passes a lambda over the packed tile grid
var grid_tile_lookup := func(ttx: int, ttz: int) -> int:
    var li: int = (ttz - grid_min_z) * grid_w + (ttx - grid_min_x)
    if li < 0 or li >= tile_grid.size():
        return IsoConst.TILE_WALL
    return tile_grid[li]
var hfield := TerrainMath.compute_height_field(
    grid_tile_lookup, chunk_origin.x, chunk_origin.z, nvx, nvz, step, CURVE_R, PLATEAU_H)
```

Never duplicate terrain algorithms — add new methods to `TerrainMath` instead.

---

## Canonical Constants: IsoConst Is the Source of Truth

### The problem
Tile type constants (`TILE_GRASS`, `TILE_WALL`, `TILE_HILL`), `TILE_SIZE`, `CHUNK_SIZE`,
and `WALL_FACE_H` were defined in multiple files. Changing one without updating the others
caused terrain rendering bugs.

### The fix
All gameplay constants live in `autoloads/IsoConst.gd`. Other files reference them via
`IsoConst.TILE_SIZE`, etc. `WorldMap` re-exports them as aliases (`const TILE_WALL: int = IsoConst.TILE_WALL`)
for backward compatibility — never add new copies elsewhere.

---

## Running Tests: Installing Godot

### The problem
Tests require the Godot 4 headless binary. If `godot` is not available in your environment,
tests cannot run.

### Installing Godot headless
```bash
# Download Godot 4 headless (Linux 64-bit)
wget -q https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip -O /tmp/godot.zip
unzip -o /tmp/godot.zip -d /tmp/godot
cp /tmp/godot/Godot_v4.4.1-stable_linux.x86_64 /usr/local/bin/godot
chmod +x /usr/local/bin/godot
rm -rf /tmp/godot /tmp/godot.zip
```

### Running tests
```bash
# From the project root
godot --headless --path . -s tests/runner.gd
```

Exit code 0 means all tests passed, 1 means one or more failed.
