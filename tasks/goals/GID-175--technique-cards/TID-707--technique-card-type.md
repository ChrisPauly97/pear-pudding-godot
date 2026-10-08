# TID-707: Technique card type: 8 cards, recycle-on-play, both modes

**Goal:** GID-175
**Type:** agent
**Status:** pending
**Depends On:** TID-706

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Add a `technique` card type and the 8 technique cards with effects that work in both battle modes.

## Research Notes

- Card data: `data/CardData.gd`, `data/cards/*.tres` (preload in `CardRegistry`; every .tres needs a `.uid` sidecar; Android needs const preloads).
- Play path: `PlayerState.play_card` / `play_card_at_slot` (game_logic/battle/PlayerState.gd:175/196). Recycle = on resolve, push the card to the bottom of `draw_deck` instead of discarding.
- Effects to port from `SkillBar.apply()`: damage, heal, interrupt, shield (`hero.apply_status("armor")`), manatap, sweep, stun. Status rules: `game_logic/battle/StatusEffects.gd`.
- Card frame/badge: `scenes/ui/CardFace.gd`, `docs/agent/card-visuals.md` (add a technique frame/badge).
- MagicTypes: techniques are typeless. Check `test_magic_types` does not require a magic_type on every card.
- Keep the `value ≤ 9` balance rule (now in a card test).
- Tests: a new `tests/unit/test_technique_cards.gd` covering recycling, each effect in turn-based and real-time, and the deck copy limit.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
