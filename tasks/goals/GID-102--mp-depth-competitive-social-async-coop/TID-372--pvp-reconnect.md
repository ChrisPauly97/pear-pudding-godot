# TID-372: Reconnect into in-progress PvP battle

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/agent/multiplayer-coop.md` states *"there is still no reconnection into an in-progress
PvP battle."* Today a mid-duel disconnect is a **forfeit win** for the remaining player. This
task lets a player who drops rejoin (matched by identity token) and resume the live duel via
the host's existing state mirror.

## Research Notes

- **Authoritative model already fits.** PvP is host-authoritative state-mirroring (GID-091):
  the host owns the canonical `GameState` and broadcasts `sync_state` mirrors; the client is
  a thin renderer that rebuilds `_state` from each mirror via `from_dict`
  (`_on_pvp_state`). A reconnecting client therefore just needs the **current mirror** —
  there is no client-side simulation to rebuild. The `request_sync` RPC
  (`BattleNetSync.gd:42`) already exists precisely to handle "my scene is up, send me the
  state," used today for the startup race — reuse it for reconnect.
- **What blocks it today.** On disconnect the host currently treats it as a forfeit and ends
  the battle (`_on_pvp_ended` / opponent-disconnect → forfeit win, per docs "Rewards & end
  states"). To support reconnect the host must instead **pause** the duel for a grace window
  before declaring forfeit.
- **Token-matched rejoin.** Reconnection of the *session* (world) already resumes a player's
  character + position keyed by `MpProfile.get_token()` (GID-095, `peer_id → token` map,
  one-tap Rejoin list in `MultiplayerLobbyScene`). Extend this: when a peer reconnects, the
  host checks whether that **token** was a combatant in a still-pending duel (track
  `_pvp_combatant_tokens` on the authority alongside the existing `peer_id → idx` maps). If
  so, route the rejoiner into `enter_pvp_battle` with the right `local_player_idx` and have
  it `request_sync`.
- **Grace window.** On `peer_disconnected` during an active duel, start a timer (e.g. 30–60 s)
  instead of immediately forfeiting; pause turn-timeout if any. If the timer expires with no
  rejoin → existing forfeit path. If the token rejoins first → cancel timer, re-mirror.
- **Scene lifetime.** WorldScene is detached-but-alive during a PvP battle and re-attaches on
  return (`_enter_tree` re-runs `_setup_coop`, idempotent — see GID-091 Flow step 4). The
  reconnecting peer, however, comes in cold: it must navigate menu → join → land in the duel.
  Confirm SceneManager can route a fresh client straight into `enter_pvp_battle` from the
  connection handshake (it routes into `enter_map_coop` today; add the duel-redirect analogous
  to the GID-098 late-joiner `recv_map_transition` redirect).
- **Dedicated server (GID-097).** On a dedicated server neither client is the host; the server
  is the referee (`enter_pvp_referee`, `_pvp_peer_to_idx`). The same grace-window + re-mirror
  logic applies there — verify both paths.
- **Scope guard.** Keep it to **PvP** (2-player and, if TID-371 lands, team duels by
  extension). Co-op-PvE reconnect can be a follow-up.
- **Tests:** `tests/net_pvp_reconnect_smoke.gd` (loopback): start duel → drop client →
  reconnect same token within grace → host re-mirrors → client resumes. Mirror
  `net_pvp_client_smoke.gd`.
- **Docs:** update `docs/agent/multiplayer-coop.md` (remove/qualify the "no reconnection into
  an in-progress PvP battle" limitation; document the grace window + token-match).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
