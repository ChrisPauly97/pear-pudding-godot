# TID-105: Enemy Deck Rarity Scaling by Difficulty Tier

**Goal:** GID-028
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
