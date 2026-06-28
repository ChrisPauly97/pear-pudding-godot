# TID-368: Wagered duels & Champion record

**Goal:** GID-101
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
