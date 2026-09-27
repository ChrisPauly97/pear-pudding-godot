# TID-573: Docs & Human Story Note

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** TID-572

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Update agent docs and CLAUDE.md for the stitched realm; flag story.md map-table changes to the human.

## Research Notes

- docs/agent/world-generation.md, named-maps-and-dungeons.md, story-implementation.md.

## Plan

Document the stitched realm in the agent docs + CLAUDE.md; list the human story.md changes for the user.

## Changes Made

- No code. Human-action note for `docs/human/story.md` (agent never edits it): its map
  specs/table describe separate door-connected maps (e.g. "madrian → maykalene" exits,
  Larik entered from the south); the towns are now regions of the overworld joined by
  roads, and the camp / Isfig / ambush beats sit at fixed road sites.

## Documentation Updates

- `docs/agent/named-maps-and-dungeons.md`: new "Stitched Story Realm (GID-138)" section; map-stack `pos:` tokens.
- `docs/agent/world-generation.md`: pipeline step 4 (realm stamping).
- `docs/agent/story-implementation.md`: starting point, full objective table with sites,
  pointability rule, camp placement, Maiteln presence.
- `CLAUDE.md`: Map Storage note; `RealmRegions` row in the world-module table.
