# BID-022: Spec lists multiplayer as out-of-scope, but co-op + PvP have shipped

**Category:** spec-gap
**Discovered During:** GID-091 (PvP card battles) research

## Description

`docs/human/specification.md` → **Out of Scope (for now)** still lists
*"Multiplayer / online features"*. This contradicts shipped functionality:

- **GID-090** added LAN co-op world exploration (2 players share madrian).
- **GID-091** adds LAN PvP card battles (host-authoritative).

The "Out of Scope" line should be narrowed to the parts genuinely not built
(internet/NAT, matchmaking, Steam, >2 players, reconnection, wagers/ranked),
rather than excluding multiplayer wholesale.

## Evidence

`docs/human/specification.md`, "Out of Scope (for now)" section:
```
- Multiplayer / online features
```
Conflicts with `docs/agent/multiplayer-coop.md` (GID-090) and the GID-091 goal.

## Suggested Resolution

Human edits the spec per **TID-334** (human-action task under GID-091): qualify
the out-of-scope bullet to "online multiplayer beyond LAN (NAT, matchmaking,
Steam), >2 players, reconnection, PvP wagers/ranked", and optionally add a
Multiplayer bullet under Key Features pointing at `docs/agent/multiplayer-coop.md`.
When done, mark TID-334 done and move this item to Resolved Backlog.
