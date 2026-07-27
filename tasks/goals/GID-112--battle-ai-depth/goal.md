# GID-112: Battle AI Depth — Enemy Personas & Real Decision-Making

## Objective

Rework `BasicAI` so different enemy types play with genuinely different tactics
and stop always checking for lethal never being computed, so the core battle
loop feels like a real opponent instead of a solved puzzle — without losing the
Enemy Intent banner's teaching value for new players.

## Context

`ai/BasicAI.gd` is a single static strategy shared by every enemy in the game:
`decide_turn`/`describe_turn` always play the cheapest affordable card first and
always attack the lowest-HP target (falling back to Ward-target filtering).
There is no lethal check anywhere in the AI — it can be one attack away from
killing the player's hero and never notice. Across 111 shipped goals, huge card
depth has been layered on top (keywords, spells, status effects, gambits,
dual-faced cards, veterancy) but every enemy — from a tier-1 Undead Wanderer to
a boss — is piloted by the exact same greedy brain, differing only in deck
composition (`EnemyRegistry._enemies[...]["deck"]`). The Enemy Intent banner
(`BasicAI.describe_turn`, shown via `BattleFx.show_intent_banner` from
`BattleScene._run_ai_turn()`, `scenes/battle/BattleScene.gd:1873-1874`) also
tells the player its exact next card/target every turn, which is valuable for
teaching (tier-1 fights) but removes all tension once a player understands the
system.

User decision (this goal's approval): keep the banner's exact wording for
tutorial-tier (`difficulty_tier == 1`) enemies; only scale it down for tier ≥ 2.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-415 | AI persona framework + shared lethal check in BasicAI | agent | done | — |
| TID-416 | Implement Aggro / Control persona decision logic | agent | done | TID-415 |
| TID-417 | Assign personas per enemy type/boss/rival + doc update | agent | done | TID-416 |
| TID-418 | Scale Enemy Intent banner specificity by difficulty tier | agent | done | TID-417 |
| TID-419 | Unit tests for lethal check + persona decisions | agent | done | TID-416, TID-417 |

## Acceptance Criteria

- [x] `BasicAI` supports at least three personas (`basic`, `aggro`, `control`) selected per enemy via `enemy_data`/`EnemyRegistry`, without changing the deferred-Callable execution pattern that avoids double-discard bugs.
- [x] All personas check for lethal (a sequence of plays/attacks that can drop the player hero to ≤0 this turn) before falling back to their normal heuristic, and take it when available.
- [x] Every enemy type in `EnemyRegistry` (including duelists, bosses, rivals, roaming boss) has an assigned persona reflecting its lore/role, documented in `docs/agent/battle-system.md` and `docs/agent/enemies-and-npcs.md`.
- [x] Enemy Intent banner keeps exact card/target wording for `difficulty_tier == 1` enemies; tier ≥ 2 enemies show vaguer, persona-flavored text that doesn't reveal the exact target.
- [x] `tests/unit/test_basic_ai.gd` covers lethal detection and each persona's distinguishing behavior; existing tests (puzzle mode, `basic` persona parity with old behavior) still pass.
- [x] PvP battles (`_pvp` guarded, AI disabled entirely) and Puzzle Battle Mode (AI turn skipped) are unaffected — confirm no new code path executes for either.

## Completion Note

TID-415 through TID-418 were implemented in a sub-session that was terminated
mid-task by an account spend limit. The parent session verified the delivered
code (clean headless import, suite green, `_has_lethal` confirmed wired into
`_pick_attack_target`, `GameBus` emissions from GID-124/TID-468 preserved), then
completed the outstanding work itself: TID-419's test suite, the
`docs/agent/enemies-and-npcs.md` persona table, and this bookkeeping.

Acceptance criterion 6 was verified by reading every `_run_ai_turn()` call site:
the solo path returns early on `if _pvp`, both non-boss call sites are guarded on
`not _state.puzzle_mode`, and the co-op boss path additionally requires
`_is_pvp_host()`. No new code path executes for PvP or Puzzle mode.

Final: headless import clean, **2236 passed / 0 failed** (2213 before TID-419).
