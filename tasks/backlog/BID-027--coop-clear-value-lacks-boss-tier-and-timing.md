# BID-027: Co-op boss clear leaderboard value has no boss-tier or timing signal

**Discovered in:** TID-379 (Global leaderboards — GID-102)
**Status:** open

## Context

TID-379 adds a `coop_clears` PvE leaderboard (`SessionState.leaderboards.coop_clears`)
recording the "best" co-op joint-boss-clear result per player. The task notes suggested
ranking by "fastest clear / highest party size / boss tier defeated."

At `WorldScene._on_coop_pve_battle_ended_leaderboard` (the `GameBus.coop_pve_battle_ended`
handler), **no boss tier, scaled difficulty, or clear-time data is available** —
`SceneManager.enter_coop_pve_battle` receives `enemy_data` (which has `is_boss`/
`enemy_type`) and `BattleScene._build_coop_pve_state` computes the party-scaled tier via
`CoopBattleScaling.scale_boss_tier`, but neither value is threaded back out to
`GameBus.coop_pve_battle_ended(did_win: bool)` or cached anywhere WorldScene can read it.
There is also no clear-duration timer anywhere in the co-op PvE battle path.

Because of this gap, TID-379 recorded the leaderboard's "value" as **party size at battle
end** (`multiplayer.get_peers().size() + 1`) — a robust but low-signal proxy: it doesn't
distinguish a party that scraped by from one that curb-stomped a low-tier enemy, and two
different bosses at the same party size produce identical leaderboard values.

## Suggested Fix

Thread a small result payload through `GameBus.coop_pve_battle_ended` (or a new signal)
carrying at least `{boss_tier: int, clear_seconds: float}`, computed in
`BattleScene._finish_coop_pve` from `enemy_data`/`_CoopBattleScaling.scale_boss_tier` and a
turn-start timestamp. `WorldScene._on_coop_pve_battle_ended_leaderboard` can then combine
tier + speed into a richer leaderboard value (e.g. `tier * 10000 - clear_seconds`, or store
multiple fields instead of a single `value` int — would need a `SessionState.leaderboards`
shape change, so bump `CURRENT_SESSION_VERSION` again with a migration if pursued).

## Notes for whoever picks this up

- Keep the existing `coop_clears` entries valid under the old shape, or write a migration.
- `_CoopBattleScaling.scale_boss_tier`/`scale_boss_hp` already exist in
  `game_logic/battle/CoopBattleScaling.gd` — no new scaling math needed, only plumbing.
- Related, not blocking: BID-025 (opponent champion stats host-only) is a similar
  "data exists in BattleScene but doesn't reach WorldScene" class of gap.
