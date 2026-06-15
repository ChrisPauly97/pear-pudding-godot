# Bounty Board Contracts

## Key Features

- Three seeded daily bounty contracts per in-game day, offered at town bounty boards.
- Bounty types: defeat N enemies of a specific type, defeat N enemies in a biome, open N chests.
- Coin rewards scale with difficulty (count and enemy tier / biome depth).
- Progress tracked via existing GameBus signals; accepted bounties surface as a live HUD tracker.
- State persists across sessions in SaveManager; unaccepted offers expire on day rollover, in-progress bounties carry over.

## How It Works

### BountyGen (`game_logic/BountyGen.gd`)

Static-only RefCounted. All logic is pure functions with no side effects.

`generate_daily(world_seed: int, day_index: int) -> Array[Dictionary]`
Returns exactly 3 bounties. Seeded with `(world_seed ^ (day_index * 2654435761)) & 0x7FFFFFFF` (same pattern as TreasureGen).

One of each bounty type per day, in fixed order (defeat_enemy_type, defeat_in_biome, open_chests):

| Type | `target` | `count` range | Reward formula |
|---|---|---|---|
| `defeat_enemy_type` | enemy type ID (see ENEMY_TYPE_IDS) | 2–4 | 40 + count × 15 + difficulty_tier × 10 |
| `defeat_in_biome` | biome name string (see BIOME_NAMES) | 3–5 | 50 + count × 12 + biome_index × 15 |
| `open_chests` | `"chest"` | 1–3 | count × 30 |

Each entry has fields: `id` (e.g., `"bounty_42_deftype_0"`), `type`, `target`, `count`, `reward`.

Public constants:
- `ENEMY_TYPE_IDS: Array[String]` — `["undead_basic", "undead_horde", "ghoul_pack", "undead_elite"]`
- `BIOME_NAMES: Array[String]` — `["grasslands", "forest", "desert", "scorched", "mountains"]`

### SaveManager Fields (save version 28)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `bounty_day` | int | 0 | Day index for which current bounties were generated |
| `offered_bounties` | Array[Dictionary] | [] | Today's available bounties (not yet accepted); cleared on day rollover |
| `active_bounties` | Array[Dictionary] | [] | Accepted in-progress bounties; carry over until claimed |

`offered_bounties` entries extend the BountyGen dict with `"offered_at_day": int`.
`active_bounties` entries further add `"accepted_at_day": int`, `"progress": int`, `"claimed": bool`, `"completed": bool`.

### Refresh / Rollover

`SaveManager._refresh_bounties()` is called from:
- `increment_day()` — triggers at midnight when the day increments
- `get_offered_bounties()` — called by the board entity (TID-189) to ensure data is current

Rollover logic: if `days_elapsed != bounty_day` or `offered_bounties` is empty, `offered_bounties` is cleared and regenerated for the current day. `active_bounties` are not touched.

### Public API

```gdscript
SaveManager.get_offered_bounties() -> Array[Dictionary]  # auto-refreshes if stale
SaveManager.get_active_bounties() -> Array[Dictionary]
SaveManager.accept_bounty(id: String) -> bool            # moves offered→active, max-3 cap
SaveManager.claim_bounty(id: String) -> int              # pays coins, returns reward (0 on fail)
SaveManager.increment_bounty_progress(bounty_type: String, match_data: Dictionary) -> void
```

`increment_bounty_progress` is called from three sites:
- `SceneManager._on_battle_won()` — `"defeat_enemy_type"` with `{"enemy_type": String}` (both spire and normal paths)
- `WorldScene._on_battle_won()` — `"defeat_in_biome"` with `{"biome_name": String}` using `_current_biome` + `BountyGen.BIOME_NAMES` (infinite world only)
- `WorldScene._handle_interact()` chest open block — `"open_chests"` with `{}`

On each matching increment, emits:
- `GameBus.bounty_progress_changed(bounty_id, progress, count)` — HUD tracker listens
- `GameBus.bounty_completed(bounty_id)` — emitted only when `progress >= count`; HUD shows "(Claim at board)"

### BountyBoardScene (`scenes/ui/BountyBoardScene.tscn`)

Full-screen overlay opened when the player interacts with a BountyBoardNPC in any town. Three bounty rows, each showing description, reward, and a button state:
- **Accept** — available when bounty is in offered_bounties and < 3 active; disabled when cap reached.
- **In Progress N/M** — greyed label while accepted but not complete.
- **Claim** — enabled when `progress >= count` and not yet claimed.
- **Claimed** — greyed text (row hidden in v1 is not done — it shows "Claimed").

Placed in `madrian` (tile 46, 30), `maykalene` (tile 60, 52), `blancogov` (tile 47, 56).

### HUD Tracker (`WorldScene`)

A `VBoxContainer` added to the WorldScene HUD at position (vh×0.01, vh×0.07), below the coin counter. Shows one label per active non-claimed bounty: `"Target N/M"` in yellow, turning green and appending `"(Claim at board)"` when complete. Updated live via `GameBus.bounty_progress_changed` and `GameBus.bounty_completed`.

## Integrations with Other Features

- **Day/night cycle**: `WorldScene._process()` calls `SaveManager.increment_day()` on midnight wrap; bounty rollover piggybacks on that call.
- **GameBus**: `battle_won` (via SceneManager + WorldScene) and chest-open event (WorldScene) drive progress increments. Two new signals: `bounty_progress_changed` and `bounty_completed`.
- **EnemyRegistry**: `get_difficulty_tier(type_id)` drives reward scaling for `defeat_enemy_type` bounties.
- **BiomeDef / InfiniteWorldGen**: `WorldScene._current_biome` (int 0–4) mapped through `BountyGen.BIOME_NAMES` for `defeat_in_biome` tracking.

## Asset Requirements

No new art assets. BountyBoardNPC uses programmatic mesh (brown post + board). BountyBoardScene uses Godot built-in UI controls only.
