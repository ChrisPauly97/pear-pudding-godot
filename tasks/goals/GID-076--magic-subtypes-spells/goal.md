# GID-076: Magic Subtypes — 40 Spell Cards

## Objective

Add 10 spell cards per magic branch (Ember, Dawn, Dusk, Ash), each obtainable in-game through the shop and enemy drops.

## Context

The TCG currently has 4–6 spells per branch — the existing set covers basics (single-target damage, heal, AoE). This goal expands each branch to 10 spells with distinct identities, adding 20 new `spell_effect` keys to `BattleScene` to support richer spell mechanics (keyword grants, hero-direct effects, poison/freeze/stun, summons, card discard).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-279 | New spell effect engine — 20 new effect keys | agent | done | — |
| TID-280 | Ember spell cards — 10 `.tres` files | agent | done | TID-279 |
| TID-281 | Dawn spell cards — 10 `.tres` files | agent | done | TID-279 |
| TID-282 | Dusk spell cards — 10 `.tres` files | agent | done | TID-279 |
| TID-283 | Ash spell cards — 10 `.tres` files | agent | done | TID-279 |
| TID-284 | Shop/drop pool wiring + test count fix | agent | done | TID-280, TID-281, TID-282, TID-283 |
| TID-285 | Agent docs update (battle-system.md) | agent | done | TID-284 |

## Acceptance Criteria

- [ ] 40 new spell `.tres` files exist (10 per branch) with `.uid` sidecars
- [ ] All 20 new `spell_effect` keys are implemented in `BattleScene._resolve_spell_effect`
- [ ] `_SPELL_EFFECT_LABELS` covers all new effects (both in BattleScene and CardInspectOverlay)
- [ ] Targeting arrays updated: 4 new enemy-targeted and 4 new friendly-targeted effects
- [ ] All new spells appear in ShopScene (automatic via CardRegistry scan)
- [ ] New spells distributed across enemy drop pools
- [ ] Test card count updated to pass
