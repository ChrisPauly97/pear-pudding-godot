# Rideable Mounts (GID-048)

## Key Features

- **MountRegistry** — static dictionary registry in `game_logic/MountRegistry.gd`; `stable_horse` is the only mount in v1 (2× speed, 750 coins).
- **SaveManager persistence** — `owned_mounts: Array[String]`, `active_mount: String`, `is_mounted: bool` are saved/migrated (version 24).
- **Speed multiplier** — `Player._get_move_speed()` multiplies `SPEED` by the mount's `speed_multiplier` when `is_mounted and current_map == "main"`.
- **Stable NPC** — `npc_type = "stable"` in `assets/maps/madrian.tres` at tile (75, 42). Routed by `WorldScene._handle_interact()` to `_show_stable_panel()`. Level 10 gate + 750-coin check; on purchase summons the mount immediately.
- **HUD button** — flat `Button` below Skills in `WorldScene._build_hud()`, text toggles "Mount"/"Dismount", hidden when no mounts owned or not in main map. T key (action `"mount"`) is the keyboard equivalent.
- **Auto-dismount / remount** — see below.
- **Mounted visuals** — mount sprite and dust particles in `Player.gd`.

## How It Works

### Purchase Flow

`WorldScene._show_stable_panel()` shows an inline panel overlay (CanvasLayer → PanelContainer). Checks `sm.level >= 10` and `sm.coins >= 750`. On buy: `sm.add_coins(-750)`, `sm.owned_mounts.append("stable_horse")`, `sm.summon_mount("stable_horse")`.

### Summon / Dismiss API

```gdscript
SaveManager.summon_mount(mount_id)   # sets is_mounted=true, active_mount=mount_id, emits mount_state_changed
SaveManager.dismiss_mount()          # sets is_mounted=false, active_mount="", emits mount_state_changed
SaveManager.auto_dismiss_mount()     # sets is_mounted=false, KEEPS active_mount, emits mount_state_changed
```

`auto_dismiss_mount()` is the key difference: used for battle and map-entry auto-dismount so `active_mount` is preserved for the remount that happens on return.

### Auto-Dismount Rules

| Trigger | Handler | Method called |
|---|---|---|
| Battle starts (`enemy_engaged`) | `WorldScene._on_enemy_engaged_for_mount()` | `auto_dismiss_mount()` |
| Entering non-main map (door) | `WorldScene._handle_interact()` guard | `auto_dismiss_mount()` |

### Auto-Remount Rules

| Trigger | Where |
|---|---|
| Battle won (`battle_won` callback in WorldScene) | `sm.summon_mount(sm.active_mount)` if `active_mount != ""` and `current_map == "main"` |
| WorldScene `_ready()` when `map_name == "main"` | `sm.summon_mount(sm.active_mount)` if `active_mount != ""` and `not is_mounted` |

The second trigger fires whenever a fresh WorldScene is created for "main" (e.g. after exiting a dungeon or named map).

### Mounted Visuals (Player.gd)

- **Mount sprite** (`_mount_sprite: Sprite3D`): real pixel art since GID-118/TID-447 —
  `SpriteRegistry.mount_texture()` (`assets/textures/characters/mount_horse.png`, 32×32,
  Clint Bellanger's Tiny Creatures pack, CC0), falling back to `TextureGen.mount_horse()`
  (48×24 procedural) if the file is missing. PIXEL_SIZE=0.05, positioned with the
  feet-at-y=0 formula computed from the **actual** texture height (`sprite.position.y
  = tex.get_height() * PIXEL_SIZE * 0.5`) — not a hardcoded `0.6`, since the real
  sprite's height differs from the old procedural fallback's. Shown/hidden via
  `_update_mount_visuals()` which is called from `_on_mount_state_changed()` connected
  to `GameBus.mount_state_changed`.
- **Dust particles** (`_dust_particles: GPUParticles3D`): 20 particles, 0.6 s lifetime, brownish colour, sphere emission radius 0.4. `emitting` toggled every physics frame: `is_mounted and _is_moving`.

### TextureGen.mount_horse()

Cached static method returning a 48×24 ImageTexture. Brown body + mane/tail + four legs, transparent background. Now only used as a fallback if `mount_horse.png` is absent (`test_mount_dismount_visuals.gd` exercises this function directly, unaffected by the sprite swap).

## Integrations

| System | Integration |
|---|---|
| `SaveManager` | `owned_mounts`, `active_mount`, `is_mounted`, `summon_mount()`, `dismiss_mount()`, `auto_dismiss_mount()` |
| `GameBus` | `mount_state_changed(mounted: bool, mount_id: String)` |
| `WorldScene` | HUD button, stable NPC routing, battle/map auto-dismount/remount |
| `Player.gd` | Speed multiplier via `_get_move_speed()`, mount sprite, dust particles |
| `MountRegistry` | Data source for display name, speed_multiplier, price |
| `SpriteRegistry` | `mount_texture()` real sprite; `TextureGen.mount_horse()` fallback |

## Asset Requirements

- `assets/textures/characters/mount_horse.png` — real sprite (GID-118/TID-447); see `CREDITS.md`. `TextureGen.mount_horse()` remains as a runtime fallback if the file is ever removed.
- No new `.tres` files — mount data is a GDScript dictionary in `MountRegistry.gd`. The PNG has a committed `.uid`-equivalent `.import` sidecar (auto-generated, not a `.uid` file — plain PNGs don't need one).
