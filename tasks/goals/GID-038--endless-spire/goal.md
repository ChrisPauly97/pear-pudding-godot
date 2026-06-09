# GID-038: The Endless Spire — Roguelike Draft Mode

## Objective

A repeatable run mode: enter a tower, fight one enemy per floor, draft one of three cards between floors, and climb until death — with run stats shown on the existing run summary screen.

## Context

The game has deep systems but no repeatable content loop beyond wandering the infinite world. A draft-based climb is the biggest replayability multiplier available, and it is cheap here: DungeonGen, the boss framework (TID-070), EnemyRegistry, and RunSummaryScene all already exist. The drafted deck is run-local — it never touches the player's permanent collection, so it cannot break the economy.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-146 | Spire run state model + SaveManager migration | agent | pending | — |
| TID-147 | Card draft logic + draft pick UI | agent | pending | TID-146 |
| TID-148 | Spire floor scene + enemy difficulty scaling | agent | pending | TID-146 |
| TID-149 | Spire entrance door + SceneManager routing | agent | pending | TID-148 |
| TID-150 | Death/exit flow + run summary integration | agent | pending | TID-147, TID-148 |

## Acceptance Criteria

- [ ] `SaveManager.spire_run` persists an active run (floor, draft deck, hp, seed) across app restarts, with migration for old saves
- [ ] After each floor victory, a draft UI offers 3 cards weighted by floor depth; the pick joins the run-local deck only
- [ ] Each floor spawns one enemy scaled by floor number (floors 1–3 common, 4–6 uncommon, 7+ boss-tier)
- [ ] A door in a named map enters the Spire; quitting mid-run resumes at the same floor
- [ ] Death ends the run, discards the draft deck, and shows RunSummaryScene with floors cleared and cards drafted
- [ ] All tests pass headless
