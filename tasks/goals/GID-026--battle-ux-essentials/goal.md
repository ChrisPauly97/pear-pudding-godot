# GID-026: Battle UX Essentials

## Objective

Add the three table-stakes UX features missing from battle: card inspect overlay, settings menu with volume controls, and pause functionality.

## Context

These are baseline expectations for any card game on mobile. Without card inspect, players on touchscreens cannot read a card once it leaves their hand. Without settings, there is no way to adjust volume. Without pause, any interruption during battle is unrecoverable.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-086 | Card inspect overlay (tap-to-inspect during battle) | agent | pending | — |
| TID-087 | Settings menu with volume sliders | agent | pending | — |
| TID-088 | Pause during battle | agent | pending | — |

## Acceptance Criteria

- [ ] Tapping/clicking any card in hand, on board, or in the enemy's board opens an inspect overlay showing full card details
- [ ] Inspect overlay is dismissible by tapping outside or pressing a close button
- [ ] Settings menu accessible from main menu and from battle pause screen
- [ ] Settings menu has separate sliders for music volume and SFX volume; values persist in SaveManager
- [ ] Battle can be paused; pause menu offers Resume and Return to Menu options
- [ ] All tests pass headless
