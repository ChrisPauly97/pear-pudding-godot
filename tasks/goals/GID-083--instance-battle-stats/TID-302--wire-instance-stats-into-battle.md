# TID-302: Wire get_deck_instances() into BattleScene and PlayerState

**Goal:** GID-083
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`BattleScene._ready()` calls `SaveManager.get_deck_template_ids()` which returns plain `Array[String]` template IDs, discarding instance UIDs. `PlayerState.build_deck(ids)` then fetches base stats from `CardRegistry.get_template(cid)`. Per-instance rolled stats are never used.

`SaveManager.get_deck_instances()` returns `Array[Dictionary]` with keys `{template_id, uid, rarity, attack, health, cost}` but has zero callers.

## Plan

GID-060 (veterancy) already implemented the core wiring:
- `PlayerState.build_deck_from_instances()` applies per-instance rolled stats + rank bonuses
- `BattleScene._ready()` already calls it at line 166 (normal player deck path)

Remaining gap: `build_deck_from_instances` uses `CardRegistry.get_template(tid)` instead of `get_template_for_face(tid, face)`, so dual-faced cards always resolve as the light face regardless of player alignment.

Fix:
1. Add `var face: String = "dark" if CardRegistry.is_dark_aligned() else "light"` in `build_deck_from_instances`
2. Replace `CardRegistry.get_template(tid)` with `CardRegistry.get_template_for_face(tid, face)`
3. Verify all acceptance criteria are met
4. Run tests headless

## Changes Made

- `game_logic/battle/PlayerState.gd`: `build_deck_from_instances()` now calls `CardRegistry.get_template_for_face(tid, face)` (face derived from `CardRegistry.is_dark_aligned()`) instead of `CardRegistry.get_template(tid)`, so dual-faced cards resolve to the correct face matching the player's corruption/redemption alignment. Per-instance rolled stats and veterancy rank bonuses continue to be applied on top of the resolved template.

  Core wiring (`BattleScene` calling `build_deck_from_instances(get_deck_instances())` and `PlayerState.build_deck_from_instances` applying rolled stats) was already in place from GID-060. This task closes out the remaining gap.

- All 1129 tests pass headless; 12 pre-existing skips (missing imported texture dependencies in headless mode) and 1 pre-existing FAIL (DungeonGen `new()` call) are unaffected.

## Documentation Updates

No agent doc changes needed; `docs/agent/battle-system.md` already documents the `build_deck_from_instances` path under "Veterancy Kill Attribution".
