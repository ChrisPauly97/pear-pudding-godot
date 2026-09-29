# BID-074: Veterancy is never taught or announced

**Category:** content-gap
**Discovered During:** backlog pass over `docs/agent/game-appeal.md` §7 (2026-09-29)

## Description

`game-appeal.md` §7 left veterancy teaching "deliberately deferred — surfacing it at first rank-up would be a
separate, later task." A card silently gained a title and chevrons; nothing said why.

## Resolution

- `SaveManager.record_veterancy()` now returns the card's new rank when a fight pushes it up one (else 0).
- `BattleVictory._announce_rank_up()` shows a "Veteran! Ghost the Seasoned ▲" toast and emits
  `tutorial_popup_requested("veterancy")` — a new `TutorialRegistry` entry, shown once.
- Test: `test_veterancy_attribution` → `test_record_veterancy_reports_a_rank_up_once`.
