# GID-034: Mobile-First UI Redesign

## Objective

Make every interactive element in the game comfortably usable on a phone: minimum touch targets, readable fonts, tap-and-hold card inspection, and a tutorial introducing that gesture.

## Context

Primary platform is Android. Playtesting revealed that buttons are too small to press reliably, body text is too small to read, and there is no way to inspect a card's full details without a dedicated UI button. This goal applies a mobile-first lens across all scenes: raises minimum touch targets and font sizes, adds long-press inspection to cards and items, and introduces a one-shot onboarding tutorial for that gesture.

Relevant CLAUDE.md guidance:
- Buttons minimum: 12–18% vh width × 5–6% vh height (current small buttons reach only ~3.8% vh)
- Font minimum: 2–2.5% vh (current tiny labels reach ~1.6% vh)
- Every feature must be reachable via touch

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-134 | UI Scale Audit & Global Size Increase | agent | done | — |
| TID-135 | Tap-and-Hold Long Press Detector Component | agent | pending | — |
| TID-136 | Card Inspect on Long Press (Battle, Inventory, Shop) | agent | pending | TID-135 |
| TID-137 | Tap-and-Hold Onboarding Tutorial | agent | pending | TID-135, TID-136 |
| TID-138 | Simplified Battle UI Layout | agent | pending | TID-134 |
| TID-139 | World HUD & Navigation Mobile Polish | agent | done | TID-134 |

## Acceptance Criteria

- [ ] Every tappable element is at least `vh * 0.065` tall and `vh * 0.10` wide
- [ ] Every body-text font is at least `vh * 0.025`; labels at least `vh * 0.022`
- [ ] Holding a card in battle hand, inventory, or shop for 500 ms shows the card detail overlay
- [ ] A one-shot tutorial popup ("Hold any card to inspect it") fires on first battle entry
- [ ] The in-game interact prompt is a visible tap button on mobile (not just "Press E" text)
- [ ] Coin, level, and XP labels in the world HUD are readable at arm's length on a phone
- [ ] No fixed-pixel `custom_minimum_size` values remain in any scene
