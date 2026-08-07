# BID-036: Spectator wager settlement is house-banked, not parimutuel

**Category:** design-gap
**Discovered During:** GID-104 / TID-387

`WagerSync.settle()` pays every winning bettor 1:1 (2× stake credited since
stakes are pre-debited). If winning stakes exceed losing stakes the session
"mints" coins out of thin air; otherwise it absorbs the surplus. Acceptable for
a coins-only economy, but a pool-based (parimutuel) model would be
economy-neutral. Related deliberate choice worth revisiting at the same time:
grace-expired combatant forfeits refund all bets rather than paying out (anti-
grief: a losing combatant could otherwise burn bettors by yanking the cable),
which means a genuine walkover pays nobody.

## Resolution

Rewrote `WagerSync.settle()` (`game_logic/net/WagerSync.gd`) to a parimutuel model:

- On a clean win, the whole **losing-side pool** is split among winners in
  proportion to their own stake — a winner is credited their stake back plus
  `floor(their_stake * losing_pool / winning_pool)`; a loser is credited an
  explicit `0` (kept in the returned dict, not just absent, matching the previous
  contract every caller/test relied on).
- **Coin-neutral by construction**: total credited can never exceed total staked,
  because losers contribute `0` and every winner's extra share is a `floor()`'d
  fraction of the losing pool. The only deviation from exact conservation is
  "breakage" — a few coins left uncredited when a share doesn't divide evenly
  (documented in the function's docstring), same as a real-world parimutuel
  pool. It never mints, and it only ever *under*-pays by a rounding remainder,
  never over-pays.
- **Edge case**: if nobody backed the side that actually won (every bettor picked
  the loser, or there were no bets at all on the winning side), there is no
  winner to hand the losing pool to — everyone is refunded their own stake,
  same treatment as `OUTCOME_DRAW`/`OUTCOME_ABANDONED`. This is itself a small
  judgment call: the alternative (let those stakes simply vanish, since "the
  house" has no account to receive them) would also be coin-neutral, but
  refunding is the one option with **zero** economic side effect in that corner
  case, so it was preferred.
- A sole winner with no opposing bets now nets `0` profit (just their stake
  back) instead of a flat double-up, since there is no genuine opposing pool to
  win from — this is a real behavioral change from the old 1:1 model, called out
  explicitly in the updated unit tests.

**Grace-expiry-refunds-all judgment call (the BID's secondary question):** left
as-is, refunding all bets on a reconnect-grace-timeout forfeit rather than paying
out winners of the other combatant's bets. Reasoning: `_on_pvp_reconnect_grace_expired`
cannot cleanly tell a genuine dropped connection apart from a losing combatant
deliberately pulling the cable to grief their own bettors — that anti-grief
property is the entire reason `OUTCOME_ABANDONED` exists. Refund-all is the only
option that can never be exploited to grief a bettor; the cost is that a true,
non-adversarial walkover under-pays the spectators who backed the player who
would have won. Per the task's own guidance this distinction isn't safe to make
cleanly, and the parimutuel payout math above (not this call) was the actual
core ask — so it was kept simple and unchanged.

Added unit test coverage for the new payout math in
`tests/unit/test_wager_sync.gd`: sole-winner-no-losers, multi-winner
proportional splits, rounding/"breakage" never exceeding total staked, and the
no-winning-side-bets refund-all edge case. Updated the pre-existing settle
tests (`test_settle_loser_credited_zero`, `test_settle_mixed_sides`,
`test_settle_skips_garbage_bet_entries`, `test_settle_total_credit_conservation_on_clean_win`,
`test_full_flow_win_and_loss_net_effect`) to the new expected values, since
several of them encoded the old flat-1:1 assumption directly in their
assertions.

Verified: `godot --headless --editor --quit` parse-clean; full test suite
(`tests/runner.gd`) 2366 passed / 0 failed; `tests/net_pvp_reconnect_smoke.gd`
and `tests/net_pvp_dedicated_smoke.gd` PASS (grace-window/reconnect paths that
call into settlement untouched in behavior, just in payout math).
