# TID-482: Cosmology Section in magic-system.md

Goal: [GID-128](goal.md) · Type: agent · Status: done

## Problem

`magic-system.md` described how each of the four types *feels to channel* and
nothing else. No origin, no account of why there are four, why a player gets
exactly one, or why two currencies span four types. The four magic-adjacent
systems in the game had no lore at all.

## Approach

The frame was **derived from the mechanics**, not invented and then decorated
onto them. Every claim had to explain a constant or behaviour already in the
code; anything that explained nothing was cut. The section ends with a
"Mechanics this frame explains" table listing 20 implemented behaviours against
the lore that accounts for each, so a future reader can check the fit rather than
take it on trust.

## Changes Made

New `## Cosmology — Essence, Veins and the Four Draws` section in
`docs/agent/magic-system.md`, placed before the existing per-type Lore:

- **Essence** — a substance, not a force. Nothing creates or consumes it; it only
  moves. Magic is therefore a plumbing problem: a mage is a route, not a source.
- **Veins** — ley lines are paths the essence wore for itself. Flow density
  explains the cyan gradient; essence in motion "quickens" what it passes
  through, which is one cause for both the move-speed boost and the Attuned mana
  bonus. Wells are surplus surfacing at crossings.
- **The four draws** — one essence, four grips. Light and Verdant push essence
  in (fast / slow); Dark and Rift pull it out (into the mage / elsewhere). This
  *is* the life-vs-entropy alignment split, and it was already latent in the
  existing Light and Dark lore, which described them as additive and subtractive.
- **Why you only get one** — the first real pull sets the channel like frost
  setting a crack in stone. Explains the one-time permanent `magic_type` choice
  and why reaching into another type is possible but becoming one is not.
- **Corruption and redemption** — the pressure *is* the currency. Pushing
  outward hollows the channel; drawing inward builds surplus. Each is the only
  thing that buys the opposite grip, which is exactly the implemented rule:
  signature-branch cards earn it, non-home types spend it. Both names are
  in-fiction misnomers assigned by the temples, which lets the mechanical meaning
  and the moral connotation diverge on purpose.
- **The Blight** — an opened vein. Bleeds outward, never contracts (`SPREAD_RATE`),
  over-saturates everything in reach (+5 enemy HP), and closing one is the most
  life-aligned act available, hence the Redemption payout.
- **The Colossi** — apertures rather than grips, built over veins to take
  everything at once. All five worked, briefly. Five unrelated attempts explains
  five unrelated biome variants; forgotten builders explain location-derived
  procedural names.
- **Cantrips** — a card is a creature's essence-pattern. Carry four and the
  pattern imposes enough to borrow the trick.
- **Hearth** — the fifth thing, explicitly *not* a fifth type: a channel that
  never set, a hundred hairline paths carrying almost nothing. A hundred useful
  things badly and no destructive thing at all.

## Judgment Call — Hearth as a tradition, not a type

The user's opening question was whether to add more types. Hearth is the only
candidate that filled a real gap rather than duplicating an existing branch, but
making it a fifth *type* would have broken the 2-life/2-entropy split that lets
two currencies cover four types, and added a skill tree and card roster to
balance. As a **tradition** it costs zero balance surface, needs no code, and
closes the actual hole — which was that the story's only wizard practises magic
the type system cannot express.

## Documentation Updates

`docs/agent/magic-system.md`. Orphan-doc hooks in TID-483.
