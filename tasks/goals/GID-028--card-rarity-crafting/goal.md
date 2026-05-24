# GID-028: Card Rarity, Crafting & Economy

## Objective

Add per-instance card rarity (common → legendary), randomised stat rolls within rarity ranges, a sell/scrap economy, card combining, a crafting screen, and enemy difficulty-based rarity scaling on drops.

## Context

Cards are currently flat templates — every copy of "Ghost" is identical. This goal introduces meaningful collection depth: the same card can drop at different rarities with different stat rolls, letting players chase higher-tier copies. Selling/scrapping and crafting add deliberate progression levers. Enemy difficulty already has a tier ladder; this goal makes that ladder affect card quality.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-097 | Rarity data model — extend CardData with per-rarity stat ranges and craftability flag | agent | done | — |
| TID-098 | Owned card instances + save migration v9→v10 | agent | pending | TID-097 |
| TID-099 | Rarity-weighted card drops (battles & chests) | agent | pending | TID-097 |
| TID-100 | Inventory rarity display & per-instance stat readout | agent | pending | TID-098 |
| TID-101 | Sell & scrap actions (gold + essence) | agent | pending | TID-100 |
| TID-102 | Card combining (3× same rarity → 1× next rarity) | agent | pending | TID-100 |
| TID-103 | Crafting recipes data model | agent | pending | TID-097 |
| TID-104 | Crafting screen UI | agent | pending | TID-101, TID-103 |
| TID-105 | Enemy deck rarity scaling by difficulty tier | agent | pending | TID-097, TID-099 |

## Acceptance Criteria

- [ ] CardData has per-rarity stat ranges; legendary cards have ranges but no common/rare/epic variants; unique cards are flagged
- [ ] owned_cards saves per-instance data (uid, template_id, rarity, rolled attack, health, cost)
- [ ] Old saves migrate cleanly to v10 with common-rarity instances at base stats
- [ ] Card drops roll a rarity based on enemy difficulty / chest tier; stats are drawn from the rolled rarity's range
- [ ] Inventory shows each card instance with rarity badge, rolled stats, and (min–max) range annotation
- [ ] Player can sell any card for gold or scrap it for essence
- [ ] Player can combine 3× copies of the same template+rarity into 1× next-rarity instance
- [ ] Crafting screen lists all craftable recipes with essence cost; craft button produces a fresh stat-rolled instance
- [ ] Cards flagged can_craft=false are absent from all crafting recipes
- [ ] Harder enemies drop rarer cards; their battle decks use higher-tier stat rolls
