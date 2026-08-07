# BID-025: Opponent PvP champion stats are recorded host-only

**Category:** design-inconsistency
**Discovered During:** GID-102 / TID-370 (PvP rating model)

## Summary

`WorldScene._on_pvp_battle_ended_coop` updates the **champion record**
(`pvp_wins` / `pvp_losses` / `pvp_streak` / `pvp_best_streak`) only for the host's own
session character (`MpProfile.get_token()`), via the TID-368 logic. The opponent (the
client combatant) never has its champion stats updated — the client runs the same hook
but the whole block is gated on `NetworkManager.is_host()`, so a non-host combatant
records nothing.

This means in a listen-server duel only the host's win/loss/streak ever change; in the
derived leaderboard (`SessionState.get_leaderboard`, added in TID-370) every non-host
member shows `wins = losses = streak = 0` even after playing many duels.

## Why it wasn't fixed in TID-370

TID-370 is scoped to the **rating** (`pvp_rating` / `pvp_games`), which it *does* update
for **both** combatants on the authority (`_update_pvp_ratings`). Extending the same
both-records treatment to the champion win/loss/streak fields is a change to TID-368
behaviour and was kept out of scope to avoid creep.

## Suggested fix

In `_update_pvp_ratings` (or a sibling helper on the host authority), also increment the
opponent's `pvp_losses`/`pvp_wins` and update `pvp_streak`/`pvp_best_streak` symmetrically
to the host's, so both champion records and the leaderboard's win/loss columns are
coherent. The host already owns both records, so no extra RPC is needed. Add a
`test_session_state` / smoke assertion that a duel updates both members' champion stats.

## Files

- `scenes/world/WorldScene.gd` — `_on_pvp_battle_ended_coop` / `_update_pvp_ratings`

## Resolution

Fixed opportunistically alongside BID-027/BID-031.

**Note on file location:** the handlers live in `scenes/world/coop/CoopPvP.gd`
(a WorldScene child module — see CLAUDE.md "Scene Modules"), not directly in
`scenes/world/WorldScene.gd` as this file's "Files" section says; the module
split happened after this BID was filed. `_on_pvp_battle_ended_coop` and
`_update_pvp_ratings` are exactly where the summary describes, just one level
down.

Extracted a new `_apply_champion_result(st, token, won)` helper from the
win/loss/streak block that previously only ran for the host's own token, and
call it for **both** combatants in `_on_pvp_battle_ended_coop`:

```gdscript
_apply_champion_result(st, token, did_win)
var opp_peer: int = _world._pvp_ante_peer1
if opp_peer > 0:
    var opp_token: String = str(_world._session_token_by_peer.get(opp_peer, ""))
    if opp_token != "" and opp_token != token:
        _apply_champion_result(st, opp_token, not did_win)
SessionStore.mark_dirty()
```

This reuses the same `_pvp_ante_peer1` / `_session_token_by_peer` opponent-token
resolution `_update_pvp_ratings` already uses for the ranked-rating update right
below it — no new RPC, no new state to track. Unlike the rating update, the
champion win/loss/streak update is **not** gated on `_pvp_ranked`: TID-368's
original champion-record block already ran unconditionally for the host, so the
opponent side stays symmetric with that (every casual duel, not just ranked
ones, now updates both combatants).

Added `tests/unit/test_coop_pvp_champion_record.gd` — 6 unit tests calling
`_apply_champion_result` directly on an untree'd `CoopPvP` node (the helper only
touches its `st`/`token`/`won` arguments, never `_world`, so no network/session
scaffolding is needed). Covers: win increments wins+streak, loss increments
losses and resets streak without lowering `pvp_best_streak`, the streak/best-streak
high-water-mark interaction across a win-win-loss-win sequence, an unknown token
being a no-op, and — the BID's core regression guard — a single duel result
applied to both a winner and a loser token leaves both records independently
correct.

No deviation from the suggested fix; `test_session_state` itself wasn't touched
since `_apply_champion_result` isn't a `SessionState` method (it operates on a
`SessionState` instance passed in), so a new dedicated unit test file was more
natural than adding to that suite.
