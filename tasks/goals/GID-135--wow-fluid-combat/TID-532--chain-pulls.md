# TID-532: Chain Pulls — Keep Momentum Between Fights

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-528, TID-531

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With fights in-world, nearby enemies can join or immediately follow, like pulling multiple mobs in WoW.

## Research Notes

- Enemy AI and engage: `scenes/world/EnemyNPC.gd` (wander/track/engage), `GameBus.enemy_engaged`,
  `SceneManager._on_enemy_engaged`. Finders `_find_nearby_*` stay on WorldScene (test_interact_priority).
- Options: (a) an aggro'd enemy within radius joins as a reinforcement wave mid-battle (adds to its board);
  (b) back-to-back: on victory, a tracking enemy in range engages instantly with no camera reset. Start with (b).
- Keep per-instance enemy ids unique (see Spire learnings) and `defeated_enemies` semantics.
- Interacts with TID-541 (pack encounters).

- Option (a) "a nearby enemy joins mid-battle" shipped as TID-551 (adds). Remaining here: (b) back-to-back
  engages with no camera reset.

## Plan

Option (b), back-to-back pulls (option (a) shipped as TID-551): after a won in-place fight,
the nearest pursuing EnemyNPC within 9 units engages immediately; the camera stays zoomed
between the fights.

## Changes Made

- `EnemyNPC`: `GROUP` (`world_enemy`), `is_pursuing()`.
- `BattleVictory`: `_chain_candidate()`, `_start_chain()` (+ give-up release of the zoom).
- `SceneManager`: `hold_fight_zoom`; `_freeze_world` / `_thaw_world` honour it.
- `tests/in_world_battle_smoke.gd`: `_check_chain_pull` (verified to fail with the radius at 0).

## Documentation Updates

- `combat-model.md` → Chain pulls.
