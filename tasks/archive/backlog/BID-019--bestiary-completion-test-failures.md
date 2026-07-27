# BID-019: test_bestiary_completion suite has 8 failing tests

## Observed

Running `godot --headless --path . -s tests/runner.gd` produces 8 FAIL results
in the `test_bestiary_completion` suite:

- `test_bestiary_complete_when_all_defeated`
- `test_bestiary_complete_after_repeated_defeats`
- `test_bestiary_complete_rewarded_set_on_completion`
- `test_coins_awarded_on_completion` — expected >= 500, got 0
- `test_coins_awarded_exactly_500` — expected 500, got 0
- `test_soul_harvest_card_awarded_on_completion`
- `test_story_flag_bestiary_complete_set`
- `test_achievement_in_unlocked_achievements`

## Root cause

Unknown — bestiary completion reward logic may not be wired up or the test
setup is not correctly calling the completion trigger. Did not investigate
further during GID-063 as these failures are pre-existing.

## Fix

Investigate `game_logic/BestiaryCompletion.gd` (or equivalent) to confirm
whether coin award and achievement unlock are connected, and fix either the
implementation or the test setup.

## Discovered during

TID-225 (GID-063 gambits — reward multipliers + tests)
