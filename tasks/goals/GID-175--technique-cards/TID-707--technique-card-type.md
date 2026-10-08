# TID-707: Technique card type: 8 cards, recycle-on-play, both modes

**Goal:** GID-175
**Type:** agent
**Status:** done
**Depends On:** TID-706

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Add a `technique` card type and the 8 technique cards with effects that work in both battle modes.

## Research Notes

- **Design is fixed in combat-model.md → "Technique cards (GID-175 / TID-706)".** Create `game_logic/battle/TechniqueDefs.gd` (real-time extras + level/coins, replaces `SkillBar.ABILITIES`). Turn-based effects reuse existing `spell_effect` ids, except a new `mana_tap`. Add `TECHNIQUE_DECK_MAX = 3` and the 1-copy rule.
- Card data: `data/CardData.gd`, `data/cards/*.tres` (preload in `CardRegistry`; every .tres needs a `.uid` sidecar; Android needs const preloads).
- Play path: `PlayerState.play_card` / `play_card_at_slot` (game_logic/battle/PlayerState.gd:175/196). Recycle = on resolve, push the card to the bottom of `draw_deck` instead of discarding.
- Effects to port from `SkillBar.apply()`: damage, heal, interrupt, shield (`hero.apply_status("armor")`), manatap, sweep, stun. Status rules: `game_logic/battle/StatusEffects.gd`.
- Card frame/badge: `scenes/ui/CardFace.gd`, `docs/agent/card-visuals.md` (add a technique frame/badge).
- MagicTypes: techniques are typeless. Check `test_magic_types` does not require a magic_type on every card.
- Keep the `value ≤ 9` balance rule (now in a card test).
- Tests: a new `tests/unit/test_technique_cards.gd` covering recycling, each effect in turn-based and real-time, and the deck copy limit.

## Plan

Medium complexity, but the design was already settled, so I proceeded without an approval stop.
1. `TechniqueDefs.gd`: real-time table + deck rules.
2. Eight `tech_*.tres` cards, each `card_class = "spell"`, so every existing spell path works.
3. CardRegistry preloads them and keeps them out of `get_all_ids()`.
4. `PlayerState`: recycle on play.
5. Resolver: real-time power + `mana_tap`.
6. Tests.

## Changes Made

- New `game_logic/battle/TechniqueDefs.gd`, plus `data/cards/tech_{strike,mend,kick,guard,ember_lance,mana_tap,sweep,daze}.tres` (+ `.uid`).
- `autoloads/CardRegistry.gd`: preloads; `get_all_ids()` excludes techniques; new `get_technique_ids()`.
- `game_logic/battle/PlayerState.gd`: `_retire_spell()` puts a technique at the bottom of the draw pile.
- `scenes/battle/SpellEffectResolver.gd`: `TechniqueDefs.power()` (real time when `mana_scale > 1`); new `mana_tap` arm. Label in `SpellEffectLabels.gd`.
- `tests/unit/test_technique_cards.gd` (12 tests). Full suite PASS with 0 SCRIPT ERROR; gdlint and unsafe-hits clean.
- Deviation from the TID-706 design: `card_class` stays `"spell"` (19 code paths check `== "spell"`) instead of a new `"technique"` class. The `tech_*` id is the marker. The card-face badge is reduced to description text.

## Documentation Updates

combat-model.md → Technique cards: card-type, visual and pool rows corrected; new "Implementation (TID-707)" subsection. TID-708/709 research notes updated.
