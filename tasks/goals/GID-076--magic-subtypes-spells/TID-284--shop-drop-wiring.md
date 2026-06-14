# TID-284: Shop/Drop Pool Wiring + Test Count Fix

**Goal:** GID-076
**Type:** agent
**Status:** pending
**Depends On:** TID-280, TID-281, TID-282, TID-283

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New spell cards need to appear in the shop and be earnable from enemy battles. The shop scans `CardRegistry` automatically, so no shop code changes are needed — but enemy `EnemyData` drop pools need the new spells added. The test card count assertion also needs updating (BID-007).

## Research Notes

### Shop
`ShopScene` pulls cards via `CardRegistry.get_all_ids()` which scans `data/cards/` — no code change needed. New `.tres` files are automatically available in the shop once created.

### Drop pools
Enemy drop pools are in `data/enemies/*.tres`. Each `EnemyData` has a `drop_pool: Array[String]` field. Distribute the 40 new spells across enemy types by magic affinity:

| Spells | Add to enemy drop pools |
|---|---|
| Ember (light) | `ember_mage`, `undead_basic`, `undead_elite` (or equivalent light-aligned enemies) |
| Dawn (light) | `dawn_priest`, `undead_basic`, `undead_elite` |
| Dusk (dark) | `dusk_summoner`, `undead_horde`, `undead_elite` |
| Ash (dark) | `ash_necromancer`, `ghoul_pack`, `undead_elite` |

**Check actual enemy IDs** before editing: `ls data/enemies/` and `grep 'id =' data/enemies/*.tres`.
Add 3–5 thematically matching new spell IDs to each relevant enemy's drop_pool.

### Test fix (BID-007)
File: `tests/unit/test_card_registry.gd`
Find the assertion that checks card count (currently expects 40, actual count is 46 before this task). After adding 40 new cards, the count will be 86. Update the assertion to match.

Check exact assertion: `grep -n 'assert\|count\|size' tests/unit/test_card_registry.gd`

### SkillRegistry preload (if needed)
If `CardRegistry` uses explicit preloads (not a scan), all 40 new `.tres` files must be added as `const` preloads. Check `autoloads/CardRegistry.gd` to confirm whether it uses `DirAccess` scan or preloads.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
