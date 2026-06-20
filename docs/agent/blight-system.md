# Blight System (GID-066)

## Key Features

- Deterministic Blight Hearts seeded from `world_seed` spread corruption chunk-by-chunk each in-game day.
- Blighted chunks receive a dark-purple terrain shader tint via per-instance shader uniform (no material duplication).
- Enemies in blighted chunks gain +5 HP at battle start.
- Players can cleanse a heart via a boss-tier card battle, permanently purifying its region and earning +10 Redemption Points.
- All blight state is a pure function of `(world_seed, days_elapsed, blight_cleansed_hearts)` — no per-chunk persistence.

## How It Works

### Heart Placement — `game_logic/world/BlightField.gd`

A pure static module, no autoload dependencies.

| Constant | Value | Meaning |
|---|---|---|
| `SUPER_SIZE` | 12 | Super-region side length in chunks (12×12 = 144 chunks per region) |
| `HEART_DENSITY` | 3 | 1-in-3 super-regions get a heart (~33%) |
| `INITIAL_RADIUS` | 2.0 | Chunks blighted from day 0 |
| `SPREAD_RATE` | 0.5 | Chunks per day the radius grows |
| `MAX_RADIUS` | 10.0 | Hard cap on spread radius |
| `SAFE_CHUNK_RADIUS` | 6 | Manhattan distance from origin with no hearts |

**Heart ID format:** `"heart_{sx}_{sz}"` where `sx`, `sz` are super-region coordinates.

**Placement hash:** `((sx*73856093) ^ (sz*19349663) ^ world_seed) & 0x7FFFFFFF % HEART_DENSITY == 0`

**Heart chunk within super-region:** `cx = sx*SUPER_SIZE + (hash >> 4) % SUPER_SIZE`, similarly for `cz`.

### Spread & Intensity

```gdscript
static func blighted_radius(days_elapsed: int) -> float:
    return minf(INITIAL_RADIUS + float(days_elapsed) * SPREAD_RATE, MAX_RADIUS)

static func blight_intensity(cx, cz, world_seed, days_elapsed, cleansed_hearts) -> float:
    # Returns 0.0 (clean) to 1.0 (heart center) based on distance to nearest active heart
    # Fades from 1.0 at the heart outward to 0.0 at the blight radius edge
```

The search radius for nearby hearts is `ceil(MAX_RADIUS / SUPER_SIZE) + 1 = 2` super-regions.

### Shader Tinting

`assets/shaders/terrain.gdshader` has an `instance uniform float blight_amount : hint_range(0.0, 1.0) = 0.0`.

In fragment:
```glsl
if (blight_amount > 0.0) {
    float lum = dot(tinted_col, vec3(0.299, 0.587, 0.114));
    vec3 blight_col = vec3(lum * 0.35 + 0.05, lum * 0.15, lum * 0.30);
    tinted_col = mix(tinted_col, blight_col, blight_amount * 0.75);
}
```

The `instance uniform` means each `MeshInstance3D` gets its own value — no material duplication needed. `ChunkRenderer.set_blight_amount(intensity)` calls `set_instance_shader_parameter("blight_amount", intensity)` on both the terrain mesh and the wall face mesh.

### Refresh Timing

Blight state only changes on:
1. **Day rollover** — `WorldScene._update_day_night()` emits `GameBus.blight_changed()`
2. **Heart cleansed** — `SceneManager._on_battle_won()` emits `GameBus.blight_changed()`

`WorldScene._refresh_blight_tints()` handles the signal and iterates `_chunk_renderers` to update uniforms.

### Enemy Buff

`SceneManager._on_enemy_engaged()` stamps `enemy_data["is_blighted"]` from `WorldScene.get_battlefield_context()`. `BattleScene` applies +5 HP to the enemy hero if `is_blighted == true` **and** `enemy_data` does not carry `blight_heart_id` (blight heart fights are already boss-tier and don't need the additional buff).

### BlightHeart Entity — `scenes/world/entities/BlightHeart.gd`

A pulsing dark-purple sphere mesh with a semi-transparent aura. Spawned by `ChunkRenderer._spawn_entities()` using `BlightField.get_heart_at_chunk()` — skipped if `SaveManager.is_heart_cleansed(heart_id)`.

`engage()` emits `GameBus.enemy_engaged` with:
- `enemy_type: "blight_heart"` (registered in `EnemyRegistry`)
- `is_boss: true`, `boss_hp: 40`
- `blight_heart_id: _heart_id` — the win handler uses this to trigger cleansing

`WorldScene` registers hearts via `register_blight_heart()` and includes them in `_check_interactions()` / `_handle_interact()`.

### On Victory — Cleansing

In `SceneManager._on_battle_won()`, after the veterancy block:
```gdscript
var blight_heart_id: String = str(save_manager.pending_battle_enemy_data.get("blight_heart_id", ""))
if blight_heart_id != "":
    save_manager.mark_heart_cleansed(blight_heart_id)   # persisted to save
    save_manager.add_redemption_points(10)               # +10 Redemption Points
    GameBus.blight_changed.emit()                        # re-tints all loaded chunks
    GameBus.hud_message_requested.emit("The blight recedes… +10 Redemption Points.")
```

The heart node `queue_free()`s itself in `engage()`, and `mark_heart_cleansed` means it will never respawn (the spawn check skips cleansed hearts).

## Integrations with Other Features

| Feature | Integration |
|---|---|
| **SaveManager** | `blight_cleansed_hearts: Array[String]`; save version bumped 37→38 with migration |
| **GameBus** | `signal blight_changed()` |
| **ChunkRenderer** | `set_blight_amount()`, initial tint in `build_visual()`, BlightHeart spawn in `_spawn_entities()` |
| **WorldScene** | `get_battlefield_context()` includes `is_blighted`; `_refresh_blight_tints()` on `blight_changed` |
| **SceneManager** | Stamps `is_blighted` on engage; cleanses heart on win |
| **BattleScene** | +5 enemy HP buff for blighted-zone fights (non-heart only) |
| **EnemyRegistry** | `"blight_heart"` boss entry |
| **Redemption points** | `add_redemption_points(10)` on each cleanse |

## Asset Requirements

- `scenes/world/entities/BlightHeart.tscn` + `BlightHeart.gd` + `.uid` sidecars — all committed.
- `game_logic/world/BlightField.gd` + `.uid` sidecar — all committed.
- `assets/shaders/terrain.gdshader` — already had a `.uid` sidecar; no new sidecar needed.
