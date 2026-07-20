# Card Cantrips — Your Deck Shapes the World (GID-065)

## Key Features

- **Ghost Phase**: player phases through one TILE_WALL tile in the facing direction when the deck contains ≥4 Ghost-family cards. 15-second cooldown.
- **Skeleton Dig**: player digs buried mounds spawned in ~10% of open-world chunks. Requires ≥4 Skeleton-family cards in deck. 10-second cooldown. Rewards: 10–30 coins + 60% card / 40% essence.
- HUD buttons `[G] Phase` and `[D] Dig` (left side of screen), plus keyboard keys G and D.
- Both keys also work on desktop; the HUD buttons are the mobile touch targets.
- Buttons are **always visible** (TID-463 / BID-050), even when locked: a
  locked button is dimmed and shows a family-card progress count
  (`"[G] Phase (3/4)"`); it stays clickable so a curious tap still surfaces
  the "requires N+ family cards" HUD message via the existing
  `_activate_ghost_phase()` / `_activate_skeleton_dig()` guard.
- Cooldowns persist in `SaveManager.cantrip_cooldowns` (Dictionary: cantrip_id → Unix expiry float).
- Dug mounds persist in `SaveManager.dug_mounds` (Array[String] of mound IDs).

## How It Works

### CantripManager (`game_logic/world/CantripManager.gd`)

Pure static utility — no mutable state, headless-testable.

| Method | Description |
|---|---|
| `is_available(cantrip_id, template_ids)` | Returns true if deck has ≥threshold family cards |
| `available_cantrips(template_ids)` | Returns all unlocked cantrip IDs |
| `count_family(cantrip_id, template_ids)` | Current family-card count, for the locked-button progress readout (TID-463) |
| `get_threshold(cantrip_id)` | Returns the deck-count threshold (4 for both cantrips) |
| `get_cooldown(cantrip_id)` | Returns cooldown duration in seconds |
| `is_on_cooldown(cantrip_id, cooldowns, current_time)` | Returns true if expiry > current_time |
| `cooldown_remaining(cantrip_id, cooldowns, current_time)` | Seconds remaining (0 if not cooling) |

Card families:
- **Ghost Phase**: `["ghost", "dusk_wraith", "shrouded_wraith", "surge_spirit"]`
- **Skeleton Dig**: `["skeleton", "zombie", "ghoul", "blitz_ghoul", "iron_revenant"]`

### Ghost Phase Flow

1. Player presses G or taps `[G] Phase` button.
2. `WorldScene._activate_ghost_phase()` checks availability and cooldown.
3. `_do_ghost_phase()` scans cardinal directions (facing direction first) for a sequence: walkable → TILE_WALL → non-wall.
4. On match, `_start_ghost_phase_tween()` disables player collision, fades sprite alpha to 0.5, tweens position over 0.3s.
5. `_on_ghost_phase_done()` restores collision and alpha.
6. Cooldown expiry stored in `SaveManager.cantrip_cooldowns["ghost_phase"]`.
7. `GameBus.cantrip_used("ghost_phase")` emitted.

Collision layers restored: `collision_layer = 1`, `collision_mask = 2 | 4` (terrain + walls).

**NEVER call `camera.look_at()` during or after the tween** — the isometric camera rotation is baked.

### Skeleton Dig Flow

1. Burial mounds spawn in ~10% of open-world chunks via `InfiniteWorldGen._gen_entities()`.
2. Mound ID format: `"mound_<cx>_<cz>_0"`. Deterministic: same seed+coords = same mound.
3. `BurialMound.init_from_data(data)` checks `SaveManager.dug_mounds` — hides node if already dug.
4. Player approaches mound (within `IsoConst.INTERACT_RANGE`) → interact prompt shown.
5. Player presses E, taps USE, or presses D → `BurialMound.interact()` called.
6. `interact()` checks CantripManager availability, then cooldown, then gives seeded rewards.
7. Rewards seeded from `hash(mound_id)` so same mound always gives same loot on first dig.
8. Mound ID added to `SaveManager.dug_mounds`; cooldown recorded; node hidden.
9. `GameBus.cantrip_used("skeleton_dig")` emitted.

## Integrations

| System | Integration |
|---|---|
| SaveManager | `cantrip_cooldowns: Dictionary`, `dug_mounds: Array[String]`; save version 37 |
| GameBus | `signal cantrip_used(cantrip_id: String)` |
| InfiniteWorldGen | Burial mounds in `ChunkData.burial_mounds: Array[Dictionary]` |
| ChunkRenderer | Preloads `_BurialMoundScene`, calls `world_scene.register_burial_mound()` |
| WorldScene | HUD buttons, G/D key handling, entity registration/teardown |
| TutorialRegistry | `"cantrips"` teaser popup (GID-117): `WorldHUD._maybe_teach_cantrips()` emits `tutorial_popup_requested("cantrips")` when a cantrip button is visible (initial build + `refresh_action_cluster`); once-per-save via `seen_tutorial_cantrips` story flag. Fires on first world entry — the starter deck's 9 Skeleton-family cards already unlock Dig |

## Asset Requirements

- `game_logic/world/CantripManager.gd` — pure static utility
- `scenes/world/entities/BurialMound.gd` + `BurialMound.tscn` — entity scene
- `.uid` sidecars for both `.gd` files
- No new textures required (procedural brown cylinder mesh)
