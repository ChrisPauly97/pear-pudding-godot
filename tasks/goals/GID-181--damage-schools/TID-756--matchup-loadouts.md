# TID-756: Matchup loadouts: quick deck swap before a fight

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-753

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Horizontal progression only pays off if switching to the right deck is quick. Players keep several decks and pick one for a matchup.

## Research Notes

- Loadouts exist: `autoloads/save_manager/SaveLoadouts.gd` (`save_manager.decks`), deck table UI from GID-180 (scenes/ui deck builder). Allow naming/tagging a loadout with a school.
- Hook point: the engage → battle gap. `SceneManager.accepts_engage()` / gambit picker (see CLAUDE.md bug learnings on pending UI steps needing a busy flag). Add a small 'Swap deck' row to the gambit/engage prompt showing the enemy's known weak schools (from TID-753) and the player's loadouts, with the best-matching one highlighted.
- Must work with gambits off (auto-skip) — then offer it on the world HUD via `register_action` (ZONE_CONTEXT) when an enemy is targeted/nearby, not a bare Button (HUD registry guardrail).
- Mobile parity: tap targets; desktop: number keys optional.

## Plan

1. Pure scorer `game_logic/battle/LoadoutMatchup.gd`: weak-hit count, resist tie-break, best index; unit tests.
2. Shared row `scenes/ui/LoadoutSwapRow.gd` over the known profile (`SchoolKnowledge.journal_view`), chips and star.
3. Gambit picker shows the row; SceneManager passes the engaged enemy type. Picking sets the active loadout.
4. Auto-skip path: `SwapDeckPrompt` world module, HUD action in ZONE_CONTEXT when a hostile enemy is in awareness range; modal holds engage.
5. Docs in damage-schools and inventory-and-deck.

## Changes Made

- `game_logic/battle/LoadoutMatchup.gd` (new, pure): `weak_hits`, `resist_hits`, `rank`, `best_index`.
  Score = cards whose school the enemy is weak to. Ties: fewer resisted-school cards, then lower index.
  Invalid loadouts are ranked but never best; an unknown profile highlights nothing.
- `scenes/ui/LoadoutSwapRow.gd` (new, RefCounted): loadout buttons (star on best, disabled on active /
  too-small), weak-school colour chips, "Defeat one to learn its weaknesses" when unknown. Picking calls
  `decks.set_active_loadout` and rebuilds.
- `scenes/battle/GambitPickerOverlay.gd`: `matchup_enemy_type`; row above the gambit list (flow wrap).
- `autoloads/SceneManager.gd`: passes `engaged_enemy_type` to the picker; `hold_engage()` / `release_engage()`
  counter checked first in `accepts_engage()`.
- `scenes/world/modules/SwapDeckPrompt.gd` (new, module `SwapDeckPrompt`): proximity check every 0.25 s,
  "Swap deck" in ZONE_CONTEXT via `register_action`, modal via `_build_prompt` that holds engage while open.
- `scenes/world/WorldScene.gd`: preload and module creation line (kept at the 1890-line ceiling; no field).
- `tests/unit/test_loadout_matchup.gd` (new).

Deviations: the task text says "weak/resisted" for the score. Implemented as weak hits only, with resisted
cards as a tie-break, since a resisted school is never a good match. Loadout school tagging in the deck
builder was not built (not in the Build section).

Validation: parse check clean, `unsafe-hits.sh` clean, gdlint clean on changed files, `tests/runner.gd`
exit 0 with 0 SCRIPT ERROR, all 33 `tests/*smoke*.gd` exit 0 with 0 SCRIPT ERROR, `balance_bands.gd` exit 0.

## Documentation Updates

- `docs/agent/damage-schools.md`: new "Matchup Loadouts (TID-756)" section (scorer, row, picker, auto-skip
  module, engage hold, deviations).
- `docs/agent/inventory-and-deck.md`: "Matchup Swap Row (TID-756)" under Deck Loadouts.
