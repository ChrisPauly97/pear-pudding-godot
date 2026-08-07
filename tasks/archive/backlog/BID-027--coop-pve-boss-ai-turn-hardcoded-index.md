# BID-027: Co-op PvE boss AI turn execution hardcodes player index 1 (not fixed)

**Category:** code-smell
**Discovered During:** GID-102 / TID-371 (2v2 team duels) — while auditing other
hardcoded-2-player-index assumptions adjacent to BID-026.

## Summary

`BattleScene._run_ai_turn` / `_execute_ai_actions` hardcode `_state.players[1]`
throughout (board-diffing for emergence effects, weather application) when running the
AI's turn. This is invoked for the co-op-PvE **boss's** turn
(`_on_turn_ended`'s `elif player_idx == boss_idx: ... _run_ai_turn()` branch), but the
boss is never at index 1 in a valid co-op battle (allies occupy indices
`0..n_allies-1`, boss is at index `n_allies`, and `setup_coop_battle` clamps
`n_allies` to a 2..4 minimum, so the boss index is always ≥ 2). The board-diff/
emergence/weather logic in `_execute_ai_actions` would therefore read/write **ally-1's
board** instead of the boss's whenever the boss plays a minion with an emergence effect
or weather-sensitive entry, while `BasicAI.decide_turn(_state)` itself (pure logic
keyed off `_state.current_player_idx`) likely behaves correctly for the actual
attack/play decisions — only the post-action board-diff bookkeeping is index-hardcoded.

## Why not fixed in GID-102 / TID-371

Team PvP duels have **no AI participants** (all 4 players are human), so this code path
is never reached by the work in TID-371. Fixing it requires re-deriving `_execute_ai_actions`
to take the boss's actual index (or use `_state.current_player_idx` consistently) and
re-verifying the co-op-PvE boss-turn flow end-to-end — a separate, focused fix outside
this task's scope (BID-026 fixed the *adjacent* host/ally attack-resolution bugs, which
*are* on the team-PvP-reachable code path).

## Suggested fix

In `_run_ai_turn`/`_execute_ai_actions`, replace the hardcoded `1` with the boss's actual
index (`_state.players.size() - 1` when `_coop_pve`, else `1` for 2-player solo/duel —
mirrors the `_resolve_intent_opp_idx` pattern added for BID-026). Add a co-op-PvE smoke
test exercising a boss turn with ≥2 allies and an emergence-effect/weather-sensitive
minion in the boss's deck to catch regressions (see BID-026's "residual gap" note — both
bugs point at the same missing test coverage).

## Files

- `scenes/battle/BattleScene.gd` — `_run_ai_turn`, `_execute_ai_actions`

## Resolution

Fixed opportunistically alongside BID-025/BID-031.

**Deviation from the suggested fix:** the BID suggested deriving the index
inline as `_state.players.size() - 1 when _coop_pve, else 1`. Investigating
BID-026's actual fix (`_execute_attack`, `_apply_remote_intent`) turned up an
existing `_opp_idx()` accessor on `BattleScene` (added by BID-026/TID-371) that
already computes exactly this — "the local player's opponent": `players.size() -
1` when `_coop_pve` and `players.size() > 2`, a team-PvP-aware resolution, else
`1 - _local_player_idx`. `_run_ai_turn` only ever runs on the host authority
(gated by `_is_pvp_host()` in `_on_turn_ended`), and the host's
`_local_player_idx` is always `0` — so `_opp_idx()` already resolves to exactly
the AI's own index in every mode this code path can run in (`1` for solo/2-player,
the boss slot for co-op PvE). Reused it instead of re-deriving the same branch a
second time:

```gdscript
var ai_idx: int = _opp_idx()
var ai_board_before: Array[CardInstance] = _state.players[ai_idx].board.get_cards().duplicate()
actions[idx].call()
_resolver.flush_auto_spells(ai_idx)
for c: CardInstance in _state.players[ai_idx].board.get_cards():
    if not ai_board_before.has(c):
        _resolver.resolve_emergence(c, ai_idx)
        _apply_weather_to_summoned(c, ai_idx)
```

This is behavior-preserving for solo/2-player battles (`_opp_idx()` returns `1`
there, same as the old hardcode) and fixes the co-op-PvE case (the boss's own
board-diff/emergence/weather bookkeeping now reads/writes the boss's own player
slot instead of ally-1's).

**`_check_boss_phase2`** (also hardcodes `_state.players[1]`, for the boss-HP-based
phase-2 deck swap) was investigated and left untouched: `_check_game_over` returns
early for `_coop_pve` (routing to `battle_net._coop_pve_check_game_over()` instead)
before it ever reaches the `_check_boss_phase2()` call, so that hardcode is only
ever reached in solo battles where index `1` is always correct — not part of this
bug's reachable surface.

Added `tests/coop_pve_ai_turn_smoke.gd` — a standalone smoke test (not part of the
auto-discovered `tests/unit/` suite, for the same "needs a real BattleScene node
tree + real async wall-clock delay" reasons `net_pvp_smoke.gd`/`world_scene_smoke.gd`
stay standalone). It instantiates a real `BattleScene.tscn` co-op-PvE battle with 2
allies (boss at index 2, never 1) whose entire boss deck is `dusk_seer` (cost 3,
`emergence_draw` power 1), drives turns via `GameState.end_turn()` until the boss can
afford to play one, and asserts:
1. the boss sits at index >= 2 (never the hardcoded 1);
2. ally-1's hand/board are never mutated during any boss turn;
3. playing `dusk_seer` nets a **0** hand-size delta (−1 for the play, +1 from a
   correctly-resolved `emergence_draw`) — under the bug this nets **−1** because the
   diff was computed against ally-1's untouched board, so the emergence effect never
   fired at all.

Verified the test actually catches the regression: reverting the `BattleScene.gd`
fix and re-running the smoke test reproduces the `-1` delta and a `[FAIL]`; restoring
the fix returns it to `[PASS]`. Run on demand:
`godot --headless --path . -s tests/coop_pve_ai_turn_smoke.gd`.
