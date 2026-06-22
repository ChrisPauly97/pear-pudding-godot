# TID-319: Per-card illustration art

**Goal:** GID-089
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`CardData` has an `illustration: Texture2D` field added by GID-008 (`TID-017`), and `CardViewBuilder.gd` reads it to display card art. However, most cards still use a color fill fallback because no illustration textures were ever created. This task uses `TextureGen` to procedurally generate a pixel-art illustration for each of the four card archetypes (Ghost, Skeleton, Zombie, Ghoul) plus the spell card variants, and wires them into `CardRegistry` so all card instances automatically get the right illustration.

## Research Notes

**CardData.illustration field:**
- Defined in `data/cards/*.tres` resources; type `Texture2D` (nullable)
- `CardViewBuilder.gd` checks `if card_data.illustration != null` and uses it, else falls back to the archetype color

**CardRegistry (`autoloads/CardRegistry.gd`):**
- Preloads all card `.tres` files as `const` at the top
- `_ensure_loaded()` populates `_cards` dict
- The right place to assign `illustration` at load time: after loading each card resource, call `TextureGen.card_illustration(card_type)` and assign it

**TextureGen extension:**
Add `static func card_illustration(card_type: String) -> ImageTexture` with a `match` on `card_type`:
- `"ghost"` — floating wisp silhouette: translucent white oval with dim inner glow gradient
- `"skeleton"` — humanoid bone figure: white on dark outline style
- `"zombie"` — shambling humanoid: green-tinted with ragged outline
- `"ghoul"` — hunched creature: dark purple with red eyes
- `"spell"` — swirling rune circle: abstract glyph in card's magic-type color

Each illustration is 32×32 pixels, painted with `Image.set_pixel()` loops. Use the `_cached` helper so each type is only generated once.

**Card type identification:**
`CardData` has a `card_type: String` field (values: `"ghost"`, `"skeleton"`, `"zombie"`, `"ghoul"`) and spell cards have `card_type = "spell"` plus a `magic_type: String`. The illustration key can be `"spell_" + magic_type` for spells.

**Wire-up location:**
In `CardRegistry._ensure_loaded()`, after `_cards[skill.id] = skill`, add:
```gdscript
if skill.illustration == null:
    skill.illustration = TextureGen.card_illustration(skill.card_type)
```

**Android constraint:** All textures are generated at startup and cached in memory by `TextureGen._cache`. No file I/O at runtime. 32×32 × ~50 cards = negligible memory footprint.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
