# GID-016: Mobile / Desktop Feature Parity Fixes

## Objective

Fix all identified gaps where features are missing, broken, or misleading on Android vs desktop.

## Context

Primary export target is Android. A codebase scan revealed five categories of parity issues: the merchant shop doesn't display cards on mobile (ScrollContainer height collapse), the inventory two-column layout collapses on portrait screens, VirtualJoystick uses fixed pixels for sizing, BattleScene card drag can only be cancelled via right-click, and two pieces of UI text reference keyboard keys on mobile.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-041 | Fix ShopScene portrait layout | agent | done | — |
| TID-042 | Fix InventoryScene portrait layout | agent | pending | — |
| TID-043 | Fix VirtualJoystick viewport-relative sizing | agent | pending | — |
| TID-044 | Add touch cancel for BattleScene card drag | agent | pending | — |
| TID-045 | Platform-aware UI text and inventory feedback | agent | pending | — |

## Acceptance Criteria

- [ ] Merchant shop displays all cards in a scrollable list on Android portrait
- [ ] Inventory Collection and Deck panels are both readable and scrollable on portrait phones
- [ ] VirtualJoystick buttons and joystick size correctly on all screen sizes
- [ ] Players can cancel a card drag on Android without right-clicking
- [ ] MapViewOverlay shows touch-appropriate close instructions on Android
- [ ] Inventory − button gives visible feedback on Android when deck is at minimum size
