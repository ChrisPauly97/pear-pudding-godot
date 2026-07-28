# GID-127: Magic Cosmology — Tying the Orphan Systems Together

## Objective

Write the world lore that explains, from one frame, the four magic types and the
four implemented-but-unexplained magic systems: ley lines, the Blight, the
Ancient Colossi, and card cantrips. Also account for Maiteln, whose magic the
type system cannot express.

## Context

Raised by the user (2026-07-28), immediately after GID-126 shipped Verdant and
Rift: *"any other types of magic we could add? gaps in the lore around magic we
can fill in?"* — then, after the research below was presented: *"okay do that and
tie it all together."*

### The gap

Research across `docs/human/story.md` and the agent docs found that the magic
system had lore for how each type *feels to channel* and nothing else. There was
no account of where magic comes from, why a person gets exactly one type, or why
there are four. Meanwhile four fully-implemented systems transacted in magic
without belonging to it:

| System | Mechanically live | Lore |
|---|---|---|
| Ley lines | Speed boost, "Attuned" +1 mana, Mana Wells yield essence | none |
| Blight | Hearts spread daily, +5 enemy HP, cleansing pays Redemption Points | none |
| Ancient Colossi | 5 ruined biome variants, procedural names | none |
| Cantrips | Deck composition grants Ghost Phase / Skeleton Dig | none |
| Maiteln | Conjures horses, smooths roads, tidies rooms, cooks | contradicts the four types |

The Blight was the clearest symptom: it already paid out in Redemption Points, a
currency defined entirely by the magic system, while having no stated connection
to it.

### Why not a fifth type

The user's first question was whether to add more types. The recommendation —
accepted — was no, for two reasons:

1. **The alignment math.** Four types split 2 life / 2 entropy, which is what
   lets two currencies (corruption / redemption) cover all four. A fifth forces
   either a third currency or a 3/2 split. Types are cheapest to add in pairs.
2. **The space is covered.** Post-GID-126, the obvious candidates collide with
   what exists: Storm/Tempest overlaps Flux's tempo, Void/Umbral overlaps Rift,
   Grave overlaps Ash, Ward overlaps Dawn.

Hearth — Maiteln's practical, domestic magic — was the one candidate filling a
real gap. It is resolved here as a **tradition rather than a fifth type**, which
costs no balance surface and closes the narrative hole instead.

### The frame

Essence is a real substance that moves through the ground in veins. The four
types are four ways of drawing on it. Everything else follows: a vein is a ley
line, a Mana Well is where two veins cross and essence surfaces, the Blight is a
vein opened and never closed, the Colossi are what happens when someone tries to
draw without a draw, and a cantrip is essence-pattern borrowed from cards you
carry.

The frame was chosen to be *derived from* the mechanics rather than decorative —
each claim explains a number that is already in the code. See the "Mechanics this
frame explains" table in `docs/agent/magic-system.md`.

## Tasks

| Task | Title | Status |
|------|-------|--------|
| [TID-480](TID-480--cosmology-lore.md) | Cosmology section in magic-system.md | done |
| [TID-481](TID-481--orphan-doc-lore-hooks.md) | Lore hooks in the four orphan docs + story.md proposal | done |

## Acceptance Criteria

- [x] One frame explains essence, veins, the four types, both currencies, and the
      permanence of the path choice.
- [x] Ley lines, the Blight, the Colossi and cantrips each have a lore account
      that matches their implemented behaviour, including specific constants.
- [x] Maiteln's magic is accounted for without adding a fifth type.
- [x] Each orphan doc links back to the frame rather than restating it.
- [x] Story-canon claims are drafted as a proposal for human approval, not
      written into `docs/human/story.md`.
- [x] Documentation only — no `.gd`, `.tres` or scene changes.
