# BID-066: Graveyard and sealed crypt have no graveyard dressing

**Category:** content-gap
**Discovered During:** GID-141 / TID-593

## Description

Madrian's graveyard (GID-141 / TID-591) is a ring of the town's tall brick wall tiles with three burial mounds; no headstones, fence or crypt facade, so it reads as more town wall.

## Evidence

TID-593 capture; `assets/maps/madrian.tres` local (8..18, 47..56) and (22..26, 48..52).

## Suggested Resolution

Add a low fence tile or prop set (headstones, crypt door facade) to the GPU-instanced prop system (`docs/agent/visual-polish.md`).
