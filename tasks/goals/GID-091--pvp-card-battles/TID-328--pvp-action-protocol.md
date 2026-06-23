# TID-328: PvP action wire protocol (pure logic + unit tests)

**Goal:** GID-091
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Defines the wire format for PvP battle networking before any scene/RPC plumbing,
mirroring how GID-090 split pure `AvatarSync.gd` from the `NetSync` RPC node. This
is a pure, scene-free, fully unit-tested helper so the encode/decode contract is
locked and testable without sockets.

Two payload families are needed:
1. **Intents** the client sends to the host (one human action each).
2. The **full-state mirror** the host broadcasts back (a thin wrapper around the
   existing `GameState.to_dict()`).

## Research Notes

**Mirror the AvatarSync pattern.** `game_logic/net/AvatarSync.gd` is static,
scene-free, returns plain `Array`/`Dictionary`, and is unit-tested in
`tests/unit/test_coop_sync.gd` (auto-run suite). Follow the same shape:
`game_logic/net/BattleNetProtocol.gd` with `static func encode_*` /
`decode_*`, returning JSON-friendly types (RPC args serialize fine as
`Dictionary`/`Array`, but keep them primitive: String/int/bool/float/Array/Dict).

**The set of local player actions to support** (from BattleScene research — these
are every method that mutates `GameState` in response to local input):

| Intent type | BattleScene origin | GameState/PlayerState call | Key fields |
|---|---|---|---|
| `play_card_at_slot` | `_do_play_card_at_slot()` | `players[pid].play_card_at_slot(card, slot)` | `card_uid`/hand index, `slot_idx` |
| `play_spell` | `_do_play_card()` | `players[pid].play_card(card)` + `_resolver.resolve_spell(...)` | hand index, optional `target` dict |
| `attack` | `_execute_attack()` | minion attacks minion/hero | `attacker_ref`, `target_ref` (slot idx or `"hero"`) |
| `end_turn` | `_on_end_turn()` | `_state.end_turn()` | — |
| `hero_power` | `_use_hero_power()` | direct hero/board mutation | optional target |
| `potion` | `_apply_potion_effect()` | direct hero mutation | `potion_id` |
| `surrender` | new (flee in PvP) | host marks remote hero dead / ends battle | — |

**Card/minion identity over the wire.** `CardInstance` has a stable
`instance_id` (preserved across `to_dict`/`from_dict`, see GID-034) and, for
player-owned cards, a `collection_uid`. Use a positional/identity scheme that is
unambiguous on the host's canonical state: prefer **(zone, index)** addressing for
hand cards and **board slot index** for board minions, since the host applies the
intent against *its* authoritative state and both sides agree on slot indices.
Decide and document the exact addressing in the Plan — the simplest robust choice
is: hand cards by `hand_index`, board minions by `board_slot`, hero by the literal
`"hero"`. Avoid sending `instance_id` if slot/index addressing is sufficient,
since the host is authoritative anyway.

**Full-state mirror.** Wrap `GameState.to_dict()`:
`encode_state(state_dict, seq) -> Dictionary` returning
`{"v": 1, "seq": seq, "state": state_dict}`; `decode_state(payload)` returns the
inner dict + seq. A monotonic `seq` lets the client drop stale/out-of-order
mirrors (RPC will be reliable+ordered, but `seq` is cheap insurance and aids
tests).

**CLAUDE.md conventions:** explicit type annotations (dict indexing returns
Variant); no `class_name` reliance — callers will `preload(...)`; keep all data
JSON-primitive so it survives ENet RPC serialization. No `.uid` needed for `.gd`
scripts (only resources), but the editor will generate a `.gd.uid` — fine.

**Tests:** add `tests/unit/test_pvp_protocol.gd` to the auto-run suite (same
folder/registration as `test_coop_sync.gd`). Cover: each intent encode→decode
round-trip preserves fields; unknown/garbage payloads decode to a safe empty/typed
default; `encode_state`/`decode_state` round-trip including `seq`. Confirm the
runner picks it up (`tests/runner.gd`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
