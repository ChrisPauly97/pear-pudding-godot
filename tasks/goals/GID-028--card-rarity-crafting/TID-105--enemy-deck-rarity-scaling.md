# TID-105: Enemy Deck Rarity Scaling by Difficulty Tier

**Goal:** GID-028
**Type:** agent
**Status:** done
**Depends On:** TID-097, TID-099

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Harder enemies should field higher-rarity card copies in their decks — a Tier 4 elite's Skeleton hits harder than a Tier 1 basic's Skeleton. This task wires the enemy's `difficulty_tier` field (added in TID-099) into the battle card loading pipeline so that `CardInstance` objects created for enemy PlayerState use stat rolls from the appropriate rarity tier's range rather than always using base stats.

## Research Notes

**`EnemyData.difficulty_tier: int`** — added in TID-099 (1–4). Existing enemies will default to 1 if the `.tres` wasn't updated; update them all here.

**Where enemy deck is loaded**: `PlayerState` or `BattleScene` builds the enemy's draw pile by calling `CardRegistry.get_template(id)` for each card ID in `EnemyRegistry.get_deck(type_id)`. Trace the call path:
- `BattleScene.gd` — find where `PlayerState[1]` (the AI) is populated with its deck
- `CardInstance.from_template(tmpl: Dictionary)` — creates the instance

**Change needed**: before calling `CardInstance.from_template()`, apply rarity-scaled stats for the enemy's tier. Use a new helper:

```gdscript
# In CardDropUtil (TID-099)
static func enemy_card_stats(template_id: String, difficulty_tier: int) -> Dictionary:
    # Map tier to rarity: 1=common, 2=rare, 3=epic, 4=legendary (cap at what the card supports)
    var tier_rarity := ["common", "rare", "epic", "legendary"][clampi(difficulty_tier - 1, 0, 3)]
    return roll_stats(template_id, tier_rarity)
```

The returned dict has `{attack, health, cost}`. Override the template dict's values before constructing `CardInstance`:
```gdscript
var tmpl: Dictionary = CardRegistry.get_template(card_id)
var scaled := CardDropUtil.enemy_card_stats(card_id, enemy_tier)
tmpl["attack"] = scaled["attack"]
tmpl["health"] = scaled["health"]
# cost intentionally NOT scaled — enemy mana is still fixed, cost scaling would break AI
var inst := CardInstance.from_template(tmpl)
```

**Important**: do NOT scale cost. The AI's mana is predictable (turn N = N mana, cap 10). If costs were randomised, `BasicAI` might be unable to play anything on early turns.

**`BasicAI`** (`game_logic/battle/` — find the file): should not require changes if cost is kept at template base.

**EnemyData `.tres` updates**: add `difficulty_tier` field to all existing enemy data files:
- `undead_basic.tres` → tier 1
- `undead_horde.tres` → tier 2
- `ghoul_pack.tres` → tier 2
- `undead_elite.tres` → tier 3
- Boss enemies → tier 4

**Player deck**: player cards continue to use their per-instance rolled stats from TID-098 — no change needed here.

**Tests**: if `tests/` has any battle tests that assert specific enemy card stats, they will need to be updated. Audit existing tests for hardcoded attack/health expectations on enemy minions.

## Plan

1. Add `enemy_card_stats(template_id, difficulty_tier)` to `CardDropUtil` — maps tier 1–4 to rarity then delegates to `roll_stats()`.
2. Add optional `difficulty_tier: int = 0` param to `PlayerState.build_deck()` — when > 0, duplicates the template dict and overrides `attack`/`health` with tier-scaled values (cost kept at base).
3. In `BattleScene`, derive `_enemy_tier` from `EnemyRegistry.get_difficulty_tier()` (boss = 4) and pass to `build_deck()` for both the initial enemy deck and the phase 2 deck swap.

## Changes Made

- **`game_logic/CardDropUtil.gd`**: Added `enemy_card_stats(template_id, difficulty_tier)` — maps tier to rarity (`common/rare/epic/legendary`) and returns `roll_stats()` output.
- **`game_logic/battle/PlayerState.gd`**: `build_deck()` gained optional `difficulty_tier: int = 0`; when positive, scales each card's attack/health via `CardDropUtil.enemy_card_stats()` before `CardInstance.from_template()`. Cost intentionally not scaled (would break AI mana).
- **`scenes/battle/BattleScene.gd`**: Enemy deck loading now computes `_enemy_tier` from `EnemyRegistry.get_difficulty_tier()` (boss = 4) and passes it to `build_deck()`. Phase 2 deck swap also passes the tier.

## Documentation Updates

No new agent docs needed — extends the enemies-and-npcs.md coverage.
