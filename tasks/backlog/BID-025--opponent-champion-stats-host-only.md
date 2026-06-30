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
