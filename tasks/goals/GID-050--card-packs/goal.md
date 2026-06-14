# GID-050: Card Packs & Pack Opening

## Objective

Sealed card packs sold by merchants, opened in a tap-to-flip reveal ceremony, with a persisted legendary pity counter.

## Context

The shop sells single known cards; packs add the gambling thrill that makes TCG economies tick, and the flip-reveal ceremony is the fun part. Rarity and stat rolls reuse `CardDropUtil` from GID-028 — no new roll logic.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-185 | Pack data model (tiers, prices, rarity weights via CardDropUtil) + shop integration | agent | done | — |
| TID-186 | Pack opening ceremony UI: tap-to-flip reveals with rarity flair | agent | done | TID-185 |
| TID-187 | Legendary pity counter (guaranteed within N packs), persisted with migration | agent | done | TID-185 |

## Acceptance Criteria

- [ ] Two pack tiers exist (e.g. Standard 120 coins / Premium 300 coins), each granting 3 cards rolled via CardDropUtil with tier-appropriate rarity weights; buying a pack from the merchant deducts coins and queues the pack for opening
- [ ] The pack opening scene shows 3 face-down cards; tapping each flips it with rarity-coloured flair (higher rarity = bigger flourish); a Skip/Reveal-all control exists; cards land in owned_cards as normal instances
- [ ] Premium packs guarantee at least one rare-or-better card
- [ ] A pity counter persists in SaveManager (with migration): if no legendary in 20 consecutive packs, the next pack's best slot is forced legendary and the counter resets
- [ ] Everything is touch-first and viewport-relative (mobile parity per CLAUDE.md)
- [ ] All tests pass headless
