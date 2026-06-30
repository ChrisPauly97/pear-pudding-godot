# BID-029: No HUD entry point to initiate a custom-ante wagered duel

**Category:** missing-ui / dead-code
**Discovered During:** GID-102 / TID-373 (Ranked queue UI + season leaderboard panel)

## Summary

`scenes/world/WorldScene.gd` defines `_request_wager_challenge(ante_coins: int) -> void`
(added in GID-101 / TID-368), which sends `request_battle_wager` to the nearby peer with
a caller-chosen ante. Grepping the entire codebase (`scenes/`, `tests/`) for callers of
`_request_wager_challenge` turns up **zero** — no HUD button, no input action, nothing
wires to it.

The *responder* side of a wagered duel is fully reachable: an incoming
`request_battle_wager` shows `_show_wager_accept_panel` with Accept/Decline, and
`_accept_wager_challenge` correctly enters the wagered duel. But there is currently no
way for a player to be the **initiator** of a wagered duel with a chosen ante amount —
only the plain (unwagered) "Challenge to Battle" button exists for initiating.

## Why it wasn't fixed during TID-373

TID-373 added a "Ranked" toggle next to the existing unwagered challenge button (see
`docs/agent/multiplayer-coop.md` → "Ranked UI & Leaderboard"), but did not touch the
wager flow — combining ranked + wagered was explicitly called out as a separate,
orthogonal follow-up in that task's Plan. Building a proper ante-amount picker (numeric
input or a stepper UI, viewport-relative, with mobile/desktop parity) is a reasonably
sized UI task on its own and was out of scope for a ranked-leaderboard task.

## Suggested fix

Add a small UI affordance (e.g. long-press / secondary button next to "Challenge to
Battle", or a small inline ante stepper) that lets the local player pick an `ante_coins`
value and calls the existing `_request_wager_challenge(ante_coins)`. Make sure it has a
touch target per CLAUDE.md mobile/desktop parity rules. Consider whether it should also
carry the ranked flag (TID-373) once both features need to compose.

## Files

- `scenes/world/WorldScene.gd` — `_request_wager_challenge` (dead code, no callers),
  `_ensure_challenge_button` (where the new affordance would naturally live next to
  `_challenge_btn` / `_ranked_toggle_btn`)
