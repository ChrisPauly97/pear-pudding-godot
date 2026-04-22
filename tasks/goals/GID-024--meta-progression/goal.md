# GID-024: Meta-Progression

## Objective

Add an achievement milestone system, special legendary cards unlockable via achievements, and a post-session summary screen.

## Context

The game has no long-term goals beyond completing Chapter 1. Standard cards are always available; there is nothing to work toward. This goal adds a lightweight achievement system with milestone tracking, a small set of Legendary cards (5–8) gated behind achievements, and a summary screen shown on returning to menu. Standard cards (existing + GID-018 Dawn/Dusk) remain always available.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-082 | Achievement data model and SaveManager integration | agent | done | — |
| TID-083 | Achievement UI — toast notification and list screen | agent | done | TID-082 |
| TID-084 | Legendary card unlock progression | agent | done | TID-082 |
| TID-085 | Run summary screen | agent | done | — |

## Acceptance Criteria

- [x] Achievement milestones are defined and tracked in SaveManager
- [x] Unlocking an achievement shows a toast notification in-game
- [x] An achievement list is accessible from the main menu
- [x] 5 Legendary cards exist; they only appear in shop after their unlock achievement is met
- [x] Standard cards are unaffected — always available
- [x] A summary screen appears when returning to menu showing session stats
- [x] Pre-existing test failures unchanged (test_card_registry failures were pre-existing)
