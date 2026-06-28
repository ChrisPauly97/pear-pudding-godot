# TID-353: PvP on dedicated server (server-authoritative duel)

**Goal:** GID-097
**Type:** agent
**Status:** done
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

1. **NetSync.gd** — add 4 RPCs: `set_session_flags`, `relay_pvp_request`,
   `relay_pvp_response`, `notify_pvp_start`.
2. **WorldScene.gd** — add `_session_dedicated` flag; route challenge/response
   through server when flag is set; add server-side relay handlers
   (`_on_relay_pvp_request`, `_on_relay_pvp_response`); call
   `SceneManager.enter_pvp_referee` on the server.
3. **SceneManager.gd** — add `enter_pvp_referee(deck_a, deck_b, peer_a_id,
   peer_b_id)` that instantiates BattleScene with `_local_player_idx = -1` and
   the `_pvp_peer_to_idx` map.
4. **BattleScene.gd** — generalise `_is_pvp_host()` / `_is_pvp_client()` to use
   `NetworkManager.is_host()` rather than `_local_player_idx == 0`; add
   `_pvp_peer_to_idx` lookup in `_on_pvp_intent`; guard all render paths with
   `if _local_player_idx < 0: return`; generalise `_apply_remote_intent` to use
   `player_idx`/`opp_idx` instead of hardcoded `0`/`1`; update
   `_apply_remote_surrender(player_idx)`; update `_finish_pvp` to emit
   `pvp_battle_ended` headlessly when referee.

## Changes Made

### `scenes/world/NetSync.gd`
- Added `set_session_flags(flags)` — server → client session metadata RPC.
- Added `relay_pvp_request(target_peer_id, challenger_deck)` — client → server
  challenge relay.
- Added `relay_pvp_response(challenger_id, accepted, responder_deck)` — client →
  server challenge response relay.
- Added `notify_pvp_start(my_player_idx, opponent_deck)` — server → client battle
  start notification.

### `scenes/world/WorldScene.gd`
- Added `_session_dedicated: bool`, `_pvp_relay_challenger_id`, `_pvp_relay_challenger_deck`,
  `_pvp_relay_target_id` vars.
- `_setup_coop()`: skips `_ensure_challenge_button()` and LAN IP toast and roster
  build on dedicated server.
- `_send_character_to_peer()`: sends `set_session_flags({"dedicated": true})` after
  delivering character record in dedicated mode.
- `_request_challenge()`: routes through `relay_pvp_request` → server when
  `_session_dedicated`, else direct P2P.
- `_accept_challenge()` / `_decline_challenge()`: route through `relay_pvp_response`
  → server when `_session_dedicated` (accept returns early, waits for `notify_pvp_start`).
- Added `_on_session_flags`, `_on_relay_pvp_request`, `_on_relay_pvp_response`,
  `_on_notify_pvp_start` handlers.
- `_on_relay_pvp_response`: on accept, calls `SceneManager.enter_pvp_referee` on the
  server after dispatching `notify_pvp_start` to both clients.

### `autoloads/SceneManager.gd`
- Added `enter_pvp_referee(deck_a, deck_b, peer_a_id, peer_b_id)`: instantiates
  BattleScene with `_local_player_idx = -1`, `pvp_player0_deck`/`pvp_player1_deck`,
  and `_pvp_peer_to_idx` map. Headless referee — no rendering.
- `_on_pvp_battle_ended`: added dedicated-server branch to restore world scene
  directly (no transition) when authority finishes as referee.

### `scenes/battle/BattleScene.gd`
- Added `pvp_player0_deck`, `pvp_player1_deck`, `_pvp_peer_to_idx` vars.
- `_is_pvp_host()`: changed to `_pvp and NetworkManager.is_host()` — covers both
  listen-server (player 0) and dedicated-server (referee, idx=-1).
- `_is_pvp_client()`: changed to `_pvp and not NetworkManager.is_host()`.
- `_build_pvp_decks()`: referee branch builds both decks from `pvp_player0_deck` /
  `pvp_player1_deck`; listen-server path unchanged.
- `_can_local_act()`: returns false if `_local_player_idx < 0`.
- `_refresh_all()`, `_refresh_player_board()`, `_update_status()`: early-return if
  `_local_player_idx < 0`.
- `_on_pvp_intent()`: resolves `acting_idx` from `_pvp_peer_to_idx` when referee;
  calls `_apply_remote_surrender(acting_idx)` / `_apply_remote_intent(intent, acting_idx)`.
- `_apply_remote_intent(intent, player_idx)`: generalised — uses `player_idx` and
  `opp_idx = 1 - player_idx` throughout instead of hardcoded `1`/`0`.
- `_apply_remote_surrender(player_idx)`: generalised — sets the surrendering player's
  health to 0, broadcasts winner as `1 - player_idx`.
- `_pvp_surrender()`: added `_local_player_idx < 0` guard; generalised host branch to
  use `_local_player_idx` instead of hardcoded `0`.
- `_finish_pvp()`: if `_result_ui == null` and referee, emits `pvp_battle_ended`
  directly so SceneManager returns to world.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: extended the "Dedicated Server" section with a
  "PvP on a Dedicated Server" subsection documenting the 3-message handshake,
  referee BattleScene, client flow, and listen-server compatibility note.
