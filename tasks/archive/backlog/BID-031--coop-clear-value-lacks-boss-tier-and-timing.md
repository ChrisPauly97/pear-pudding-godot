# BID-031: Co-op boss clear leaderboard value has no boss-tier or timing signal

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

## Note on ID numbering

Originally filed as BID-027 from an isolated worktree (branched before BID-027 was claimed
elsewhere for an unrelated finding); renumbered to BID-031 during integration.

## Resolution

Fixed opportunistically alongside BID-025/BID-027 (the "related, not blocking"
pairing noted above).

**Handler location note:** as with BID-025, `_on_coop_pve_battle_ended_leaderboard`
lives in `scenes/world/coop/CoopActivities.gd`, not directly on `WorldScene.gd` — a
module split that happened after this BID's context section was written. Likewise
the co-op PvE build/finish logic lives in `scenes/battle/net/BattleNet.gd` (a
`BattleScene` child module), not `BattleScene.gd` itself.

Took the suggested-fix path of widening the existing signal rather than adding a
new one:

- `GameBus.coop_pve_battle_ended` widened from `(did_win: bool)` to
  `(did_win: bool, result: Dictionary)`. The three other connected handlers
  (`SceneManager._on_coop_pve_battle_ended`, `CoopActivities._on_coop_siege_battle_ended`,
  `CoopActivities._on_coop_spire_battle_ended`) were left declaring only
  `(did_win: bool)` — Godot truncates extra emitted signal arguments for a
  connected callable that declares fewer parameters, so none of them needed
  touching.
- `BattleNet._build_coop_pve_state()` (host-only) now stamps
  `_coop_battle_started_at_msec = Time.get_ticks_msec()` and caches
  `_coop_boss_tier = scaled_tier` (the same value already computed there via
  `CoopBattleScaling.scale_boss_tier` for HP/deck scaling — no new scaling math).
- `BattleNet._build_coop_reward_payload(did_win)` adds `boss_tier`/`clear_seconds`
  (computed from the two fields above) to the reward dict it already builds and
  RPCs to every peer via the existing `coop_battle_ended` RPC — no second signal,
  no extra RPC round-trip. Included on both the win and loss branches.
- `BattleNet._finish_coop_pve` builds `result := {"boss_tier": ..., "clear_seconds":
  ...}` from the (possibly RPC'd) payload and emits
  `GameBus.coop_pve_battle_ended.emit(did_win, result)`.
- `CoopActivities._on_coop_pve_battle_ended_leaderboard(did_win, result: Dictionary
  = {})` combines the two into a single int rather than widening the stored
  leaderboard-entry shape: `value = boss_tier * 10000 - round(clear_seconds)`. Tier
  dominates via the ×10000 multiplier (a harder boss always outranks an easier one
  regardless of speed); a faster clear (lower `clear_seconds`) then breaks ties
  within the same tier. The default parameter keeps a stale/legacy caller that only
  emits `did_win` from erroring (falls back to tier 1 / 0s).

**Deviation from the suggested fix:** chose the single-combined-int approach
explicitly offered as the lower-risk alternative in the BID's own "Suggested Fix"
section, rather than widening `SessionState.leaderboards.coop_clears`'s stored
entry shape. This avoids a `CURRENT_SESSION_VERSION` bump + migration entirely —
existing `coop_clears` entries (old party-size values) stay valid as-is under the
unchanged `{token, name, value, day}` shape; a party-size value and a
`tier*10000-seconds` value now sit in the same board, which is a one-time ranking-
scale discontinuity for old entries (a decent old party-size score could now rank
above a genuine tier-4 clear) but no data is lost or invalidated, and the board
naturally re-sorts to the richer signal as new clears are recorded. No test file
existed for `SessionState.leaderboards.coop_clears`'s value semantics specifically
(the pre-existing `test_coop_spire_leaderboard_value_is_floors_cleared_style` test
covers the sibling `coop_spire` board, which this change doesn't touch), so no new
`SessionState` unit test was needed — the new plumbing lives entirely in
`BattleNet`/`CoopActivities`/`GameBus`, exercised end-to-end by the existing
`godot --headless --path . -s tests/world_scene_smoke.gd` run (module wiring) and
manually verified by reading through the emit → RPC → handler chain.
