# BID-099: Gathering harvests are not synced in co-op

**Category:** design-inconsistency
**Discovered During:** GID-182 / TID-760

## Description

Gathering-node depletion is session-only and local, so in co-op every peer can harvest the same node. The goal's acceptance criterion "both are deterministic and co-op safe" is met for enemy drops but not for gathering. Related gaps: a harvest is a single tap rather than a timed hold, nodes respawn on real seconds rather than in-game minutes, bog moss is not planted, and wilderness campfires are not cooking fires.

## Evidence

`scenes/world/modules/GatherNodes.gd`, `scenes/world/entities/GatherNode.gd`; "Known gaps" in `docs/agent/professions.md`; GID-182 goal.md (co-op criterion left unticked).

## Suggested Resolution

Broadcast harvests the way chest removals are (`CoopSession` world-object sync, keyed by gather-node id, with a map discriminator), and have the host own the respawn clock.
