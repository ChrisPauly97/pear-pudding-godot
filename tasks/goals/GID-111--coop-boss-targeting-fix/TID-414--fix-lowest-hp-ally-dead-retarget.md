# TID-414: Fix `_get_lowest_hp_ally` Dead-Ally Retargeting

**Goal:** GID-111
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`game_logic/battle/GameState.gd::_get_lowest_hp_ally()` drives who the co-op boss
attacks on its turn (`opponent()`, GID-099). It initializes `result = players[0]`
and `lowest = players[0].hero.health` unconditionally, then only overrides when
`p.hero.is_alive() and p.hero.health < lowest`. If `players[0]` is dead, `lowest`
starts at `0`; since health is clamped at 0, no alive ally's health can ever be
`< 0`, so `result` never changes — the boss keeps "targeting" the dead ally-0 for
the rest of the battle instead of retargeting to the lowest-HP alive ally. Logged
as BID-028 during GID-102/TID-371, where the analogous team-battle helper
(`_get_lowest_hp_enemy_team_member`) was written correctly (prefers any alive
candidate over a dead `result`) but the co-op-PvE helper was left as-is, out of
scope for that task.

## Research Notes

- Buggy code: `game_logic/battle/GameState.gd:121-131`.
- Correct sibling pattern to mirror: `game_logic/battle/GameState.gd:133-152`
  (`_get_lowest_hp_enemy_team_member`) — iterate all candidates; take the first as
  `result` unconditionally to seed a baseline, then let any later candidate
  override `result` if it's alive AND (`result` is currently dead OR it has lower
  HP than `lowest`).
- Test file: `tests/unit/test_coop_battle_state.gd`, section "opponent() during
  ally vs boss turns" (around line 132). Existing case `test_boss_targets_lowest_hp_ally`
  (line 149) is the pattern to follow: build `_coop(2)`, set HP, `end_turn()` twice
  to reach the boss's turn, assert on `gs.opponent().player_id`.
- Doc reference to update: `docs/agent/multiplayer-coop.md` line ~1850,
  "Boss turn → returns the alive ally with the lowest hero HP" — already correct
  in *intent*, just needs a note that dead allies are correctly skipped now (the
  doc describes the intended behavior, which the code didn't previously satisfy).
- No `class_name`/preload concerns — `GameState.gd` is already preloaded via
  `const GameState = preload(...)` in the test file.

## Plan

1. Rewrite `_get_lowest_hp_ally()` to mirror `_get_lowest_hp_enemy_team_member`'s
   dead-vs-alive preference logic: seed `result`/`lowest` from `players[0]`
   unconditionally (so there's always a fallback if the whole party is dead — same
   fallback contract as the team-battle sibling), then override on any later ally
   that is alive AND (`result` is dead OR strictly lower HP).
2. Add a regression test to `tests/unit/test_coop_battle_state.gd`:
   `test_boss_retargets_away_from_dead_ally` — `_coop(2)`, kill ally 0
   (`health = 0`), leave ally 1 alive, advance to the boss's turn, assert
   `gs.opponent().player_id == gs.players[1].player_id`.
3. Run the full test suite headless (`godot --headless --path . -s tests/runner.gd`)
   and a headless editor import to confirm no regressions/parse errors. If the
   Godot binary is unavailable in this sandbox, note that explicitly instead of
   claiming verification.
   - **Result:** Godot is not installed in this sandbox, and the release download
     (`github.com/godotengine/godot/releases/...`) is blocked by the egress proxy
     (403 — organization policy denial, not retried per proxy guidance). The fix
     was verified by manual trace instead: it is a direct structural port of the
     already-tested `_get_lowest_hp_enemy_team_member` (lines 137-152, covered by
     `tests/unit/test_team_battle_state.gd`), and `HeroState.take_damage`/
     `CardInstance.take_damage` both clamp health via `max(0, ...)`, confirming the
     original bug's precondition (`lowest` floors at `0`, so no alive ally's HP
     can ever satisfy `< lowest` once ally 0 is dead). Traced both test cases
     (`test_boss_targets_lowest_hp_ally`, new
     `test_boss_retargets_away_from_dead_ally`) by hand against the new loop body
     and confirmed correct output. **Not run headless** — flagged per project
     convention (see GID-108/GID-110/etc. notes in `tasks/index.md`).
4. Update `docs/agent/multiplayer-coop.md`'s boss-targeting bullet to note the
   dead-ally-skip guarantee explicitly.
5. Move `tasks/backlog/BID-028--coop-pve-lowest-hp-ally-stuck-on-dead.md` to
   `tasks/archive/backlog/`, update its `tasks/index.md` row to Resolved Backlog.

## Changes Made

- `game_logic/battle/GameState.gd`: rewrote `_get_lowest_hp_ally()` to prefer any
  alive ally over a dead `result`, matching `_get_lowest_hp_enemy_team_member`'s
  logic. Previously, if `players[0]` was dead, the loop's `lowest = 0` floor meant
  no other ally could ever be selected (health is clamped at 0), so the boss stayed
  locked onto the dead ally for the rest of the battle.
- `tests/unit/test_coop_battle_state.gd`: added
  `test_boss_retargets_away_from_dead_ally` covering the fixed case (ally 0 dead,
  ally 1 alive — boss must target ally 1).
- `docs/agent/multiplayer-coop.md`: clarified the boss-targeting bullet to state
  dead allies are never targeted while any ally remains alive.
- `tasks/backlog/BID-028--coop-pve-lowest-hp-ally-stuck-on-dead.md` moved to
  `tasks/archive/backlog/`; `tasks/index.md` updated.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — boss-targeting bullet under the GID-099
  co-op joint battle model section.
