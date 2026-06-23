# TID-332: PvP result, rewards policy & disconnect forfeit

**Goal:** GID-091
**Type:** agent
**Status:** pending
**Depends On:** TID-331

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Closes the PvP loop: a synced, duel-style end-of-battle (no card/coin rewards, no
enemy-defeat tracking), shown correctly on both peers, plus robust handling of a
mid-battle disconnect as a forfeit. Also the regression guard that single-player /
NPC / duel / puzzle / Spire battles are untouched.

## Research Notes

**Rewards policy = duel-style.** Model the PvP outcome on Friendly Duel Mode
(TID-143, `docs/agent/battle-system.md` "Friendly Duel Mode"): duels bypass the
normal `battle_won`/`battle_lost` reward path, award no cards/XP, and don't mark
enemies defeated. PvP goes further: **no coin transfer either** (we chose no
wager). Reuse the duel branch structure in `BattleScene._check_game_over()` as the
template, but add a `_pvp` branch that:
- Determines the winner from `_state.winner()` (host is authority; the result is
  in the broadcast mirror so both peers agree).
- Shows a synced victory/defeat overlay (host wins → host shows victory, client
  shows defeat, and vice-versa). Reuse `BattleResultUI` with a minimal PvP overlay
  (no reward card, no rarity, no coins) — likely a new
  `BattleResultUI.show_pvp_result(did_win)` or pass flags to suppress rewards.
- Emits a PvP-specific completion that `SceneManager` handles by restoring the
  shared world (NOT GameOverScene, NOT card rewards) — mirror how
  `duel_won`/`duel_lost` are handled (`SceneManager` just restores the world). Add
  `GameBus.pvp_battle_ended(did_win)` or reuse the duel signals if their side
  effects are acceptable (duel adjusts coins — so a dedicated signal is cleaner).

**End-of-battle sync.** `_check_game_over()` runs on the host against the canonical
state. The host detects the winner, broadcasts a final `sync_state` (so boards
agree), then sends `pvp_ended` (TID-329 relay) carrying the winner so the client
shows the correct overlay even though the client never computed game-over itself.
Guard against double-firing (both the mirror's implied game-over and the explicit
`pvp_ended`).

**Flee / surrender.** The pause menu's "Flee Battle" (`BattlePauseUI`,
`GameBus.battle_fled`) must, in PvP, become a **surrender**: send a `surrender`
intent (TID-328); the host marks that player as the loser, broadcasts the end, and
both return to the world. Don't use the single-player flee path (which just
restores the world with no opponent notification).

**Disconnect = forfeit.** While in a PvP battle, connect to
`NetworkManager.peer_disconnected` / `session_ended`:
- If the **opponent** drops, the remaining player wins by forfeit — show the PvP
  victory overlay and restore the world (now solo, or back to menu if the whole
  session ended). If `session_ended` (the remaining player is the client and the
  host vanished), there is no world session to return to → route to menu cleanly.
- If the **local** player is the one leaving (app background / quit), no special
  handling needed beyond existing teardown; the opponent's disconnect handler
  fires on their side.
- Ensure these signals are disconnected on battle exit to avoid dangling handlers
  (follow the `_teardown_coop` defensiveness pattern).

**Regression guard (must verify).** Re-run the full suite and a headless import.
Manually reason through: single-player battle (`_pvp == false`,
`_local_player_idx == 0`) hits zero new code paths; NPC duel, puzzle, Spire, and
boss flows unchanged. The `_pvp` branch in `_check_game_over` must be additive and
not alter the existing duel/puzzle/regular ordering.

**CLAUDE.md:** guard by `_pvp`; preload; explicit types; headless import; mobile
parity for any new buttons (the surrender prompt already exists via the pause UI).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
