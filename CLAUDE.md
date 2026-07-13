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

## Map Storage
Maps are `.tres` files in `assets/maps/`, preloaded by `autoloads/MapRegistry.gd`. To add a built-in map:
1. Create `assets/maps/<name>.tres`
2. Add `const _NAME := preload("res://assets/maps/<name>.tres")` to `MapRegistry.gd`
3. Add name to `_BUNDLED` dictionary in `MapRegistry.gd`

---

## GDScript: Variant Inference — Use Explicit Types

`:=` on a Variant RHS is a strict-mode parse error. Always annotate:

| Expression | Fix |
|---|---|
| `array[i]`, `max()`, `min()`, `lerp()`, `clamp()` | `var x: int = ...` |
| Untyped array index | Use `Array[int]` typed array |

```gdscript
var step: int = max(1, depth / 8)          # not :=
var depths: Array[int] = [10, 20, 30]
var d := depths[i]                          # OK — typed array
var deck: Array[String] = []
deck.assign(enemy_data["enemy_deck"])       # dict values are plain Array
```

---

## GDScript: Freed Node Dictionary Crash

Casting a freed object ref crashes **at the cast**, before any validity check. Dicts tracking nodes by id can hold stale refs after `queue_free()`.

```gdscript
# Bad — crashes if freed
var node: Node3D = _enemy_nodes.get(eid) as Node3D

# Good — check untyped first
func _valid_node3d(v) -> Node3D:
    return v if is_instance_valid(v) else null

var node: Node3D = _valid_node3d(_enemy_nodes.get(eid))
```

Reuse `WorldScene._valid_node3d()` / `_valid_node()`. Any dict tracking live nodes needs this pattern.

---

## GDScript: class_name — Always preload

`class_name` registration depends on editor scan order — new files and load-order races both fail. Always `preload` instead:

```gdscript
# Bad
BaseOverlay.attach_drag_scroll(_scroll)

# Good
const _BaseOverlay = preload("res://scenes/ui/BaseOverlay.gd")
_BaseOverlay.attach_drag_scroll(_scroll)
```

**Exception:** If `extends "res://path/to/Foo.gd"`, inherited statics work without qualifier.

**Rule:** Calling `Foo.method()` without `extends "res://...Foo.gd"` requires `const Foo = preload(...)`.

---

## GDScript: Always Validate Compilation

One parse error silently breaks every scene that `preload`s it. Run after **any** `.gd` edit:

```bash
godot --headless --editor --quit 2>&1 | \
  grep -iE "Parse Error|Compile Error|Failed to load script" | \
  grep -viE "imported/|Make sure resources"
```

Empty output = clean. Common pitfalls:
- Removing a `const` alias — grep for bare usages first
- `ClassName.method()` inside the same file — call unqualified
- Inherited methods only work if the scene `extends` the right base
- Setting non-existent engine properties (verify in Godot docs first)

---

## Camera: Isometric Follow

Never call `look_at` — it destroys the baked iso rotation. Only move position:

```gdscript
_camera.position = _player.position + Vector3(20, 20, 20)  # opposite of look dir (-1,-1,-1)
```

---

## Sprite3D: Depth Clipping

Billboard sprites clip below `y=0` if origin is too low.
Formula: `sprite.position.y = pixel_height * pixel_size * 0.5 + small_margin`

---

## Grass / Environmental Physics

Grass shaders: `wind_direction: vec2` uniform + `player_pos: vec3` per-frame. Blades within `player_radius` push radially. Update from `_process()`, not physics.

Godot 4 has **no geometry shaders**. Use: fragment shader (foliage), `ArrayMesh` (procedural geo), `GPUParticles3D` (trails).

---

## UI Sizing: Relative to Viewport

Never hard-code pixel sizes:

```gdscript
var vh: float = get_viewport().get_visible_rect().size.y
button.custom_minimum_size = Vector2(vh * 0.12, vh * 0.05)
```

| Control | Width | Height |
|---|---|---|
| Standard button | 12–18% vh | 5–6% vh |
| Icon/square button | 5–6% vh | 5–6% vh |
| Panel/sidebar | 20–25% vw | — |
| Font size | — | 2–2.5% vh |

Re-apply in `_notification(NOTIFICATION_RESIZED)`.

---

## HUD Buttons: Use the Action Registry

Never `Button.new()` + `_hud.add_child()` directly — causes silent position overlaps:

```gdscript
# Bad
var btn := Button.new()
btn.position = Vector2(vh * 0.5, vh * 0.72)
_hud.add_child(btn)

# Good
_new_feature_btn = _world_hud.register_action(
    "new_feature", "New Feature", WorldHUD.ZONE_CONTEXT, _on_new_feature_pressed)
```

Always-on buttons usually belong in `PartyPanel.gd`, not the HUD. `test_hud_registry_guardrail.gd` fails if a bare `_hud.add_child(<Button>)` appears in `WorldScene.gd`.

---

## Mobile / Desktop Feature Parity

Every feature needs both keyboard/mouse and touch equivalents. If you add a key binding, add a tap target. Don't rely on `_unhandled_input` alone for Android.

---

## Godot Resource .uid Files

Every `.gdshader`, `.tres`, `.material`, `.theme`, `.gdextension` needs a `.uid` sidecar. Create immediately after the resource:

```
uid://a1b2c3d4e5f6   # exactly 12 lowercase alphanumeric chars
```

Generate: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`

Always `preload()` resources, never `load()`. CI headless import fills missing UIDs, but commit the sidecar for stable local IDs. (Plain `.gd` and `.tscn` files don't need sidecars.)

---

## Android: Always preload() .tres Files

Never `ResourceLoader.load()` or `DirAccess` for `.tres` on Android — dynamic paths aren't packaged in the APK:

```gdscript
# Bad
var res := ResourceLoader.load("res://data/skills/" + fname)

# Good — one const per file
const _SKILL_A := preload("res://data/skills/ember_searing_focus.tres")
```

Declare all resources as `const` preloads; iterate them in `_ensure_loaded()`.

---

## TerrainMath

All terrain logic lives in `game_logic/TerrainMath.gd`. Both named-map and infinite-chunk paths delegate via `Callable` tile lookups. Never duplicate terrain algorithms.

---

## Constants: IsoConst Is the Source of Truth

All tile/size constants (`TILE_GRASS`, `TILE_SIZE`, `CHUNK_SIZE`, etc.) live in `autoloads/IsoConst.gd`. Reference as `IsoConst.TILE_SIZE`. Never add copies elsewhere.

---

## Running Tests

Install Godot headless:
```bash
wget -q https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip -O /tmp/godot.zip
unzip -o /tmp/godot.zip -d /tmp/godot
cp /tmp/godot/Godot_v4.6-stable_linux.x86_64 /usr/local/bin/godot
chmod +x /usr/local/bin/godot
```

Run: `godot --headless --path . -s tests/runner.gd` (exit 0 = pass)

---

## Named Map Player Spawn vs. Saved Position

`_spawn_player()` uses `save_manager.current_map == map_name` to restore saved position. **Don't add extra guards** — `current_map` is only set to the target map on `continue_game()`, so fresh entry paths naturally fall through to spawn/door position.

| Entry path | Position used |
|---|---|
| New game / door / waystone | Spawn marker or door position |
| Continue game (same map) | Saved x/z |

---

## Bug Fix Learnings

### Named map position not restored (claude/character-position-save-bug-0glsz2)
Removed `not world_map.has_player_spawn()` guard — it broke save restoration for maps with SPAWN markers. `current_map == map_name` is sufficient.

### Dead signal connect aborted `_ready` (claude/game-multiplayer-networking-fb94pj)
Never `connect` to a GameBus signal without confirming it still exists in `GameBus.gd`. A throwing statement at the tail of `_ready` silently kills everything appended after it.

### Re-hosting failed — stale ENet peer (GID-092 / TID-337)
Always `close()` a `MultiplayerPeer` before dropping it. Nulling alone leaks the bound port.

### Cold co-op had no deck (GID-092 / TID-335)
Features reachable without `new_game()`/`load()` must not assume save-backed state exists. Seed a transient default.

### PvP client lost signal on `GameState` replacement (GID-092 / TID-336)
Reconnect signals whenever you replace a cached state object created via `from_dict`.

### Python idioms in GDScript (GID-094 / TID-341)
Use `/` not `//` for int division. `Object.get()` takes one arg — no default. Run headless import after every `.gd` edit.

### Co-op avatar cross-map ghosts (GID-096 / TID-352)
Sync layers must carry a map discriminator in the payload and filter on receive. Entry-point gating alone is insufficient.

### Stale co-op session leaked into New Game (claude/single-player-multiplayer-bug-wlaoij)
`go_to_menu()` must call `NetworkManager.leave()`. State flags must be reset by every exit path, not just defensively re-checked at entry.

### 140 GodotBody3D RIDs leaked on exit — detached world orphaned at quit (claude/p11godotbody3d-rid-leak-vd2ny6)
SceneTree teardown only frees in-tree nodes. Battles/puzzles detach WorldScene into `SceneManager._saved_world_scene`; quitting mid-battle left it an orphan and leaked every physics body in it. `SceneManager._exit_tree()` frees the orphan with an immediate `free()` (`queue_free()` never flushes at shutdown). Any stash holding a detached node needs the same explicit shutdown free.

### Nocturnal despawn — "modulate:a does not exist" (fixed with automation bridge)
`Node3D` has no `modulate`. Always resolve to `Sprite3D`/`CanvasItem` child before tweening modulate.

---

## Documentation: docs/agent/ Directory

Agent-owned feature docs. Each covers Key Features, How It Works, Integrations, and Asset Requirements. Add a row when adding a major feature.

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
| [docs/agent/card-packs.md](docs/agent/card-packs.md) | Pack tiers, roll logic, pity counter, tap-to-flip ceremony UI, SceneManager routing |
| [docs/agent/bounty-board.md](docs/agent/bounty-board.md) | BountyGen, daily seeded generation, SaveManager fields, rollover logic |
| [docs/agent/night-hunts.md](docs/agent/night-hunts.md) | Spectral enemy spawning, nocturnal system, drop boost, minimap coloring, tutorial |
| [docs/agent/card-cantrips.md](docs/agent/card-cantrips.md) | Ghost Phase, Skeleton Dig, CantripManager, burial mound spawning, cooldown persistence |
| [docs/agent/blight-system.md](docs/agent/blight-system.md) | BlightField pure logic, terrain shader tint, enemy buff, BlightHeart entity, cleansing, Redemption Points |
| [docs/agent/ancient-colossi.md](docs/agent/ancient-colossi.md) | Landmark placement, 5 biome variants, CPU ArrayMesh structures, name generator, discovery system, Journal tab |
| [docs/agent/ley-lines.md](docs/agent/ley-lines.md) | Simplex noise bands, UV2 terrain glow, speed boost, Attuned battle buff, Mana Wells |
| [docs/agent/app-diagnostics.md](docs/agent/app-diagnostics.md) | AppLog ring buffer, auto-logged GameBus signals, DiagnosticsScene overlay, pause & menu entry points |
| [docs/agent/multiplayer-coop.md](docs/agent/multiplayer-coop.md) | NetworkManager transport (4 players), RemotePlayer avatars, NetSync/AvatarSync, PvP (BattleNetProtocol/Sync), draft duels, tournaments, wagers |
| [docs/agent/visual-polish.md](docs/agent/visual-polish.md) | ProceduralSkyMaterial, biome color grade, vignette, GPU-instanced props, highlight rings, card art |
| [docs/agent/audio-soundtrack.md](docs/agent/audio-soundtrack.md) | Curated CC0/CC-BY music shortlist per slot (7 slots), acquisition/conversion steps, attribution requirements |
| [docs/human/story.md](docs/human/story.md) | Story bible: characters, chapters, NPC dialogue, map specs (human-owned) |
