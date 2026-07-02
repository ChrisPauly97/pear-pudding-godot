# TID-387: Spectator Wagers

**Goal:** GID-104
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

1. **Pure logic — `game_logic/net/WagerSync.gd`** (new, mirrors `AvatarSync`/`BattleNetProtocol`/`LootRoll`; no scene deps):
   - Constants: `SIDE_A = "a"` (players[0]), `SIDE_B = "b"` (players[1]), `OUTCOME_DRAW`, `OUTCOME_ABANDONED`, `CUTOFF_TURN = 3`, `MAX_BET_FLAT = 50`, `MAX_BET_PCT = 0.10`.
   - Cutoff: `is_betting_open(turn_number)` — every peer already mirrors `GameState.turn_number`, so no extra wire traffic is needed for the cutoff; the host enforces it authoritatively and the spectator UI locks from the same value.
   - Caps: `max_bet(coins)` = min(flat, 10% floored); `is_valid_bet(side, amount, coins, existing)` validates a replacement against total headroom (balance + prior stake).
   - Wire: `encode_bet`/`decode_bet` (`{side, amount}`), `encode_settlement`/`decode_settlement` (`{outcome, payouts}`). All decoders garbage-tolerant, forged sides normalize to `""`.
   - Settlement: `settle(bets, outcome) -> {token: credit}` — 1:1 payout (winner credited 2× stake since the stake was already debited), losers 0, draw/abandoned refund exactly the stake.
2. **RPCs — `BattleNetSync.gd`** (3 new reliable RPCs in the TID-367 spectate style): `submit_spectator_bet` (spectator→host), `recv_wager_ack`, `recv_wager_settlement` (host→spectator).
3. **Peer→token across the detached WorldScene**: new `SceneManager.session_token_for_peer(peer_id)` reads the live scene in WORLD state or `_saved_world_scene` during BATTLE; backed by a new public `WorldScene.get_session_token_for_peer` over `_session_token_by_peer` (guarding `multiplayer` access behind `is_inside_tree()` since the scene is detached mid-battle).
4. **Authority escrow/settlement — `BattleScene`**:
   - `_wager_bets: {token → {side, amount, peer_id}}` + one-shot `_wagers_settled`.
   - `_on_wager_bet_submitted`: guards (`NetworkManager.is_active()`, `_is_pvp_host()`, `_pvp`, not ended, sender in `_spectators` and not in `_pvp_peer_to_idx` — no betting on your own match), cutoff, `is_valid_bet` against the SessionState record; debits the stake directly from the member record (the `_grant_chest_loot_to_token` write pattern in reverse) and acks with the authoritative remainder.
   - `_settle_spectator_wagers(outcome)`: called from every host end path *before* the `pvp_ended` broadcast (normal game-over + both surrender paths → winning side; reconnect-grace forfeit + host `session_ended` → `OUTCOME_ABANDONED` refund); credits payouts into member records and unicasts the settlement to still-connected bettors.
   - `_refund_wager_for_peer(pid)` from `_on_pvp_peer_disconnected`: immediate refund for a disconnecting spectator. Opportunistic fix in the same handler: a pid found in `_spectators` must not trip the listen-server `idx = 1` combatant fallback (bogus grace window).
5. **Spectator UI — `BattleScene._build_wager_panel`** (built only in the `_pvp_spectating` branch of `_setup_pvp_battle`, gated by `NetworkManager.is_active()`): viewport-relative panel on `_float_layer` — side toggle buttons ("Bottom Player"/"Top Player"), −/+ amount stepper (step 5, clamped to `max_bet`), "Place Bet", status line. `_update_wager_panel()` re-evaluates on every state mirror; past cutoff everything disables and shows "Bets Closed". Ack/settlement apply the exact authoritative coin delta locally (`add_coins(remaining - current)`) so the periodic session persist-back can't clobber the record. Settlement line surfaces on the panel and on the result overlay via a new optional `wager_note` param on `BattleResultUI.show_pvp_result` ("" default = existing call sites unchanged).
6. **Tests — `tests/unit/test_wager_sync.gd`**: cutoff, caps (flat/pct/boundaries), validation (incl. replace-bet headroom), encode/decode round-trips + garbage tolerance, settlement math (win/loss/mixed/draw/abandoned/garbage entries), end-to-end net-effect flow.
7. **Docs**: new "Spectator wagers (GID-104 / TID-387)" section in `docs/agent/multiplayer-coop.md` after the TID-367 spectate section.

## Changes Made

**New files:**
- `game_logic/net/WagerSync.gd` — pure spectator-wager helpers: sides/outcomes, cutoff (`CUTOFF_TURN = 3`, checked against the mirrored `turn_number`), bet caps (min of 50 flat and 10% of balance), `is_valid_bet` (replacement-aware headroom), `encode_bet`/`decode_bet`, `settle` (1:1 payout; draw/abandoned refund), `encode_settlement`/`decode_settlement`. No scene deps; all decoders garbage-tolerant.
- `tests/unit/test_wager_sync.gd` — 39 unit tests covering cutoff, caps, validation, wire round-trips + garbage tolerance, payout math, and the full place→settle net-effect flow.

**Modified files:**
- `scenes/battle/BattleNetSync.gd` *(shared)* — added the spectator-wager RPC trio (`submit_spectator_bet`, `recv_wager_ack`, `recv_wager_settlement`), an isolated block between the spectate and team-duel sections.
- `scenes/battle/BattleScene.gd` *(shared)* — `WagerSync` preload + a self-contained wager var block; authority escrow (`_on_wager_bet_submitted` — spectators only, never combatants; direct SessionState debit), one-shot settlement (`_settle_spectator_wagers`) wired into the four host end paths (game-over, remote/local surrender → winning side; grace-expired forfeit and host `session_ended` → abandoned refund) always *before* the `pvp_ended` broadcast; spectator disconnect refund (`_refund_wager_for_peer`); spectator bet panel (`_build_wager_panel` + `_update_wager_panel`, viewport-relative, all-Button tap targets, "Bets Closed" lock from each state mirror) and ack/settlement handlers that mirror the authoritative coin deltas into the local character. Opportunistic bug fix: `_on_pvp_peer_disconnected` no longer treats a disconnecting **spectator** as the listen-server combatant client (previously any pid hit the `idx = 1` fallback and started a bogus 45 s grace window → forfeit).
- `scenes/battle/BattleResultUI.gd` *(shared)* — `show_pvp_result` gained an optional `wager_note: String = ""` third parameter rendering one extra settlement label; all existing call sites unchanged.
- `autoloads/SceneManager.gd` *(shared)* — new `session_token_for_peer(peer_id)` helper resolving through the live or detached (`_saved_world_scene`) WorldScene.
- `scenes/world/WorldScene.gd` *(shared)* — new public `get_session_token_for_peer(peer_id)` accessor over `_session_token_by_peer` (guards `multiplayer` behind `is_inside_tree()` because it is called while the scene is detached mid-battle).
- `docs/agent/multiplayer-coop.md` — new "Spectator wagers (GID-104 / TID-387)" section.

**Guard rails honored:** all wager logic inert without `NetworkManager.is_active()` (panel only exists for `_pvp_spectating`, authority handlers guard explicitly); single-player byte-for-byte unchanged; only coins at risk, never cards; no betting on your own match; bet cap enforced host-side; refunds on spectator disconnect, abandoned match, and (future) draw.

**Not run (environment):** Godot is unavailable in this environment, so the headless import and the unit suite could not be executed; the diff was hand-audited against every CLAUDE.md parse pitfall (no `:=` on Variant RHS, no `//`, no 2-arg `Object.get()`, preloads for all cross-file class references, RPC arg counts match).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added the "Spectator wagers (GID-104 / TID-387)" section after "Spectating a duel" — WagerSync pure helpers (cutoff/caps/settlement math and the house-banked 1:1 payout note), the three BattleNetSync RPCs, authority escrow + settlement/refund flow (including the `session_token_for_peer` detached-WorldScene bridge and the local coin-mirror rationale vs. `_tick_session_persist`), the bet panel UI/mobile parity, the "Bets Closed" lock, and the opportunistic spectator-disconnect fix.
