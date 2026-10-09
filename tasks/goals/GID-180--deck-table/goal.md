# GID-180: Deck Table — Fun, Tactile Deck & Bag Management

## Objective

Make deck building and bag management intuitive and fun: a physical card table, a binder worth browsing, a forge, and selling as a moment at the vendor counter.

## Context

User request 2026-10-09: "deck management and inventory management has to be the most intuitive, fun thing ever." Brainstormed and approved scope: card table with juice, deck personality, binder, forge/combine ritual, never-lost loot, compare-by-hover, mentor barks, world loop (fly-in, badge, campfire). **Selling happens only at vendors** (user decision) — the bag offers Scrap and 'flag for sale'. Spec: cards are the atomic unit; deck must matter more (specification.md feature filter).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-736 | Pure logic: DeckInsights | agent | done | — |
| TID-737 | Card table layout + auto-save/undo | agent | done | — |
| TID-738 | Drag juice: lift, snap, sounds, sparkle | agent | done | TID-737 |
| TID-739 | Binder: stacks, pages, silhouettes, shimmer, gilding | agent | done | TID-736, TID-737 |
| TID-740 | Deck personality: name, crest, synergy threads, skyline, test hand | agent | pending | TID-736, TID-737 |
| TID-741 | Compare on hover, upgrade dot, Best deck button | agent | pending | TID-736, TID-738 |
| TID-742 | Forge: scrap + combine ritual; flag for sale replaces Sell | agent | pending | TID-737, TID-738 |
| TID-743 | Never lose loot + overstuffed satchel | agent | pending | TID-737 |
| TID-744 | Maiteln deck barks in the builder | agent | pending | TID-736, TID-737 |
| TID-745 | Vendor counter: slide-to-sell, reactions, coin pile, Sell basket | agent | pending | TID-742 |
| TID-746 | Vendor magic-type preferences + buyback shelf | agent | pending | TID-745 |
| TID-747 | World loop: fly-in new cards, HUD bag badge, campfire table | agent | pending | TID-737, TID-739 |

## Acceptance Criteria

- [ ] One-screen card table; tap/drag add/remove; auto-save with undo; no Save Deck button
- [ ] Drag feels physical (lift, snap, sounds, rarity sparkle)
- [ ] Binder with stacks, magic-type pages, silhouettes, perfect-roll shimmer, veterancy gilding
- [ ] Live deck name/crest, synergy threads, curve skyline, test hand
- [ ] Compare on hover + upgrade dot + Best deck
- [ ] Forge scrap + combine ritual; no Sell in the bag; flag-for-sale
- [ ] Loot never lost; satchel + companion grumble
- [ ] Maiteln deck barks
- [ ] Vendor counter with reactions, Sell basket, town preferences, buyback
- [ ] New-card fly-in, HUD badge, campfire opens deck table
- [ ] All tests, gdlint, unsafe-hits clean; desktop + touch parity
