# TID-278: Stale test fixes

**Goal:** GID-075
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The card-registry test asserts a hardcoded count that drifted as cards were added and removed; resolves BID-007. Tests should validate logic robustly, not hardcode registry counts that change every time a card is created. This task also sweeps for other stale assertions across the test suite.

## Research Notes

### Primary issue: CardRegistry test assertion
- **File:** `tests/unit/test_card_registry.gd:25–26`
- **Assertion:** `test_get_all_ids_returns_forty_default_cards` asserts `_registry.get_all_ids().size() == 40`
- **Actual count:** CardRegistry.gd defines 46–47 preloaded cards (two sweeps counted 46 and 47 — count the `const _C_*` declarations, lines 3–51, to get the true number)
- **Status:** Expected to FAIL on next test run (if it currently passes, investigate why — maybe `get_all_ids()` filters)
- **Fix:** Rename the test (drop "forty") and prefer a robust assertion: either assert the count matches the number of preload consts programmatically, or assert >= some floor plus uniqueness of ids, so the test stops drifting every time a card is added

### Sweep all test files for stale counts
- **Pattern:** Hardcoded counts/ids referencing registries (enemies, skills, weapons, scrolls, maps)
- **Search:** `ls tests/unit/` and grep for `assert_eq` with integer literals near registry calls
- **Fix each:** Replace magic numbers with programmatic assertions or robust floor assertions with a comment explaining the intent

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
