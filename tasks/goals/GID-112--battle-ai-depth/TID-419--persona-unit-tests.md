# TID-419: Unit Tests for Lethal Check + Persona Decisions

**Goal:** GID-112
**Type:** agent
**Status:** done
**Depends On:** TID-416, TID-417

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Locks in the new behavior added across TID-415/416/417 with regression tests,
and confirms the `basic` persona still matches the pre-goal behavior exactly
(protecting Puzzle Battle Mode and any other implicit dependency on today's
exact AI ordering).

## Research Notes

- Existing file: `tests/unit/test_basic_ai.gd` (265 lines) — extend it rather
  than creating a new file. Test helpers already present: `_tmpl()`, `_card()`,
  `_state()`, `_ai_turn_state()` (see top of file). Follow the existing pattern
  of building a `GameState`, populating hand/board directly, calling
  `BasicAI.decide_turn`/`describe_turn`, executing returned Callables, and
  asserting on resulting state (`tests/framework/test_case.gd` base class).
- New cases needed:
  1. **Lethal check** — construct a state where the AI has enough board attack
     to drop the player hero to ≤0 this turn; assert `decide_turn` (any
     persona) produces actions that result in `state.opponent().hero.health <= 0`
     rather than following the persona's normal heuristic.
  2. **`basic` persona parity** — re-run (or keep) every existing test in the
     file with the persona explicitly set to `"basic"` and confirm identical
     outcomes to pre-goal behavior (this is the regression safety net for
     Puzzle Battle Mode, which never sets a persona and must default to
     `"basic"`).
  3. **`aggro` persona** — construct a board where a favorable trade is
     available; assert the aggro persona still attacks the hero (or the correct
     Ward target if one exists) rather than taking the trade.
  4. **`control` persona** — same setup; assert the control persona takes the
     favorable trade instead of face damage.
  5. **Ward targeting still mandatory for every persona** — reuse/extend
     whatever Ward test already exists (grep `WARD` in the current test file) to
     confirm `aggro`/`control` both still respect the Ward-only-target rule.
  6. **`describe_turn` tier wording** (depends on TID-418 also being complete) —
     assert tier-1 banner text still names the exact card/target; assert
     tier ≥ 2 banner text does not contain the exact target's name.
- Run `godot --headless --path . -s tests/runner.gd` per `CLAUDE.md` ("Running
  Tests: Installing Godot"). If the Godot binary is unavailable in-sandbox
  (established issue in this environment — network egress to the GitHub
  release download is blocked), say so explicitly in Changes Made rather than
  claiming verification, and trace the new/changed logic by hand against each
  test case instead (see TID-414's Changes Made for the established pattern of
  manual trace + explicit "not run headless" note).

## Plan

_Written during Plan phase._

## Changes Made

New suite `tests/unit/test_ai_personas.gd` — **23 tests**, all passing.
`test_basic_ai.gd` keeps covering persona-independent mechanics; this suite
covers only what personas and the lethal check change.

Written as **contrast pairs** wherever possible: the same board is driven by two
personas and must produce *different* outcomes. A persona test that passes under
every persona is not testing the persona, and that was the main risk here.

Coverage:

- Targeting contrast — basic trades with a minion; aggro on the identical board
  hits the hero and leaves the minion untouched; the no-argument call still
  behaves as basic (back-compat).
- Control trades — takes a favorable trade, skips an unfavorable one and
  pressures the hero instead, and trades down into a strictly bigger threat.
- Lethal — goes face past an available minion; the one-damage-short boundary
  case does *not*; damage is summed across several attackers; armor is counted,
  so 5 damage into 3 health behind 4 armor is correctly not lethal.
- Ward — blocks an otherwise-lethal line, binds aggro too, and outranks a softer
  non-Ward target.
- Hand order — aggro fields the bigger body from two equally-priced cards while
  basic takes the same hand in raw order; control develops a minion and holds
  the spell while basic casts the spell first from the identical hand.
- Banner — tier 1 names the card; tiers 2-4 never leak it; aggro and control
  read differently; the named target matches what the AI actually attacks; the
  "Enemy is thinking..." fallback.

One assertion failed on first run — the armor test expected the blocker at 8 HP
when 9 - 5 = 4. That was an error in the test's arithmetic, not the AI: the
implementation had correctly denied the lethal line and traded. Corrected.

## Verification

Headless import clean. Full suite **2236 passed / 0 failed** (up from 2213).
