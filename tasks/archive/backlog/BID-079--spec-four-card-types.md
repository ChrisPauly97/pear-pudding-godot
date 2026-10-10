# BID-079: Spec still lists four card types

**Category:** spec-gap
**Discovered During:** GID-151 research

## Description

`docs/human/specification.md` says the battle system has four card types (Ghost, Skeleton, Zombie, Ghoul) and
lists "more than 4 card types" as out of scope. The game now ships ~134 cards (minions, spells, legendaries).

## Evidence

`docs/human/specification.md` Card Battle System + out-of-scope list; `data/cards/*.tres`.

## Suggested Resolution

Human edit of the spec to describe the current card roster.
