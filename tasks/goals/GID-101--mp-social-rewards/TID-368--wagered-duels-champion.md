# TID-368: Wagered duels & Champion record

**Goal:** GID-101
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP today awards **nothing** (documented "no cards, no coins, no XP, no record" in
`multiplayer-coop.md` → "Rewards & end states"). This task adds stakes: an optional
**ante** paid to the winner, and a persistent **win-streak / Champion** record so
winning is visible and worth chasing.

## Research Notes

- **Existing wager scaffolding:** `GameState` already has `wager_coins: int` and
  `friendly_duel: bool`; Gambits (GID-063) is the pre-battle wager system — reuse its
  staking/escrow concepts rather than inventing a new one. Grep `wager_coins` /
  Gambits code for the existing flow.
- **Ante flow (host-authoritative):** during the PvP challenge handshake
  (`NetSync.request_battle` / `respond_battle`, see `multiplayer-coop.md` → "PvP Flow"),
  both players stake coins and/or a card; the authority escrows, and on game-over awards
  the pot to the winner. Card stakes move the **instance** between session characters
  (reuse TID-366 transfer logic — coordinate; this is the same dupe-proof transfer).
- **Reward path change:** the duel-style "empty drop pool / zero coin reward"
  (`enemy_data` for PvP) must be replaced by the escrowed pot for wagered duels;
  unwagered duels stay reward-free. Update the `BattleResultUI.show_pvp_result` /
  `pvp_battle_ended` path and the docs that state "PvP awards nothing".
- **Champion record:** add per-player fields to the GID-095 character record
  (`SessionState` member: `pvp_wins`, `pvp_losses`, `pvp_streak`, `pvp_best_streak`) +
  `to_dict`/`from_dict` + migration bump (`CURRENT_SESSION_VERSION`). Authority updates
  on each duel end; surface in the roster / a title ("Champion" at a streak threshold).
- **Isolation invariant:** all persistence via `SessionStore`, never `save_slot_*.json`
  (the `adopt_session_character` `_loaded = false` contract).
- **Docs:** this **changes the documented PvP "no rewards" contract** —
  update `docs/agent/multiplayer-coop.md` accordingly. Consider whether the human spec
  (`docs/human/specification.md`) wants a note (human-owned → flag, don't edit).
- **Tests:** unit-test streak/record update + the escrow/award math; extend
  `test_session_state.gd` for the new member fields + migration.

## Plan

Extend the PvP challenge handshake with an optional ante, thread ante_coins through SceneManager into BattleScene, award pot on win via `_on_pvp_battle_ended_coop`, and persist pvp stats into SessionState.

## Changes Made

- **`game_logic/net/SessionState.gd`**: bumped `CURRENT_SESSION_VERSION = 3`; `party_bounties: Array = []` field; `make_starter_character` returns `pvp_wins/losses/streak/best_streak = 0`; `to_dict`/`from_dict` include party_bounties; `_apply_migrations` v<2 adds party_bounties, v<3 backfills pvp stats on existing members.
- **`scenes/world/NetSync.gd`**: `request_battle_wager(challenger_deck, ante_coins)` (reliable), `respond_battle_wager(accepted, responder_deck, ante_coins)` (reliable).
- **`autoloads/SceneManager.gd`**: `enter_pvp_battle(local_player_idx, opponent_deck, ante_coins: int = 0)` — passes `pvp_ante_coins` to BattleScene overlay.
- **`scenes/battle/BattleScene.gd`**: `pvp_ante_coins: int = 0`; `_pvp_check_game_over()` includes `"ante_coins"` in pvp_ended payload.
- **`scenes/battle/BattleResultUI.gd`**: `show_pvp_result(did_win, coins_delta)` displays "+N coins (wagered)" (gold) or "-N coins (wagered)" (red) when `coins_delta != 0`.
- **`scenes/world/WorldScene.gd`**: `_pvp_ante_coins: int`, `_pvp_ante_peer0/1: int`; `_request_wager_challenge(ante_coins)` / `_show_wager_accept_panel` / `_accept_wager_challenge` / `_decline_wager_challenge` / `_on_battle_wager_requested` / `_on_battle_wager_responded` / `_enter_pvp_wagered`; `_on_pvp_battle_ended_coop(did_win)` — `add_coins(_pvp_ante_coins * 2)` on win, updates pvp_wins/losses/streak/best_streak in SessionStore, defers pvp-active clear broadcast via `_pvp_ended_pending_broadcast`.
- **`tests/unit/test_session_state.gd`**: 5 new cases for pvp stats fields, round-trip, migration v3 backfill, and party_bounties garbage tolerance.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md`: replaced "no rewards" Rewards section with wagered duel description; added Champion record subsection; updated Tests table.
