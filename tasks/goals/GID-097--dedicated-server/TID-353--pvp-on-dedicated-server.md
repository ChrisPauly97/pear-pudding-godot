# TID-353: PvP on dedicated server (server-authoritative duel)

**Goal:** GID-097
**Type:** agent
**Status:** pending
**Depends On:** TID-352

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP today (GID-091) is host-authoritative where **the host is also player idx 0**.
On a dedicated server neither connected peer is the host, so the duel needs the
server to act as a non-playing referee that owns the `GameState` and both players
are clients sending intents.

## Research Notes

_To be expanded when TID-352 lands._

- **Current model:** `docs/agent/multiplayer-coop.md` "PvP Card Battles" — host owns
  the one `GameState` (`players[0]` = host, `players[1]` = client), applies both
  sides' intents, broadcasts `to_dict()`. Client sends intents, renders the mirror
  from its perspective. Relay = `scenes/battle/BattleNetSync.gd`; wire format =
  `game_logic/net/BattleNetProtocol.gd`.
- **Generalization needed:** decouple "authority" from "player idx 0". The server
  builds the `GameState` for *two client players* (idx 0 and 1 both remote), applies
  intents from both, broadcasts to both. Both clients become the
  `_local_player_idx == 1`-style perspective renderers (already supported); the
  server-as-referee is the new `_local_player_idx == none` case (renders nothing /
  headless). Audit `_my_idx()/_opp_idx()` accessors and the
  `NetworkManager.is_host()` checks that currently equate host with player 0.
- **Listen-server unchanged:** when the authority *is* a player (listen server), the
  existing path must still work — branch on "is the authority a player?" not on a
  rewrite. Keep `net_pvp_smoke` / `net_pvp_client_smoke` passing.
- **Challenge handshake routing** (`enter_pvp_battle`, WorldScene
  `_request_challenge`/`_accept_challenge`) needs a 3-party variant: two clients
  challenge, server arbitrates and launches both into the battle as clients.
- Rewards stay duel-style (no rewards) per GID-091, unless changed by then.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
