# TID-344: Update spec multiplayer scope (human-owned)

**Goal:** GID-094
**Type:** human-action
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/human/specification.md` still lists "Multiplayer / online features" under
**Out of Scope** (line ~101), but co-op + PvP already shipped (GID-090/091) and
this roadmap (GID-094–097) significantly expands multiplayer into persistent,
4-player, internet-reachable sessions. The spec is **human-owned — the agent must
not edit it**. This task records the exact change for the human to make. Resolves
**BID-022**.

## Research Notes

**File:** `docs/human/specification.md`.

**Current conflicting text:** the "Out of Scope (for now)" section opens with
"Multiplayer / online features"; BID-022 (`tasks/backlog/BID-022--spec-multiplayer-out-of-scope-conflict.md`)
tracks this.

**Suggested edits for the human to make (agent will present, not apply):**
1. Remove "Multiplayer / online features" from **Out of Scope**, or replace it with
   a narrower exclusion (e.g. "ranked matchmaking / global server browser").
2. Add a short **Multiplayer** subsection under Key Features summarizing the
   shipped + planned scope: co-op (up to 4 players), PvP card duels, dedicated
   server option, session-scoped persistent characters, LAN discovery + join by IP.
3. Note the constraints that remain (no NAT-punch relay — port-forward/public-IP or
   dedicated server at home; Android can join/host-listen but multicast discovery is
   limited).

**On completion:** once the human confirms the spec is updated, move
`tasks/backlog/BID-022--spec-multiplayer-out-of-scope-conflict.md` to
`tasks/archive/backlog/`, update its link + section in `tasks/index.md`.

## Plan

Human-action task. The user explicitly authorized the agent to apply the spec edits
directly (human-owned doc), so the agent made the changes and confirmed completion.

## Changes Made

`docs/human/specification.md` (edited with the owner's explicit permission):
1. **Out of Scope** — replaced "Multiplayer / online features" with the narrower
   "Ranked matchmaking, global server browser, and NAT-punch relay/matchmaking service".
2. **Key Features** — added a "Multiplayer (Co-op & PvP)" subsection summarizing
   shipped + planned scope (4-player co-op, PvP duels, LAN discovery + join-by-IP,
   planned dedicated server + session-scoped persistent characters) and the
   connectivity constraints (LAN by default, no NAT traversal; Android host-discovery limited).

Backlog: moved `BID-022` to `tasks/archive/backlog/` and updated `tasks/index.md`
(struck through in Backlog, added to Resolved Backlog).

## Documentation Updates

No agent-doc changes (spec is human-owned). BID-022 resolved and archived.
