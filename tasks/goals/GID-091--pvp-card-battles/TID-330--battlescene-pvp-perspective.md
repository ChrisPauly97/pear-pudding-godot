# TID-330: BattleScene PvP perspective, input gating & AI disable

**Goal:** GID-091
**Type:** agent
**Status:** pending
**Depends On:** TID-329

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The core task. BattleScene becomes capable of running a battle where `players[1]`
is a remote human instead of `BasicAI`, under host-authoritative state mirroring.
The host applies both its own and the client's intents to the one canonical
`GameState` and broadcasts the result; the client sends intents and renders the
received mirror **from its own perspective**.

## Research Notes

**Key BattleScene members & flow** (`scenes/battle/BattleScene.gd`):
- `_state: GameState`, `_resolver: SpellEffectResolver`, `_view: CardViewBuilder`,
  `_fx: BattleFx`, `enemy_data: Dictionary`, `duel_wager: int`, `puzzle_data`.
- `_ready()` builds decks (`build_deck_from_instances` for player, `build_deck`
  for enemy), draws opening hands, connects `_state.turn_ended`, then
  `start_turn(1)`.
- Local input → state mutations: `_do_play_card()` / `_do_play_card_at_slot()`
  (play), `_execute_attack()` (attack), `_use_hero_power()`, `_apply_potion_effect()`,
  `_on_end_turn()` → `_state.end_turn()`.
- AI turn: `_on_turn_ended(idx)` → when `idx == 1` (and not puzzle) →
  `_run_ai_turn()` → `BasicAI.decide_turn()` → `_execute_ai_actions()`.
- `_refresh_all()` rebuilds the UI from `_state`; `_view.refresh_zone` /
  `refresh_board_zone` / `refresh_hero` take explicit nodes for hand/board/hero of
  each side. Today the mapping is hard-wired: bottom = `players[0]`, top =
  `players[1]`.

**New PvP fields:**
- `_pvp: bool` — true for a PvP battle (set by SceneManager in TID-331).
- `_local_player_idx: int` — `0` on the host, `1` on the client. The authority
  (host) is always `players` index `0` in the canonical state; the client is
  index `1`. Render mapping: "my side" (bottom) = `players[_local_player_idx]`,
  "opponent" (top) = `players[1 - _local_player_idx]`.
- `_net: BattleNetSync` (preload `scenes/battle/BattleNetSync.gd`) — the relay node
  added under BattleScene; back-reference set to `self`.
- `_state_seq: int` — monotonic counter the host increments per broadcast.

**Perspective rendering.** The cleanest minimal change: introduce accessors like
`_my_player()` / `_opp_player()` that resolve via `_local_player_idx`, and have
`_refresh_all()` feed the bottom nodes from `_my_player()` and the top nodes from
`_opp_player()`. In single-player `_local_player_idx == 0`, so behaviour is
identical (regression-safe). Audit every place that assumes `players[0]` is "me"
or `players[1]` is "the enemy" (targeting highlight, hero panels, hand rendering,
mana pips, potion/hero-power buttons, intent banner) and route through the
accessors. **This audit is the bulk of the work** — be exhaustive; a missed site
shows the wrong side's cards to the client.

**Input gating.** A peer may only act when it is its own turn AND the action phase
is local:
- Allowed when `_state.current_player_idx == _local_player_idx` and not waiting on
  a network round-trip.
- On the **client**, local input must NOT mutate `_state` directly. Instead it
  encodes the intent (TID-328 `BattleNetProtocol`) and `rpc`s `send_intent` to the
  host, then waits for the authoritative `sync_state` mirror before the board
  reflects it (optionally show a lightweight "pending" state). Simplest correct
  model: client is a thin controller — every client action is an intent; the
  client only re-renders on received state.
- On the **host**, local input applies to `_state` as today, then the host
  broadcasts the new state. Remote (client) intents arrive via `_on_pvp_intent`.

**Host intent application (`_on_pvp_intent(sender, payload)`):**
1. Decode via `BattleNetProtocol`.
2. Validate: it is the sender's turn (`current_player_idx == 1`, since client is
   index 1), the action is legal (`can_play`, slot empty, attacker can attack,
   target valid). Reject illegal intents silently (host is authoritative — never
   trust the client). Re-broadcast current state on reject so the client re-syncs.
3. Apply by calling the SAME internal methods the host uses for its own actions but
   targeted at `players[1]` (e.g. a parameterised `_do_play_card_at_slot(card,
   player_idx)` already takes a player_idx in places — verify and extend). Reuse
   `_resolver` for spells, `_execute_attack` for combat.
4. Broadcast: `BattleNetProtocol.encode_state(_state.to_dict(), _state_seq)` via
   `_net.rpc("sync_state", payload)`.

**Client state application (`_on_pvp_state(payload)`):**
- Decode, drop if `seq` older than the last applied, then
  `_state = GameState.from_dict(state_dict)`, re-wire `_resolver.setup(_state)` and
  `_view.set_battle_state(_state, enemy_data)` (these hold `_state` refs — see the
  GID-040 puzzle stale-state fix for the exact re-wiring needed), then
  `_refresh_all()`. Trigger FX from HP deltas if desired (optional for slice).

**AI disable.** In `_on_turn_ended` / `_run_ai_turn`, early-return when `_pvp` is
true so `BasicAI` never runs. The opponent's turn advances only when their intents
(host: applied locally; client: received via mirror) arrive. The turn-start
bookkeeping (`start_turn`) still runs inside `GameState.end_turn()` on the host;
the client receives the post-state.

**End-of-turn ownership.** `end_turn` must only be initiated by the player whose
turn it is. On the client, "End Turn" sends an `end_turn` intent; the host calls
`_state.end_turn()` and broadcasts. Ensure `turn_ended`-driven host logic
(companion draws, status ticks, auto-spell flush in `_on_turn_ended`) runs on the
**host** for both players (host is authority) and the results land in the mirror.

**Out of scope here:** challenge handshake & SceneManager routing (TID-331),
result overlays & disconnect (TID-332). This task can be exercised by temporarily
forcing `_pvp` + `_local_player_idx` in a test harness or by landing TID-331 next.

**CLAUDE.md:** preload `BattleNetSync.gd` and `BattleNetProtocol.gd` (no
`class_name` reliance); explicit types on dict/array indexing; run the headless
editor import after edits — a parse error in BattleScene cascades widely. Keep all
new code guarded by `_pvp` so single-player/NPC/duel/puzzle/Spire battles are
unchanged.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
