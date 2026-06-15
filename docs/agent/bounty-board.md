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
`active_bounties` entries further add `"accepted_at_day": int`, `"progress": int`, `"claimed": bool`.

### Refresh / Rollover

`SaveManager._refresh_bounties()` is called from:
- `increment_day()` — triggers at midnight when the day increments
- `get_offered_bounties()` — called by the board entity (TID-189) to ensure data is current

Rollover logic: if `days_elapsed != bounty_day` or `offered_bounties` is empty, `offered_bounties` is cleared and regenerated for the current day. `active_bounties` are not touched.

### Public API

```gdscript
SaveManager.get_offered_bounties() -> Array[Dictionary]  # auto-refreshes if stale
SaveManager.get_active_bounties() -> Array[Dictionary]
```

Accept, progress, and claim logic are added in TID-189.

## Integrations with Other Features

- **Day/night cycle**: `WorldScene._process()` calls `SaveManager.increment_day()` on midnight wrap; bounty rollover piggybacks on that call.
- **GameBus**: TID-190 wires `battle_won` and `coins_changed` signals to update `active_bounties[*].progress`.
- **EnemyRegistry**: `get_difficulty_tier(type_id)` drives reward scaling for `defeat_enemy_type` bounties.
- **BiomeDef**: biome index (0–4) drives reward scaling for `defeat_in_biome` bounties.

## Asset Requirements

No new assets needed for TID-188. TID-189 will add a bounty board entity (sprite) and UI scene.
