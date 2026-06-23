# CLAUDE.md — Pear Pudding TCG

## Read Order

Before any task, read in this order:
1. `docs/human/specification.md`
2. `docs/human/workflow.md`
3. Relevant design docs in `docs/agent/`

## Ownership

- `docs/human/` — Human-owned. Never edit.
- `docs/agent/` — Agent-owned. Keep exhaustive and current.
- `tasks/` — Agent-managed. Follow workflow rules.

## Workflow

All functional code changes follow the task lifecycle in `docs/human/workflow.md`.

## Commands

- `/new-goal` — Research and create a goal with tasks
- `/work-task` — Execute a single task

---

## Map Storage: Native Godot .tres Resources

Maps are stored as `.tres` resource files in `assets/maps/`. The 6 built-in maps are preloaded by `autoloads/MapRegistry.gd`, which Godot automatically includes in exports. No bundling step is needed.

**Whenever you add a new built-in map:**
1. Create `assets/maps/<name>.tres` (use the in-game editor or write a converter script).
2. Add a `const _NAME := preload("res://assets/maps/<name>.tres")` line to `MapRegistry.gd`.
3. Add the name to the `_BUNDLED` dictionary in `MapRegistry.gd`.

Godot's export system tracks the preload dependencies and includes the `.tres` files in the APK/PCK automatically.

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

## GDScript: class_name — Always preload, Never Rely on Global Registration

### The problem
`class_name Foo` registers a global identifier, but **only after Godot's editor scanner has seen the file**. This fails in two situations:

1. **New files created by Claude** — the editor hasn't scanned them yet, so `Foo` is not registered.
2. **Load-order races at runtime** — even for existing, committed scripts, if a file is loaded before the class_name's defining script has been parsed in the current session, `Foo` is not available. This caused a real crash: `DiagnosticsScene.gd` called `BaseOverlay._make_dark_glass_style()` via the class_name. When SceneManager loaded `MenuScene` → `DiagnosticsScene` at battle start, `BaseOverlay` wasn't registered yet, causing a compile failure that propagated all the way up to SceneManager and crashed both combat start and the collect-rewards button.

```
Parse Error: Identifier "BaseOverlay" not declared in the current scope.
ERROR: Failed to load script 'res://autoloads/SceneManager.gd' with error 'Compilation failed'
```

### The fix
**Always `preload` the script in the file that uses it.** Never call static methods or reference a class_name without a preload in the same file.

```gdscript
# Bad — relies on class_name registration order
BaseOverlay.attach_drag_scroll(_scroll)
BaseOverlay._make_dark_glass_style()

# Good — explicit preload, always works
const _BaseOverlay = preload("res://scenes/ui/BaseOverlay.gd")
_BaseOverlay.attach_drag_scroll(_scroll)
_BaseOverlay._make_dark_glass_style()
```

**Exception — inherited statics:** If a file `extends "res://scenes/ui/BaseOverlay.gd"` (via path string, not class_name), inherited static methods can be called without a qualifier because the parent is already loaded as a dependency:

```gdscript
# OK — DiagnosticsScene extends BaseOverlay via path string, so the static is inherited
extends "res://scenes/ui/BaseOverlay.gd"
panel.add_theme_stylebox_override("panel", _make_dark_glass_style())
```

### Rule of thumb
If a file calls `Foo.some_method()` and does not have `extends "res://path/to/Foo.gd"` at the top, it **must** have `const Foo = preload("res://path/to/Foo.gd")` (or equivalent) at the top.

---

## GDScript: Always Validate Compilation — Parse Errors Cascade Through preload()

### The problem
A single parse/compile error in one `.gd` file silently breaks **every** scene
that `preload`s it, directly or transitively. Because `WorldScene.gd` preloads a
long chain (`WorldMap`, `ChunkRenderer`, `MapViewOverlay`, …), one bad line in any
of them makes the whole world fail to load: **blue screen, no terrain, no
collision, map overlay won't open, map editor crashes**. The symptoms look like a
rendering or physics bug, but the root cause is a script that never compiled.

These errors are invisible without running Godot — the file looks fine, and tests
that don't touch the broken script still pass. Real cases that shipped this way:

| Bug | Broke | Cascaded into |
|---|---|---|
| `hmap.cell_size = step` — `HeightMapShape3D` has no `cell_size` (runtime error aborts the function before its `return`) | `TerrainMath.build_terrain_mesh` returned a dict missing `mesh`/`hmap` | no terrain mesh, no collision |
| Bare `CHUNK_SIZE` after the local `const CHUNK_SIZE` was deleted | `WorldMap.gd` parse error | `WorldScene` + `MapEditorScene` (both preload it) |
| `ChunkRenderer.prepare_terrain()` — self-reference to a `class_name` the file doesn't declare | `ChunkRenderer.gd` parse error | `WorldScene` |
| `attach_drag_scroll()` called in a scene that doesn't `extends BaseOverlay` | `MapViewOverlay` / `BlacksmithScene` parse error | `WorldScene` (preloads `MapViewOverlay`) |

### The rule — run a headless import after ANY GDScript edit
The single check that catches all of the above is a full-project editor import
(autoloads loaded, every script compiled, `preload` chains followed):

```bash
godot --headless --editor --quit 2>&1 | \
  grep -iE "Parse Error|Compile Error|Failed to load script" | \
  grep -viE "imported/|Make sure resources"   # filter first-import texture noise
```

Empty output = clean. Any line is a real error to fix **before** committing.
`--check-only --script <file>` validates a single file but reports false
positives for autoloads (`SceneManager`, `AudioManager`, …) and `class_name`
globals, because it doesn't load them — prefer the full import for the verdict.
Install Godot per *Running Tests: Installing Godot* below if the binary is absent.

### Specific pitfalls these errors come from
- **Removing a `const` alias** (dead-code cleanup): grep the whole file for the
  bare name first — `grep -nE "[^.]CHUNK_SIZE"` — a missed usage is a parse error.
  Constants like `CHUNK_SIZE` must be referenced as `IsoConst.CHUNK_SIZE` unless
  the file declares a local alias.
- **Calling a script's own static method as `ClassName.method()`** only works if
  the file declares `class_name ClassName`. Inside the same file, call it
  unqualified (`method()`).
- **Calling an inherited method** (e.g. `attach_drag_scroll`, `_build_backdrop`)
  only works if the scene `extends "res://scenes/ui/BaseOverlay.gd"`. For scenes
  that can't (different base like `CanvasLayer`), make the helper a `static func`
  and call it as `BaseOverlay.attach_drag_scroll(...)`.
- **Setting an engine property that doesn't exist** (`HeightMapShape3D.cell_size`)
  throws at runtime and aborts the function mid-way — verify the property exists
  in the Godot docs for the class before assigning it.

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

## Mobile / Desktop Feature Parity

### The rule
Every interactive feature must be reachable on **both** desktop (keyboard/mouse) and mobile (touch). Never ship a keyboard-only feature without a touch equivalent, and vice versa.

### Pattern
| Desktop trigger | Mobile equivalent |
|---|---|
| Key press (`map_view` → M) | Tap the minimap to open the map overlay |
| Key press (`inventory` → I) | Inventory button in HUD |
| Key press (`interact` → E) | Tap prompt on screen |
| WASD movement | Virtual joystick overlay |

### Implementation checklist
- If you add a key binding, add a visible tap target for the same action (button, labelled icon, or existing HUD element with a `pressed` signal).
- The minimap tap button is a `flat = true` Button layered above the minimap ring in `Minimap.gd`; its `pressed` signal emits `tapped` which WorldScene connects to `_open_map_view()`.
- Do not rely on `_unhandled_input` alone for features users need on Android — `Button.pressed` and touch-screen equivalents are required.

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

## Android: Always preload() .tres Files — Never Use ResourceLoader.load()

### The rule
**Never use `ResourceLoader.load()` or `DirAccess` to load `.tres` files at runtime on Android.**

`DirAccess.open("res://...")` directory scanning is unreliable inside an Android APK/PCK. More critically, `ResourceLoader.load()` with a dynamic string path is invisible to Godot's export dependency scanner — the files will not be packaged in the APK and will silently fail to load.

### The fix
Always use `preload()` constants. This creates a compile-time dependency chain that Godot's scanner follows, guaranteeing the files are in the APK.

```gdscript
# Bad — dynamic string load, files missing from Android APK
var dir := DirAccess.open("res://data/skills")
var res := ResourceLoader.load("res://data/skills/" + fname)

# Good — explicit preloads, always packaged
const _SKILL_A := preload("res://data/skills/ember_searing_focus.tres")
const _SKILL_B := preload("res://data/skills/dawn_clarity.tres")
# …one const per file; add a new line whenever a new .tres is created
```

For registries that load many `.tres` files (e.g. `SkillRegistry.gd`), declare all resources as `const` preloads at the top, then iterate them in `_ensure_loaded()`:

```gdscript
const _S_EMBER_SEARING_FOCUS := preload("res://data/skills/ember_searing_focus.tres")
# …

static func _ensure_loaded() -> void:
    var all: Array = [_S_EMBER_SEARING_FOCUS, ...]
    for res in all:
        var skill: SkillData = res as SkillData
        if skill != null:
            _skills[skill.id] = skill
```

The dependency chain only works if the registry script itself is preloaded (directly or transitively) from a scene or autoload that Godot's scanner starts from.

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

---

## Named Map Player Spawn vs. Saved Position

### The rule
`WorldScene._spawn_player()` uses `save_manager.current_map == map_name` as the
guard to decide whether to restore a saved player position. **Do not add additional
guards** (e.g., `not world_map.has_player_spawn()`) to this branch — they break
save restoration for maps that define an explicit SPAWN marker.

### Why the guard works without extras
`save_manager.current_map` is written by `update_position(map_name, x, z)`, which
WorldScene calls from `_process` as the player moves. When entering a map fresh
(new game, door, waystone), `save_manager.current_map` still points to the **previous**
map at the time `_spawn_player` runs, so the condition is `false` and the spawn /
door position is used. Only a `continue_game()` load restores `current_map` to the
target map, making the condition `true` and restoring the saved coordinates.

### Entry-path summary

| Entry path | `current_map` at spawn time | Position used |
|---|---|---|
| New game → enter madrian | `"main"` (set by `new_game()`) | Spawn marker |
| Continue game in madrian | `"madrian"` (loaded from save) | Saved x/z |
| Door with target_door_id | any | Door position (first branch) |
| Waystone → enter madrian | `"main"` (world position flushed) | Spawn marker |
| Exit dungeon back to madrian | `"dungeon_*"` (last dungeon pos) | Spawn marker |

---

## Bug Fix Learnings

When a bug is fixed, record the root cause and the invariant it violated here so
future changes don't reintroduce it. Keep entries concise: one paragraph max.

### Named map position not restored on reload (fixed in claude/character-position-save-bug-0glsz2)

`_spawn_player` guarded save-position restore with `not world_map.has_player_spawn()`.
Maps that define a SPAWN marker (madrian, maykalene, and any future town maps) always
fell through to the spawn default on `continue_game`, ignoring the persisted `player_x/z`.
Fix: remove the `has_player_spawn()` guard; `current_map == map_name` is sufficient and
correct for all entry paths (see table above).

---

## Documentation: docs/agent/ Directory

Agent-owned feature documentation lives in `docs/agent/`. Each file covers **Key Features**, **How It Works**, **Integrations with Other Features**, and **Asset Requirements**.

When adding a new major feature or system, create a corresponding `.md` file in `docs/agent/` and add a row to this table.

| File | Feature |
|---|---|
| [docs/agent/docsplan.md](docs/agent/docsplan.md) | Documentation index and architecture overview |
| [docs/agent/battle-system.md](docs/agent/battle-system.md) | TCG card battles: game state, mana, boards, AI |
| [docs/agent/world-generation.md](docs/agent/world-generation.md) | Infinite chunks, 5 biomes, ruins, entity spawning |
| [docs/agent/named-maps-and-dungeons.md](docs/agent/named-maps-and-dungeons.md) | Text map format, DungeonGen, map stack navigation |
| [docs/agent/terrain-rendering.md](docs/agent/terrain-rendering.md) | TerrainMath mesh building, height fields, shaders, grass |
| [docs/agent/camera-and-player.md](docs/agent/camera-and-player.md) | Isometric camera math, WASD movement, chunk streaming |
| [docs/agent/inventory-and-deck.md](docs/agent/inventory-and-deck.md) | Card collection, deck builder UI, chest drops |
| [docs/agent/save-system.md](docs/agent/save-system.md) | JSON persistence, dirty flag, field migration |
| [docs/agent/enemies-and-npcs.md](docs/agent/enemies-and-npcs.md) | Enemy types, wander/track/engage AI, NPC dialogue |
| [docs/agent/ui-and-scene-management.md](docs/agent/ui-and-scene-management.md) | Scene stack, battle overlay, menus, HUD, day/night |
| [docs/agent/signals-and-constants.md](docs/agent/signals-and-constants.md) | GameBus signals, IsoConst values, decoupling patterns |
| [docs/agent/story-implementation.md](docs/agent/story-implementation.md) | Story flags, dialogue gating, SaveManager fields, SceneManager entry point |
| [docs/agent/story-narration-scrolls.md](docs/agent/story-narration-scrolls.md) | Lore scroll entities, ScrollRegistry, narration audio, Journal UI, achievement hook |
| [docs/agent/skill-trees.md](docs/agent/skill-trees.md) | Branch skill trees, magic type selection, corruption/redemption currencies, cross-magic unlock |
| [docs/agent/treasure-maps.md](docs/agent/treasure-maps.md) | Treasure map fragments, deterministic dig sites, DigSpot entity, map overlay marker |
| [docs/agent/waystone-fast-travel.md](docs/agent/waystone-fast-travel.md) | Waystone entities, ID scheme, save tracking, placement, fast-travel UI, teleport routing |
| [docs/agent/bestiary-codex.md](docs/agent/bestiary-codex.md) | Bestiary system: lore fields, encounter/defeat tracking, JournalScene tab, completion rewards |
| [docs/agent/player-home.md](docs/agent/player-home.md) | Player home purchase, interior map, trophy pedestals, bed respawn, game-over routing |
| [docs/agent/home-garden-potions.md](docs/agent/home-garden-potions.md) | Home garden plots, seed growth via days_elapsed, plant harvest, potion crafting, one-per-battle potion use |
| [docs/agent/tap-to-move.md](docs/agent/tap-to-move.md) | Tap/click pathfinding: A* Pathfinder, screen-to-tile raycast, destination marker, path following |
| [docs/agent/rideable-mounts.md](docs/agent/rideable-mounts.md) | Mount purchase flow, speed multiplier, HUD button, auto-dismount/remount rules, sprite + dust visuals |
| [docs/agent/card-packs.md](docs/agent/card-packs.md) | Card Packs & Pack Opening | Pack tiers, roll logic, pity counter, tap-to-flip ceremony UI, SceneManager routing |
| [docs/agent/bounty-board.md](docs/agent/bounty-board.md) | Bounty Board Contracts | BountyGen, daily seeded generation, SaveManager fields, rollover logic |
| [docs/agent/night-hunts.md](docs/agent/night-hunts.md) | Night Hunts | Spectral enemy spawning, nocturnal system, drop boost, minimap coloring, tutorial |
| [docs/agent/card-cantrips.md](docs/agent/card-cantrips.md) | Card Cantrips | Ghost Phase, Skeleton Dig, CantripManager, burial mound spawning, cooldown persistence |
| [docs/agent/blight-system.md](docs/agent/blight-system.md) | Creeping Blight | BlightField pure logic, terrain shader tint, enemy buff, BlightHeart entity, cleansing, Redemption Points |
| [docs/agent/ancient-colossi.md](docs/agent/ancient-colossi.md) | Ancient Colossi | Landmark placement, 5 biome variants, CPU ArrayMesh structures, name generator, discovery system, Journal tab |
| [docs/agent/ley-lines.md](docs/agent/ley-lines.md) | Ley Lines | Simplex noise bands, UV2 terrain glow, speed boost, Attuned battle buff, Mana Wells |
| [docs/agent/app-diagnostics.md](docs/agent/app-diagnostics.md) | App Diagnostics Log Screen | AppLog ring buffer, auto-logged GameBus signals, DiagnosticsScene overlay, pause & menu entry points |
| [docs/human/story.md](docs/human/story.md) | Story bible: characters, chapters, NPC dialogue, map specs (human-owned) |
