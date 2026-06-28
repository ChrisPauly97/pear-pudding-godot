# TID-367: Spectate a duel

**Goal:** GID-101
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
