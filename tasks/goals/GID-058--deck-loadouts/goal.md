# GID-058: Deck Loadouts

## Objective

Multiple named deck loadouts the player can build, rename, and swap between instantly, replacing the single-deck limitation.

## Context

With 50+ goals of card content (rarities, keywords, effects, dawn/dusk branches), one deck slot forces tedious rebuilds to try new strategies. Loadouts are a pure QoL multiplier on every battle feature that already exists. A card instance may appear in several loadouts; selling or combining it prunes it from all of them.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-210 | Loadout model: named deck lists in SaveManager, active index, migration from single deck, prune-on-sale | agent | pending | — |
| TID-211 | Deck builder loadout UI: selector, new/rename/duplicate/delete, validation per loadout | agent | pending | TID-210 |

## Acceptance Criteria

- [ ] SaveManager stores up to 5 named loadouts (each a list referencing owned card instances) plus an active-loadout index; existing saves migrate their single deck into "Deck 1" with no data loss
- [ ] Battles always use the active loadout; switching the active loadout is instant and persists
- [ ] Selling, scrapping, or combining a card instance removes it from every loadout that references it (extending the existing single-deck pruning), and a loadout dropped below the 5-card minimum is flagged invalid — battles are blocked on an invalid active loadout with clear feedback (same UX as the existing GID-003 validation)
- [ ] The deck builder gains a loadout selector (tabs or dropdown) with New / Rename / Duplicate / Delete actions; Delete requires a confirm; the last remaining loadout cannot be deleted; rename uses a text input that works on Android (cite the virtual keyboard behavior of LineEdit)
- [ ] All controls are touch-operable with viewport-relative sizing (mobile parity per CLAUDE.md)
- [ ] All tests pass headless
