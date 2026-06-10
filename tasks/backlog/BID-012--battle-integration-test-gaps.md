# BID-012: No BattleScene-level tests for keywords, AI corruption paths, or dead hero ticks

**Category:** doc-gap
**Discovered During:** GID-064 audit

## Description

The battle unit tests (test_basic_ai, test_game_state, test_player_state,
test_hero_state, test_card_instance, test_status_effects, test_zone_state) cover pure
logic only. Nothing exercises Ward/Surge/Shroud at the BattleScene level, the BasicAI
double-discard corruption scenario (fixed in TID-232 — a regression test is added
there, but broader AI-plan/execute coverage is still missing), or spell resolution.

Related dead paths found during the audit: hero `freeze`/`stun` tick handling
(BattleScene.gd:1665-1678, PlayerState.gd:65) is unreachable — no effect ever applies
freeze/stun to a hero; `ZoneState.snapshot/restore_snapshot` (ZoneState.gd:46-50) is
used only by tests. Decide whether to wire hero freeze/stun to a future card or delete
the paths.

## Evidence

See file:line references above; tests/ directory suite list in tests/runner.gd.

## Suggested Resolution

A battle-integration test suite that instantiates BattleScene headless, scripts a few
turns, and asserts keyword interactions and spell effects. Pair with a decision on the
unreachable hero freeze/stun paths.
