# TID-390: Co-op Spire — Shared Run & Alternating Draft

**Goal:** GID-106
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Endless Spire (GID-038) is the game's most replayable single-player mode — players enter at floor 1, defeat progressively harder bosses, and pick from 3-card-1 drafts between each floor before the run ends on a loss. Today it is single-player only. To make it a co-op anchor feature, this task adapts the run for a party: the same seed-based floor composition, but the deck is **shared and built collaboratively** via alternating draft picks. This transforms the Spire from "I climb the tower" into "we climb the tower together," giving the co-op session a replayable, goal-oriented activity beyond just exploring madrian.

The authority orchestrates the draft flow using the **loot-roll prompt pattern** (TID-381: broadcast draft options to all, the active picker submits choice via RPC, authority applies + broadcasts result, auto-pick on timeout). Each member's turn cycles in party member order round-robin. The resulting run deck is **transient** — never written to any member's `owned_cards`; it lives in memory for the duration of the run and is discarded on completion. A co-op Spire run entry point (host-only button) and a "waiting for <name>" state for inactive pickers complete the flow.

## Research Notes

**Entry point — host-only HUD button (TID-380 pattern).** WorldScene spawns a "Co-op Spire" button (viewport-relative, sized per CLAUDE.md parity rules) visible only to the host (`NetworkManager.is_host()`) and only when not already in a battle/overlay. On press, route to `SceneManager.enter_spire_coop()` (new method), which enters the Spire with a `coop_mode = true` flag (new `SpireScene` field) and seeds the run with `_shared_seed` computed from `SessionStore.get_state().session_id` (deterministic, all peers derive the same seed). Single-player routes through the existing `enter_spire()` path, unaffected.

**Shared seed & identical floor composition.** The Spire's floor generation already keys off a seed (`game_logic/SpireFloorGen.gd`), so all peers independently compute the same floor bosses given the same seed. No new wire format needed — the seed is a single constant derived per run.

**Draft orchestration — reuse loot-roll pattern (TID-381).** The authority holds a `_coop_spire_draft_session: Dictionary` with `{active_picker_idx, round, pending_choices, auto_pick_timer}`. On floor completion:
1. Fetch 3-card draft options (standard `SpireFloorGen` logic).
2. Broadcast `NetSync.recv_spire_draft_start(options, active_picker_token, active_picker_name)` (reliable RPC).
3. Set a timeout (e.g. 30 s) for auto-pick if the active picker doesn't respond.
4. The active picker (any peer, identified by their `SessionState` token) receives the prompt and calls `NetSync.submit_spire_draft_choice(card_idx)` (reliable).
5. Authority applies the choice, advances the picker index (`(i + 1) % party_size`), and broadcasts `NetSync.recv_spire_draft_choice(card_uid, next_active_picker_token)` to all.
6. On all peers, the UI updates: "Drafting… [card name]" becomes "Waiting for <name>…" until the next choice arrives.
7. Loop until the deck reaches the target size (existing Spire draft logic).

**New pure wire helper in `game_logic/net/SpireDraftSync.gd`** (mirrors `AvatarSync.gd`, `BattleNetProtocol.gd`):
- `encode_draft_start(options, active_picker_token, active_picker_name) -> Array`
- `encode_draft_choice(card_uid, next_active_picker_token) -> Array`
- `decode_draft_start(payload) -> Dictionary` — fully defaulted, garbage-safe
- `decode_draft_choice(payload) -> Dictionary` — fully defaulted

**Draft UI — reuse SpireScene's existing draft overlay, add "waiting" state.** `SpireScene._show_draft_overlay()` already displays 3 selectable card buttons. When `_coop_draft_active` and this peer is not the picker, disable all buttons and show a banner "Waiting for <name> to pick…" (fetched from the broadcast payload or looked up in `WorldScene._remote_identities[peer_id]`). Readonly mode on non-authority peers — client draft UI is disabled until the authority applies the choice and broadcasts the next picker's turn. The banner updates on each `recv_spire_draft_choice` broadcast, so the waiting player sees "Waiting for Alice…" → apply → "Your turn!" → draft buttons re-enabled.

**Transient shared deck.** SpireScene gains a `_coop_shared_deck: Array[String]` (not persisted, not written to SaveManager or SessionState). It accumulates during draft picks and is passed to `_setup_floor_battle(coop_shared_deck)` when entering a floor. Non-co-op runs use the existing single-player `_player_deck` flow unchanged.

**Project invariants.** All co-op Spire code guarded by `NetworkManager.is_active()` (single-player entirely unchanged). New wire format is pure, unit-testable helper in `game_logic/net/`. Headless import must pass after any `.gd` edit. HUD button sized viewport-relative (parity for mobile). No `.uid` sidecar issues since no new `.tres` resources created.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
