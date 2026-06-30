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
