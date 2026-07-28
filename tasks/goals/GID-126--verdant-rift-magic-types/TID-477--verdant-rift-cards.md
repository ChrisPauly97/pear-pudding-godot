# TID-477: Verdant & Rift Spell Cards + Branch Rune Colors

Goal: [GID-126](goal.md) · Type: agent · Status: done

## Problem

Skill trees alone do not make a magic type visible in play. Light and Dark each
have spell cards carrying `magic_type` / `magic_branch`; Verdant and Rift need
the same or they never appear in a deck.

## Plan

12 spell cards, 3 per branch, built entirely from `spell_effect` ids that
`SpellEffectResolver` already implements.

## Changes Made

- **`data/cards/` — 12 new `CardData` spell resources** (+ `.uid` sidecars):

| Branch | Cards |
|---|---|
| Bloom | Germinate (heal_all 3), Verdant Bulwark (buff_health_all 2), Blooming Ward (grant_ward_all) |
| Thorn | Bramble Snare (apply_poison_all 1), Thorn Volley (deal_damage_random 3), Wild Growth (buff_attack_all 2) |
| Flux | Displace (draw_card 2), Kinetic Bolt (deal_damage_single 4), Momentum (double_attack) |
| Fracture | Unmake (bind_minion), Fault (stun_single 1), Shardfall (enemy_discard 2) |

- **`autoloads/CardRegistry.gd`** — 12 new preload constants and 12 new entries
  in the `_ensure_loaded()` list.
- **`game_logic/TextureGen.gd`** — `_gen_card_spell_rune()` now reads
  `MagicTypes.BRANCH_COLORS` instead of its own four-arm `match`. This removes a
  duplicated colour table and covers all eight branches in one line.

## Judgment Call — no new spell effects

Every card reuses an existing `spell_effect`. `SpellEffectLabels.SPELL` already
has 40+ entries covering sustain, retribution, tempo and disruption, and
`test_spell_effect_labels` asserts every registry card has a label. Inventing new
effect ids would have meant new `SpellEffectResolver` match arms, new labels, and
new targeting-list entries for no mechanical gain the existing vocabulary does
not already express. Branch identity here comes from *which* effects each branch
draws on and at what cost, which is exactly how Ember and Ash are differentiated.

## Judgment Call — no hand-drawn rune art

`SpriteRegistry.card_illustration_texture()` returns hand-drawn PNG runes for
`dawn`/`dusk`/`ember`/`ash` and `null` otherwise, and `CardRegistry` already
falls back to `TextureGen.card_illustration()` on null. The new branches
therefore render a procedural rune tinted with their branch colour, with no code
change needed at the call site. Four PNGs (`rune_bloom`, `rune_thorn`,
`rune_flux`, `rune_fracture`) are listed as an asset requirement in
`docs/agent/art-sprites.md`; dropping them in and adding four `match` arms is the
only work left to upgrade them.

## Documentation Updates

`docs/agent/magic-system.md`, `docs/agent/art-sprites.md`,
`docs/agent/battle-system.md` (TID-479).
