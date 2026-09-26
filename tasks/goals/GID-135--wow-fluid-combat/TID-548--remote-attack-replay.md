# TID-548: Remote Attack Replay in Multiplayer Battles

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-09-26): "multiplayer battles should show my animations on the other players screen, so they see me
attack." State mirrors only carried the result: the opponent / allies / spectators saw HP jump and cards vanish,
and the host saw nothing for a client's attack.

## Research Notes

- Authority broadcasts `BattleNetProtocol.encode_state(state, seq)` via `sync_state` / `sync_coop_state` /
  `sync_team_state`; receivers adopt it wholesale in `BattleNet._accept_state_mirror` → `_adopt_mirrored_state`.
- Client attacks arrive as `INTENT_ATTACK` and resolve in `_resolve_remote_attack` with no FX. Local attacks
  animate in `BattleInput._execute_attack` (lunge, deaths, float labels).
- `CardInstance.instance_id` survives `to_dict`/`from_dict`, so snapshot diffs work across a mirror.
- `BattleNet.gd` is BID-053 lint debt ("don't add to it") — new code goes in a helper.

## Plan

Carry attack events in the mirror; replay them on every receiving screen before adopting the state; give the
authority's own screen the same treatment for remote attacks.

## Changes Made

- `BattleNetProtocol`: `encode_state(state, seq, fx = [])`, `encode_attack_fx(a_pid, a_slot, t_pid, t_slot)`,
  `decode_fx()`; `decode_state` returns `fx` (malformed entries dropped). Old payloads decode with no fx.
- New `scenes/battle/net/NetBattleFx.gd`: authority `record()` / `take()` queue; `replay(fx)` and `lunge()` lunge a
  **ghost** of the attacker panel at the target (the board is re-rendered from the new state underneath).
- `BattleNet`: `record_attack_fx()` forwarder; all three broadcasts drain the queue into the payload;
  `_accept_state_mirror` snapshots → replays → adopts, and `_adopt_mirrored_state(state, snap)` animates deaths
  and floats damage numbers from the diff; remote `INTENT_ATTACK` goes through `_show_remote_attack` (lunge,
  deaths, numbers on the host) after recording.
- `BattleInput._execute_attack` records the host's own attacks.
- Tests: 3 protocol unit tests; `tests/net_attack_replay_smoke.gd` (in CI) — a real BattleScene adopts a mirror
  with an attack fx: ghost lunge appears, HP matches, no SCRIPT ERROR (verified to fail with the fx removed).
  All net_* smokes pass.

## Documentation Updates

`docs/agent/multiplayer-coop.md` → "Attack replay across screens"; CLAUDE.md BattleNet row.
