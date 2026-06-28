# TID-360: N-player host-authoritative battle networking

**Goal:** GID-099
**Type:** agent
**Status:** done
**Depends On:** TID-359

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wire the N-player co-op battle state (TID-359) over the network so 2–4 players join one
shared battle from the world, every client's intents reach the authority, and the
mirror renders on each. This generalizes the GID-091 PvP transport from 2 acting peers
to N.

## Research Notes

- **PvP transport to reuse (GID-091, see `multiplayer-coop.md` → "PvP"):**
  - `game_logic/net/BattleNetProtocol.gd` — pure wire format: `encode_play_card_at_slot`,
    `encode_play_spell` (target dicts), `encode_attack`, `encode_end_turn`,
    `encode_hero_power`, `encode_potion`, `encode_state(state_dict, seq)`. Unit-tested in
    `test_pvp_protocol.gd`.
  - `scenes/battle/BattleNetSync.gd` — fixed-name child of `BattleScene` (RPC path
    `/root/BattleScene/BattleNetSync` matches on all peers). Reliable RPCs: `send_intent`
    (client→host), `sync_state`/`pvp_ended` (host→clients), `request_sync` (retried until
    first mirror).
  - `BattleScene._local_player_idx` (0 host, 1 client, -1 dedicated referee);
    `_pvp_peer_to_idx` maps peer→idx on the dedicated-server referee path
    (`enter_pvp_referee`, GID-097/TID-353) — this is the **existing N-acting-peer
    generalization to mirror**.
- **What changes for N players:**
  - **Spell/attack targets** must carry a **player index** (which ally's board/hero),
    not just `{side, slot}`. Extend `BattleNetProtocol` target dicts with an explicit
    `player`/`pidx`. (Cross-board *card mechanics* are GID-100; the *protocol room* for
    targeting any board is added here.)
  - `_pvp_peer_to_idx` becomes the general `peer→ally_idx` map for the co-op battle;
    `_on_pvp_intent(sender, payload)` resolves `acting_idx` from it (already done for the
    referee path — extend from 2 to N).
  - State mirror (`encode_state`/`from_dict`) already round-trips the whole `GameState`;
    confirm it carries N participants after TID-359.
- **Battle entry:** add a co-op-battle entry alongside `SceneManager.enter_pvp_battle`
  / `enter_pvp_referee`. Challenge/handshake analog: an engage on a shared boss invites
  same-map party members to join; each accepting peer is assigned an ally idx by the
  authority (mirror the GID-097 3-message handshake). Decide join window (before battle
  start only, vs late-join) during Plan — start-only is simpler.
- **Authority:** listen-server host is `players` authority; on a dedicated server the
  server is the referee (`_local_player_idx == -1`, no UI) — keep that path working.
- **Tests:** extend the smoke suite — a `tests/net_coop_battle_smoke.gd` (real ENet
  loopback, host + 2 clients): each client intent reaches the authority, state mirror
  with 3 allies + boss decodes on every peer. Mirror `net_pvp_smoke.gd` /
  `net_pvp_client_smoke.gd`.

## Plan

Extended `BattleNetProtocol.encode_attack` with optional `target_pidx: int = -1` for
cross-board targeting. Added 4 new reliable RPCs to `BattleNetSync` for co-op PvE:
`send_coop_intent`, `sync_coop_state`, `coop_battle_ended`, `request_coop_sync` (kept
separate from PvP RPCs to avoid cross-mode confusion). Added `_on_coop_intent`,
`_on_coop_state`, `_on_coop_sync_request`, `_broadcast_coop_state`, `_setup_coop_pve_battle`,
`_build_coop_pve_state`, `_process_coop_sync` in `BattleScene`. Updated `_send_intent` to
route through `send_coop_intent` when `_coop_pve`. Added `SceneManager.enter_coop_pve_battle`
and `_on_coop_pve_battle_ended`. Added `GameBus.coop_pve_battle_ended` signal.

## Changes Made

- `game_logic/net/BattleNetProtocol.gd`: `encode_attack` gains `target_pidx` param;
  `decode_intent` includes `"target_pidx"` field in defaults and INTENT_ATTACK branch.
- `scenes/battle/BattleNetSync.gd`: added 4 co-op PvE RPCs.
- `scenes/battle/BattleScene.gd`: `_coop_pve` mode, `_setup_coop_pve_battle`,
  `_build_coop_pve_state`, `_on_coop_state`, `_on_coop_intent`, `_on_coop_sync_request`,
  `_broadcast_coop_state`, `_process_coop_sync`, `_send_intent` routing; extended
  `_is_pvp_host`, `_is_pvp_client`, `_opp_idx` for co-op; extended `_on_turn_ended`
  for N-player boss turn detection; extended `_check_game_over` for co-op.
- `autoloads/GameBus.gd`: `coop_pve_battle_ended(did_win: bool)` signal.
- `autoloads/SceneManager.gd`: `enter_coop_pve_battle`, `_on_coop_pve_battle_ended`.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: GID-099 section (networking sub-section).
