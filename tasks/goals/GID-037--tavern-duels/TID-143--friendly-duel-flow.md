# TID-143: Friendly Duel Battle Flow

**Goal:** GID-037
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battles currently assume the opponent is a hostile enemy: winning sets defeat flags, drops cards, and removes the enemy from the world. A friendly duel needs a parallel mode — same battle overlay, but the stakes are a coin wager and nothing in the world changes. This task builds the mode flag and wager resolution; TID-144 attaches it to NPCs.

## Research Notes

- `game_logic/battle/GameState.gd` — add `friendly_duel: bool` (default false) and `wager_coins: int`. When true, suppress story-defeat side effects on battle end.
- `autoloads/GameBus.gd` — `battle_requested(enemy_data)` signal exists. Either add an optional `friendly: bool` arg or a new `duel_requested(enemy_data, wager)` signal — prefer the new signal to avoid touching every existing emitter.
- `scenes/battle/BattleScene.gd` — battle-end handler is where win/loss currently triggers `coin_reward` and drop pools (GID-002, GID-007 patterns). In duel mode: win → player gains `wager_coins`; loss → player loses `wager_coins` (floor at 0).
- `autoloads/SaveManager.gd` — coins field exists from GID-007 (check exact name, likely `coins`). No new fields in this task.
- **Duelist decks:** Reuse `EnemyData` with empty `drop_pool` and `coin_reward = 0` (wager handled separately by duel mode). Create 2–3 duelist EnemyData `.tres` files in `data/enemies/` with `.uid` sidecars, e.g. `duelist_novice`, `duelist_adept`. Follow the preload-constant rule in `EnemyRegistry.gd`.
- **Loss handling:** A duel loss must NOT trigger GameOverScene — the player just loses the wager and returns to the world. Check how `BattleScene` routes hero death; branch on `friendly_duel`.
- `docs/agent/battle-system.md` — document the duel mode flag and end-of-battle branching.

## Plan

1. `GameBus.gd` — add `duel_requested(enemy_data, wager)`, `duel_won()`, `duel_lost()` signals.
2. `GameState.gd` — add `friendly_duel: bool` and `wager_coins: int`; update `to_dict`/`from_dict`.
3. `BattleScene.gd` — add `duel_wager: int` property; branch in `_check_game_over()` so duel wins show a wager-gain overlay (emits `duel_won`) and duel losses show a wager-loss overlay (emits `duel_lost`) — skipping the normal GameOver flow.
4. `SceneManager.gd` — handle `duel_requested` (launches battle with duel flag, no pending_battle save, no deck tutorial), `duel_won` and `duel_lost` (restore world only, no rewards/GameOver).
5. Create `data/enemies/duelist_novice.tres` and `duelist_adept.tres` (+ uid sidecars).
6. Update `docs/agent/battle-system.md`.

## Changes Made

- `autoloads/GameBus.gd` — added `duel_requested`, `duel_won`, `duel_lost` signals.
- `game_logic/battle/GameState.gd` — added `friendly_duel: bool` and `wager_coins: int`; updated `to_dict`/`from_dict`.
- `scenes/battle/BattleScene.gd` — added `duel_wager: int` property; `_ready()` copies it to state; `_check_game_over()` branches into `_show_duel_victory_overlay` / `_show_duel_loss_overlay` when `_state.friendly_duel`; both overlays handle coin transfer before emitting signals.
- `autoloads/SceneManager.gd` — wired `duel_requested` / `duel_won` / `duel_lost` signals; added `_on_duel_requested`, `_on_duel_won`, `_on_duel_lost` handlers (world restore, no rewards, no GameOver).
- `data/enemies/duelist_novice.tres` + `.uid` — Novice Duelist, tier 1, 10-card deck.
- `data/enemies/duelist_adept.tres` + `.uid` — Adept Duelist, tier 2, 12-card deck.

## Documentation Updates

- `docs/agent/battle-system.md` — added "Friendly Duel Mode (TID-143)" section covering signals, GameState fields, end-of-battle branching, and duelist enemy types.
