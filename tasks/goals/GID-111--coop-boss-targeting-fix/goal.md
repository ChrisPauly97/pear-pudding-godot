# GID-111: Co-op Boss Targeting Fix — Dead Ally Retargeting

## Objective

Fix `GameState._get_lowest_hp_ally()` so the co-op boss retargets to an alive ally
instead of getting stuck on a dead one, mirroring the fix already applied to the
team-battle equivalent.

## Context

Logged as BID-028 during GID-102/TID-371. `_get_lowest_hp_ally()` (used by
`opponent()` on the co-op boss's turn, GID-099) initializes `result`/`lowest` from
`players[0]` unconditionally. If ally 0 is dead, `lowest` starts at `0` (health is
clamped at 0), so no other ally's health can ever be `< 0` — the loop never
overrides `result`, and the boss keeps "targeting" the dead ally for the rest of
the battle even while other allies are alive. `_get_lowest_hp_enemy_team_member`
(GID-102, team duels) already implements the correct version of this logic
(prefer any alive candidate over a dead `result`); this goal ports that fix to the
co-op-PvE helper and adds regression coverage.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-414 | Fix `_get_lowest_hp_ally` dead-ally retargeting + test | agent | done | — |

## Acceptance Criteria

- [ ] `_get_lowest_hp_ally()` never returns a dead ally when at least one ally is alive.
- [ ] A unit test constructs a co-op battle with ally-0 dead and asserts the boss's `opponent()` is a different, alive ally.
- [ ] Existing `test_boss_targets_lowest_hp_ally` and all other `test_coop_battle_state.gd` cases still pass.
- [ ] `docs/agent/multiplayer-coop.md` boss-targeting description reflects the corrected behavior.
- [ ] BID-028 moved to resolved backlog.
