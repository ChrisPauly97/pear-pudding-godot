# TID-367: Spectate a duel

**Goal:** GID-101
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Let party members **watch** an in-progress PvP duel read-only. Nearly free: the host
already broadcasts full `GameState` mirrors — spectating is fanning those out to extra
peers that render but never input.

## Research Notes

- **PvP mirror (GID-091):** host owns `GameState`, broadcasts `sync_state` over
  `scenes/battle/BattleNetSync.gd` (path `/root/BattleScene/BattleNetSync`). Client renders
  the mirror with `_local_player_idx == 1`. The **dedicated-server referee** path
  (GID-097/TID-353) already renders with `_local_player_idx == -1` and **no UI/input** —
  a spectator is essentially a non-acting peer that *does* render the board.
- **Spectator model:** a new `_local_player_idx == SPECTATOR` (or a `_spectating` flag)
  that renders the full board (pick a perspective — neutral/side-on) but gates **all**
  input (no drag, no end-turn, no targeting). Reuse the referee's "render-without-acting"
  guards as the template, inverted (referee renders nothing; spectator renders the
  player UI read-only).
- **Join/leave:** host fans `sync_state` to registered spectators too; add
  `request_spectate` / `stop_spectate` RPCs. A spectator joining mid-duel uses the same
  `request_sync` retry that clients use for the first mirror.
- **Entry UX:** when a party member is dueling, others see a "Spectate" affordance (HUD
  button / roster action). Returning drops back to the world cleanly (the world is kept
  alive during battles — `_setup_coop`/`_teardown_coop` idempotent).
- **Scope:** spectate PvP duels first; spectating co-op joint battles (GID-099) is a
  natural follow-on but out of scope here unless trivial.
- **Tests:** loopback smoke — a third peer registers as spectator and decodes the host's
  mirror without crashing (mirror `net_pvp_client_smoke.gd`).

## Plan

Fan existing `GameState` mirrors to registered spectator peers. A `_pvp_spectating` flag gates all input; `_spectators: Array[int]` fans mirrors. Host broadcasts `recv_pvp_active` RPC when a duel starts/ends so non-combatants can show/hide the Spectate button.

## Changes Made

- **`scenes/battle/BattleScene.gd`**: `_pvp_spectating: bool`; `_spectators: Array[int]`; `_is_spectator()` returns `_pvp_spectating`; `_can_local_act()` blocks when spectating; `_broadcast_state()` fans to `_spectators`; `_on_spectate_request(sender)` adds sender to `_spectators` and sends current state; `_on_stop_spectate(sender)` removes sender.
- **`scenes/battle/BattleNetSync.gd`**: `request_spectate()` (reliable, client→host) and `stop_spectate()` (reliable, client→host) RPCs.
- **`autoloads/SceneManager.gd`**: `enter_pvp_spectator()` — sets `_pvp_spectating = true`, `_local_player_idx = 0`, transitions to BattleScene.
- **`scenes/world/NetSync.gd`**: `recv_pvp_active(in_battle, peer_a, peer_b)` (reliable, authority→others), `request_spectate_pvp()` (reliable, client→authority).
- **`scenes/world/WorldScene.gd`**: `_on_pvp_active_received` tracks `_pvp_active_peers`; shows/hides "Spectate" HUD button; `_request_spectate()` / `_on_spectate_pvp_requested(sender)` / `_on_spectate_approved()` — three-step spectate entry flow. `_pvp_ended_pending_broadcast` defers clear broadcast until WorldScene re-enters tree after battle.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md`: GID-101 spectate subsection; updated Limitations note (spectating now available).
