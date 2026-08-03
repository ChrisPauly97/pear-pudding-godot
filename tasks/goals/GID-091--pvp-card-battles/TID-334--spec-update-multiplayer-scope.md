# TID-334: Spec update — multiplayer no longer out-of-scope

**Goal:** GID-091
**Type:** human-action
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/human/specification.md` is human-owned and the agent must never edit it. Its
**"Out of Scope (for now)"** section still lists *"Multiplayer / online features"*,
which now contradicts shipped co-op (GID-090) and PvP card battles (GID-091). This
task records what the human should change so the spec reflects reality. Tracked
separately as **BID-022**.

## Research Notes

Current conflicting text in `docs/human/specification.md`:

```
## Out of Scope (for now)

- Multiplayer / online features
- ...
```

This was accurate at spec authoring time but is now false: the game has LAN co-op
world exploration and LAN PvP card battles.

## What needs to be done (human)

Edit `docs/human/specification.md` to reflect the current scope. Suggested:

- Remove or qualify the "Multiplayer / online features" bullet under **Out of
  Scope**. A precise replacement that keeps the genuinely-unbuilt parts out of
  scope:
  > - Online/internet multiplayer beyond LAN (NAT traversal, matchmaking, Steam
  >   transport), >2 players, reconnection, and any PvP wagers/ranked ladder
- Optionally add a short **Multiplayer** bullet under **Key Features** describing
  the shipped slice:
  > - LAN co-op (2 players share the madrian map) and LAN PvP card battles via an
  >   abstracted ENet transport (host-authoritative); see
  >   `docs/agent/multiplayer-coop.md`.

Once updated, mark this task **done** in `goal.md` and `tasks/index.md`, and move
**BID-022** to Resolved Backlog.

## Plan

_N/A — human-action task._

## Changes Made

Re-checked `docs/human/specification.md` before editing: the "Multiplayer /
online features" bullet this task describes is **already gone** from Out of
Scope — it was resolved earlier via GID-094/TID-344 (tracked as BID-022,
already in "Resolved Backlog" in `tasks/index.md`). No live conflict
remained to fix.

Since the spec had no explicit "Open Questions — Resolved" entry recording
that history (unlike the Chapter 2 precedent this task's suggested wording
was modeled on), added one while making TID-311/TID-438's edit to the same
file in this session (explicit human permission, 2026-08-03) — see that
combined diff. No separate edit needed for this task specifically.

## Documentation Updates

_N/A — human-owned doc._
