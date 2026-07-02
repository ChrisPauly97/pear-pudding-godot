# TID-387: Spectator Wagers

**Goal:** GID-104
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** claude/sonnet-5-subagent-dispatch-yz77ku
**Acquired:** 2026-07-02T09:05:00Z
**Expires:** 2026-07-02T09:35:00Z

## Context

Spectating a duel (TID-367) is passive—the 3rd or 4th player watches a 1v1 with no stake in the outcome. Letting spectators place coins on the duel outcome makes watching an activity and gives the non-combatant a stake in the match. Spectators can bet on either the left (peer_a) or right (peer_b) player before a cutoff time (e.g. end of turn 3, tracked from the mirrored `GameState.turn_number`). The authority holds all bets in escrow, and on `GameBus.pvp_battle_ended`, the authority settles payouts: winners double their bet (or get a 1:1 payout depending on odds), losers lose their coins. Bets are written directly to `SessionState` member records at settlement time via the same pattern as `_grant_chest_loot_to_token` (used for chest loot and bounty rewards), so all bet data persists across sessions. No UI is needed for players to initiate custom wagers (BID-029 has the plumbing but no callers); spectator wagers are side-bets on an existing live match.

A new pure wire format `game_logic/net/WagerSync.gd` encodes/decodes spectator bets and broadcasts them over the existing `BattleNetSync` RPC channel (since spectators are already in `BattleScene` via the spectate flow). A small bet panel on the spectator view (viewport-relative, tap targets, mobile parity) lets the spectator select their wager amount and side before the cutoff. At the cutoff, the panel locks and displays "Bets Closed". After the match, the settlement panel shows the outcome and payout. Guard rails: no betting on your own match (spectators only), cap bet size (e.g. max 50 coins or 10% of available coins), and refund bets on disconnect/draw. The spectator's own deck is never at risk—only coins.

## Research Notes

**Existing patterns:**
- Spectate system (TID-367): `SceneManager.enter_pvp_spectator()` launches `BattleScene` read-only with `_pvp_spectating = True`. `NetSync.recv_pvp_active(in_battle, peer_a, peer_b)` tracks who is fighting. `BattleNetSync` mirrors `GameState` from the host; spectators receive full state updates including `turn_number`.
- Wire format: `BattleNetSync.gd` relays host RPC to spectators. New spectator-specific RPCs can be added (e.g. `_broadcast_spectator_bet(peer_idx, side, amount)`) or bets can be piggybacked on the existing state mirror as a new `"spectator_bets"` field: a dictionary mapping peer indices to bet dicts `{"side": "a"|"b", "amount": int}`.
- Pure wire helpers: `AvatarSync.gd` and `BattleNetProtocol.gd` in `game_logic/net/` are pure, scene-free, and unit-tested. `WagerSync` follows the same pattern: static methods `encode_bet(peer_idx, side, amount) -> Dictionary`, `decode_bet(dict) -> {peer_idx, side, amount}`, `encode_settlement(settlements) -> Dictionary` (maps peer to payout or loss), `decode_settlement(dict)`.
- Coin escrow: `SaveManager.add_coins(delta)` deducts the bet when placed (or authority-only, escrow held in `BattleScene` volatile state). On settlement, authority writes directly to `SessionState.members[peer_token].coins += payout` (direct write, not `add_coins`, to bypass auth checks). This mirrors the pattern from bounty rewards and chest loot in `_grant_chest_loot_to_token`.
- Turn tracking: `GameState.turn_number` is mirrored from host to spectators, so the cutoff (e.g. `turn_number > 3`) is known locally to all peers.
- Match identity: `BattleNetSync` already tracks `_pvp_a_idx` and `_pvp_b_idx` (the peer indices fighting). Spectators use these to know who they can bet on (not themselves, if they were a combatant in a prior match in the same session—though typically a spectator in one match is not a combatant in the same session).
- Disconnect handling: if a spectator disconnects, their pending bet is refunded immediately (removed from escrow, coins restored to `SessionState`). If a combatant disconnects and the match is abandoned, all spectator bets are refunded.

**CLAUDE.md invariants:**
- Preload + UID: if new `.tres` wager configs are created, declare preloads and generate `.uid` sidecars.
- Headless import: after any `.gd` edit, run the import check—must be empty.
- NetworkManager guard: all wager logic wrapped in `if NetworkManager.is_active():` (single-player unaffected).
- Mobile parity: the bet UI (amount input, side buttons) must be tap-able and readable on a small mobile screen.

**Files to examine:**
- `scenes/battle/BattleNetSync.gd` — mirrors `GameState`; add spectator-bet RPC or extend the state dict.
- `scenes/battle/BattleScene.gd` — spectator view layout; add bet panel.
- `autoloads/SaveManager.gd` — `add_coins` and member-write patterns for escrow/settlement.
- `autoloads/SessionState.gd` — `members` list, direct coin writes.
- `game_logic/net/BattleNetProtocol.gd` — existing pure wire helpers; reference for style.
- `game_logic/net/AvatarSync.gd` — another example of pure encode/decode helpers.
- `autoloads/NetworkManager.gd` — `is_active()`, `get_peer_token(idx)` (to map peer index to session token for settlement writes).
- `docs/agent/multiplayer-coop.md` — section "Spectating a duel" (background info on TID-367).
- `docs/agent/battle-system.md` — `GameState.turn_number` and turn flow (to decide cutoff).

**BID-029 context:**
`SceneManager._request_wager_challenge(peer_idx, challenger_ante, wager_ante)` in `scenes/multiplayer/NetSync.gd` (or similar) exists but has zero callers. This task's spectator wagers may finally exercise custom wager plumbing if a future feature lets spectators initiate custom-ante challenges. For now, spectator wagers are fixed bets on existing live matches, not initiating new challenges.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
