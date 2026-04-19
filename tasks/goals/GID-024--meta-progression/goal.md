# GID-024: Meta-Progression

## Objective

Add an achievement milestone system, special legendary cards unlockable via achievements, and a post-session summary screen.

## Context

The game has no long-term goals beyond completing Chapter 1. Standard cards are always available; there is nothing to work toward. This goal adds a lightweight achievement system with milestone tracking, a small set of Legendary cards (5–8) gated behind achievements, and a summary screen shown on returning to menu. Standard cards (existing + GID-018 Dawn/Dusk) remain always available.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-082 | Achievement data model and SaveManager integration | agent | pending | — |
| TID-083 | Achievement UI — toast notification and list screen | agent | pending | TID-082 |
| TID-084 | Legendary card unlock progression | agent | pending | TID-082 |
| TID-085 | Run summary screen | agent | pending | — |

## Acceptance Criteria

- [ ] Achievement milestones are defined and tracked in SaveManager
- [ ] Unlocking an achievement shows a toast notification in-game
- [ ] An achievement list is accessible from the main menu
- [ ] 5–8 Legendary cards exist; they only appear in shop/drops after their unlock achievement is met
- [ ] Standard cards are unaffected — always available
- [ ] A summary overlay appears when returning to menu showing session stats
- [ ] All tests pass headless
