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

## Floor Collision

Grass tile `MeshInstance3D` nodes are visual only — no physics. Without a floor collider the player falls through due to gravity. Add a single `StaticBody3D` with a large `BoxShape3D` covering the whole map:

```gdscript
func _build_floor_collision() -> void:
    var floor_body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    var box := BoxShape3D.new()
    var map_size: float = WorldMap.MAP_WIDTH * IsoConst.TILE_SIZE
    box.size = Vector3(map_size, 0.1, map_size)
    col.shape = box
    floor_body.position = Vector3(map_size * 0.5, -0.05, map_size * 0.5)
    floor_body.add_child(col)
    add_child(floor_body)
```

`WorldBoundaryShape3D` is not available in all Godot 4 builds — use `BoxShape3D` instead.
