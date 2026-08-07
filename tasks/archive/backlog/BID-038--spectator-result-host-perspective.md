# BID-038: Spectators see the duel result from the host's perspective

**Category:** code-smell
**Discovered During:** GID-104 / TID-387 (pre-existing from TID-367)

Spectators render `BattleScene` with `_local_player_idx = 0` (host perspective),
so the result overlay says "Victory!/Defeated" as if the spectator were the
host — which now reads oddly next to the neutral wager settlement note. A
neutral "Player X wins" variant of `BattleResultUI.show_pvp_result` for
`_pvp_spectating` would be cleaner. Tournament auto-spectate (TID-386) shows
the same host-perspective result.

## Resolution

Added a `spectating: bool = false` parameter to `BattleResultUI.show_pvp_result`.
When true, it renders a neutral title/subtitle and background instead of
"Victory!"/"Defeated" in green/red:

- Title: **"Bottom Player Wins!"** / **"Top Player Wins!"** — reused the exact
  Bottom/Top seating language the spectator bet panel already uses
  (`BattleNet._wager_side_name`: side A = bottom = `players[0]`, side B = top =
  `players[1]`), rather than inventing new vocabulary or trying to thread real
  display names through (a spectator's `BattleScene` has no combatant-name wiring
  today — `_pvp_idx_to_token` is only populated on the dedicated-server referee
  path, not `enter_pvp_spectator()` — so "Player X wins" would have needed a new
  name-plumbing addition; Bottom/Top was already correct, already visible on the
  bet panel the spectator just used, and needed zero new plumbing).
- Subtitle: neutral "The duel has ended." instead of "You bested your
  rival!"/"Your rival prevailed."
- Background: a neutral dark-blue tint instead of green/red — there's no "us" to
  color-code a win/loss for.

`BattleNet._finish_pvp` now passes `_battle._pvp_spectating` straight through as
the new parameter. Since both live spectating (`enter_pvp_spectator()` via the
Spectate button) and tournament auto-spectate (`notify_tournament_spectate` →
the same `enter_pvp_spectator()`, GID-104/TID-386) go through the one
`enter_pvp_spectator()` entry point and set the same `_pvp_spectating = true`
flag, this fix covers both call sites the BID names with a single change — no
tournament-specific code needed.

`coins_delta` (the wager amount line) and `wager_note` (the spectator's own bet
settlement line) are untouched and still render normally under the neutral
title — a spectator's own bet result is still exactly about them, unlike the
duel outcome itself.

Verified: `godot --headless --editor --quit` parse-clean; full test suite
(`tests/runner.gd`) 2366 passed / 0 failed; `tests/net_pvp_smoke.gd`,
`tests/net_pvp_client_smoke.gd`, `tests/net_pvp_dedicated_smoke.gd` all PASS
(no existing test called `show_pvp_result` directly, so no signature-change
fallout).
