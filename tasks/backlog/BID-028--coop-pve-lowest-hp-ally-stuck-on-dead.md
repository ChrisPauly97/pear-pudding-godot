# BID-028: `_get_lowest_hp_ally` can get stuck targeting a dead ally (not fixed)

**Category:** code-smell
**Discovered During:** GID-102 / TID-371 (2v2 team duels) — while writing the parallel
`_get_lowest_hp_enemy_team_member` for team battles and comparing against the existing
co-op-PvE boss-targeting helper.

## Summary

`GameState._get_lowest_hp_ally()` (GID-099, used by `opponent()` on the boss's turn)
initializes `result = players[0]` / `lowest = players[0].hero.health` unconditionally,
then only overrides when `p.hero.is_alive() and p.hero.health < lowest`. If `players[0]`
(ally-0) is dead, `lowest` starts at `0`, and no other ally's health can ever be `< 0`
(health is clamped at 0), so the loop can never select a different ally — the boss keeps
"targeting" the dead ally-0 for the rest of the battle even while other allies are alive,
instead of retargeting to the lowest-HP **alive** ally.

This is the same class of bug as the one fixed for team battles (where
`_get_lowest_hp_enemy_team_member` was written to correctly prefer any alive member over
a dead one — see its docstring), but `_get_lowest_hp_ally` itself was left unchanged
since fixing it touches co-op-PvE behavior outside this task's scope.

## Suggested fix

Mirror `_get_lowest_hp_enemy_team_member`'s logic: initialize from the first ally
unconditionally, but only let a *later* candidate become `result` if it's alive and
(the current `result` is dead OR it has lower HP). Add a `test_coop_battle_state.gd` case
constructing a co-op battle with ally-0 dead and asserting the boss's `opponent()` is a
different, alive ally.

## Files

- `game_logic/battle/GameState.gd` — `_get_lowest_hp_ally`
