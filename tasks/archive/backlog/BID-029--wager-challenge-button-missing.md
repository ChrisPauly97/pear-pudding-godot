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

## Resolution

By the time this was picked up, the challenge/wager surface had already moved out of
`WorldScene.gd` into the `CoopPvP.gd` co-op module (see the "Scene Modules" table in
CLAUDE.md) — `_challenge_btn` / `_ranked_toggle_btn` / `_ensure_challenge_button` /
`_update_challenge_proximity` all live there now, and `_request_wager_challenge` did
not exist yet at all (only the responder side — `_on_battle_wager_requested` /
`_show_wager_accept_panel` / `_accept_wager_challenge` — was present). Added the
missing initiator side in `scenes/world/coop/CoopPvP.gd`:

- **`_wager_btn`** — a new "Wager Duel" secondary action registered via
  `WorldHUD.register_action` into the same `WorldHUD.ZONE_CONTEXT` zone as
  "Challenge to Battle" and the Ranked toggle (that zone is a `VBoxContainer`, so it
  stacks below them). Shown/hidden by proximity in lockstep with the other two via a
  new `_hide_challenge_cluster()` helper (factored out of the three duplicated
  hide-blocks in `_update_challenge_proximity`).
- **`_open_wager_picker()`** — builds a small ante-amount picker (a `_build_prompt`
  panel like the accept panel, per the "Build Widgets Through the Factories" rule):
  a ±10-coin stepper (`_wager_ante_amount`, floored at 5) and a real "Send
  Wager"/"Cancel" button pair. Real tap targets, not a long-press gesture, per the
  mobile/desktop parity rule in CLAUDE.md.
- **`_request_wager_challenge(ante_coins)`** — the actual initiator function the BID
  asked for: validates a target peer is in range, the ante is positive and
  affordable, and the local deck meets `IsoConst.DECK_MIN`, then sends
  `request_battle_wager` (the RPC already existed in `NetSync.gd`, just never had a
  caller). No coins are deducted here — deduction happens on acceptance in the
  existing `_enter_pvp_wagered`, exactly mirroring the accept-side flow, so nothing
  is charged if the peer declines.

**Judgment call:** composing this with the Ranked toggle (TID-373) was explicitly
called out as future follow-up scope in both this BID and the pre-existing
`docs/agent/multiplayer-coop.md` note, so it was left alone — the wager picker sends
an unranked wagered duel only, same as the pre-existing wager-accept flow.

Verified: `godot --headless --editor --quit` parse-clean; full test suite
(`tests/runner.gd`) 2366 passed / 0 failed; `tests/world_scene_smoke.gd` PASS. This
BID added no new RPCs — `request_battle_wager` already existed in `NetSync.gd`; the
fix was purely adding a caller and its UI.
