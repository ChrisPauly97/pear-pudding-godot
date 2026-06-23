# TID-333: Loopback PvP smoke test & agent docs

**Goal:** GID-091
**Type:** agent
**Status:** pending
**Depends On:** TID-332

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Verification and documentation for the PvP feature: a real loopback smoke test that
exercises the intent → host-apply → state-mirror round-trip, plus updates to the
agent docs so the system is fully described for future work.

## Research Notes

**Smoke-test precedent.** GID-090 added on-demand SceneTree smoke tests run with
`godot --headless --path . -s tests/<file>` (exit 0 = pass), kept OUT of the
auto-discovered unit suite because they need real sockets + frame polling:
- `tests/net_coop_smoke.gd` — real ENet loopback connect + NetSync RPC +
  AvatarSync decode end to end.
- `tests/net_discovery_smoke.gd` — loopback UDP discovery.

Add `tests/net_pvp_smoke.gd` in the same style:
1. Stand up a host + client over ENet loopback (reuse the connect helper pattern
   from `net_coop_smoke.gd`).
2. Build a minimal canonical `GameState` on the host (two tiny decks).
3. Client sends a `send_intent` (e.g. `end_turn` or a `play_card_at_slot`) via the
   `BattleNetSync` relay; host applies it and broadcasts `sync_state`.
4. Assert the client receives a mirror whose `seq`/state reflects the applied
   action (e.g. `current_player_idx` flipped, or the card on the board). Exit 0 on
   success, 1 on failure.

Note the RPC-path requirement: the relay node must sit at an identical path on
both peers (`/root/.../BattleNetSync`). The smoke test must construct that path
deterministically (it can add the relay under a fixed-name parent node to mimic
the BattleScene root).

**Unit tests** for the pure protocol already live in `tests/unit/test_pvp_protocol.gd`
(TID-328) and run in the auto suite via `tests/runner.gd`. Confirm both the unit
suite (exit 0) and the new smoke test pass, and that a headless editor import is
clean (no parse/compile errors across the BattleScene preload chain).

**Docs to update:**
- `docs/agent/multiplayer-coop.md` — add a "PvP Card Battles (GID-091)" section:
  host-authoritative model, `BattleNetProtocol` wire format, `BattleNetSync` relay
  + reliable RPCs, perspective/`_local_player_idx`, challenge handshake, duel-style
  rewards, disconnect-forfeit, and a refreshed Limitations list (PvP is LAN/loopback
  only, 2 players, no reconnection/spectating/wagers). Update the status banner at
  the top (no longer "battles out of scope").
- `docs/agent/battle-system.md` — add a "PvP Battles" subsection under Integrations
  noting `_pvp` / `_local_player_idx`, AI disable, host applies remote intents, and
  that single-player paths are unchanged.
- `CLAUDE.md` doc table — the `multiplayer-coop.md` row already exists; update its
  description to mention PvP, or confirm it still reads correctly.
- Add the new test files to the Tests table in `multiplayer-coop.md`.

**CLAUDE.md conventions:** keep agent docs exhaustive; do not create a new
standalone doc file for PvP (amend the existing `multiplayer-coop.md`, per the
"Avoiding Documentation Sprawl" rule).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
