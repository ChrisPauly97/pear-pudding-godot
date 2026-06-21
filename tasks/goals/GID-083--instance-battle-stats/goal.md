# GID-083: Instance-Level Battle Stats

## Objective

Wire per-instance rolled card stats (attack, health, cost) into battle so that rarity upgrades actually affect combat performance.

## Context

GID-028 introduced per-instance card rarity with rolled stats stored in `owned_cards` (`uid, template_id, rarity, attack, health, cost`), but `BattleScene._ready()` builds the player deck via `SaveManager.get_deck_template_ids()` which strips instance UIDs down to template strings. `PlayerState.build_deck()` then creates fresh `CardInstance`s from base registry templates. A legendary Ghost with rolled +2/+2 fights with base Ghost stats — rarity rolls have zero gameplay impact. `SaveManager.get_deck_instances()` exists but has zero callers. (BID-005)

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-302 | Wire get_deck_instances() into BattleScene and PlayerState | agent | pending | — |

## Acceptance Criteria

- [ ] Player deck in battle uses per-instance rolled attack/health/cost from `owned_cards`
- [ ] `SaveManager.get_deck_instances()` is the sole caller path for player deck construction
- [ ] `get_deck_template_ids()` remains for non-battle uses (deck builder display)
- [ ] Legendary/epic cards show their upgraded stats on the card in battle
- [ ] All existing tests pass headless
