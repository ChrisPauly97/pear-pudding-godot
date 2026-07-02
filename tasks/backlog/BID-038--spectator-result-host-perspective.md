# BID-038: Spectators see the duel result from the host's perspective

**Category:** code-smell
**Discovered During:** GID-104 / TID-387 (pre-existing from TID-367)

Spectators render `BattleScene` with `_local_player_idx = 0` (host perspective),
so the result overlay says "Victory!/Defeated" as if the spectator were the
host — which now reads oddly next to the neutral wager settlement note. A
neutral "Player X wins" variant of `BattleResultUI.show_pvp_result` for
`_pvp_spectating` would be cleaner. Tournament auto-spectate (TID-386) shows
the same host-perspective result.
