# TID-796: Capture moment polish (card reveal, deck-impact callout)

**Goal:** GID-188
**Type:** agent
**Status:** done
**Depends On:** TID-794

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Soulbinding is the hook; make it feel like a reward. On capture: a card-face reveal ceremony (CardFace + card animations), a "your deck changed" beat that points to the Deck Table, and a first-time explanation before the first capture is possible.

## Research Notes

- `game_logic/battle/CaptureTracker.gd`, `scenes/battle/BattleResultUI.gd` (hunt status line), `docs/agent/card-visuals.md`, pack flip ceremony (`docs/agent/card-packs.md`) for reusable reveal code.
- First-session audit: `docs/agent/game-appeal.md` §7.

## Plan

New `CaptureReveal` widget on the soulbind victory card: back rises, flips to the captured card's face (frame, art,
name, atk/hp), branch-colour glow pulse, Deck Table hint. The first-time explanation already exists (TID-441: the
`soulbinding` tutorial fires on learning Allies and at the first Soulbind line), so no new popup.

## Changes Made

- `scenes/ui/CaptureReveal.gd` (new): `setup(card_id, vh)`, `play(calm)`, `show_face()`, `card_color(tmpl)`; timings
  as consts (`RISE_S`, `HOLD_S`, `FLIP_HALF_S`, `GLOW_S`, `REST_GLOW`). No autoload deps of its own.
- `BattleResultUI.show_soulbind`: adds the reveal under the "Signature captured" line and plays it
  (`BattleJuice.reduce_flashing()` halves the glow peak).
- Verified visually via an Xvfb render (card back at 0.6 s, face + glow + hint at 3 s).
- Tests: `tests/unit/test_capture_reveal.gd` (3). Suite 3650 pass.

## Documentation Updates

- `docs/agent/card-visuals.md`: Capture reveal entry.
