# GID-065: Card Cantrips — Your Deck Shapes the World

## Objective

The deck grants overworld abilities — each card family unlocks a small exploration "cantrip" when the player carries enough copies, making deck building an exploration choice.

## Context

The game's unique identity is TCG-meets-overworld, but currently the deck only matters in battle. This goal brings deck composition into exploration gameplay, letting players unlock shortcuts (Ghost Phase), gather resources (Skeleton Dig), and feel rewarded for their card choices. Cantrips are distinct from pending goals like GID-043 (Treasure Maps — directed map-following) and GID-048 (Mounts — persistent travel abilities); they are immediate, threshold-based, and flavor the active deck.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-238 | Cantrip Framework — Deck-Derived Abilities, HUD Button + Key Binding | agent | pending | — |
| TID-239 | Ghost Phase — One-Tile Wall Pass | agent | pending | TID-238 |
| TID-240 | Skeleton Dig — Burial Mounds + Dig Rewards | agent | pending | TID-238 |

## Acceptance Criteria

- [ ] Cantrip availability is derived from current deck contents (≥N card copies per family)
- [ ] HUD cantrip button + key binding (M, D, S for Ghost/Dig/etc.) work on desktop and mobile
- [ ] Ghost Phase lets the player cross exactly one wall tile with cooldown feedback
- [ ] Skeleton Dig works at burial mounds spawned in chunks and grants coins/cards/equipment
- [ ] Cantrip state (cooldowns, dug mounds) persists across save/load via SaveManager
- [ ] All core tests pass
