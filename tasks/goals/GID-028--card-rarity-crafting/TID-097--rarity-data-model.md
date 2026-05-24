# TID-097: Rarity Data Model — Global Multipliers & Variance, CardData Flags

**Goal:** GID-028
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cards currently have flat stats. This task introduces rarity tiers by storing a global config of (stat multiplier, variance %) per rarity tier rather than per-card ranges. A card's stats at a given rarity are derived entirely from its base stats and the global tier config — no per-card range data is needed. CardData only gains two new flags: `can_craft` and `is_unique`.

## Research Notes

**Design principle**: no per-card per-rarity fields. Every card's rarity stats are computed at roll time:

```
rolled_stat = round(base_stat * rarity_multiplier * uniform(1 - variance, 1 + variance))
```

`base_stat` is the existing `attack` / `health` on `CardData`. Cost is never randomised — it stays at the base value regardless of rarity.

**Global rarity config** — add to `autoloads/IsoConst.gd` as a typed Dictionary constant:

```gdscript
const RARITY_CONFIG: Dictionary = {
    "common":    {"multiplier": 1.0, "variance": 0.10},
    "rare":      {"multiplier": 1.3, "variance": 0.08},
    "epic":      {"multiplier": 1.7, "variance": 0.06},
    "legendary": {"multiplier": 2.4, "variance": 0.05},
}
```

These values mean:
- A Ghost (base ATK 2, HP 3) at **rare** rolls ATK in [2, 3] and HP in [2, 3]
- At **legendary** it rolls ATK in [4, 5] and HP in [5, 6]
- All cards in the game automatically gain rarity depth with zero per-card data

**`CardData`** (`data/CardData.gd`) — only two new fields:

```gdscript
@export var can_craft: bool = true
@export var is_unique: bool = false
```

No other changes to CardData. No new sub-resources. No `.tres` edits for stat ranges.

**Rarity tiers**: `"common"`, `"rare"`, `"epic"`, `"legendary"`. Unique is a flag (`is_unique = true`), not a separate tier. Unique cards are always legendary-tier for stat purposes.

**Legendary-only cards**: legendary cards have no common/rare/epic versions — the drop system (TID-099) simply never rolls lower tiers for them. No flag is needed on CardData for this; the drop pool controls it.

**Which cards get `can_craft = false`**: the 5 existing achievement-gated legendaries (`ancient_guardian`, `void_wyrm`, `iron_revenant`, `phoenix_rise`, `time_warp`) and any unique cards. All other cards default `can_craft = true` (no `.tres` edit needed since `true` is the default).

**Files to edit**:
- `autoloads/IsoConst.gd` — add `RARITY_CONFIG` constant
- `data/CardData.gd` — add `can_craft` and `is_unique` fields
- `data/cards/ancient_guardian.tres`, `void_wyrm.tres`, `iron_revenant.tres`, `phoenix_rise.tres`, `time_warp.tres` — set `can_craft = false`

No new files, no `.uid` sidecars needed.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
