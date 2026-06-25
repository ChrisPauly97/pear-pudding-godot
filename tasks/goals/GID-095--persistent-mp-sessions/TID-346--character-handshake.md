# TID-346: Per-player character handshake & session-scoped progress

**Goal:** GID-095
**Type:** agent
**Status:** pending
**Depends On:** TID-345

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wire the session model (TID-345) into the connect flow: on join, match the player's
identity token to a stored character (or create one), send it to the client, have
the client adopt it for the session, and persist changes back as the player plays.

## Research Notes

_To be expanded when TID-345 lands._

- On `peer_connected` (authority side), look up `SessionState.members[token]`
  (token from GID-094 identity handshake). Hit → send that character record;
  miss → create a seeded starter record (reuse the `ensure_coop_deck` starter, but
  now *persisted* in the session file, not transient).
- Client adopts the received record into the in-memory game state used for co-op:
  deck/inventory/coins/level/skills. This is **session state, not `save.json`** —
  the client must render/use it without clobbering the player's single-player save.
  Audit every place co-op reads `SaveManager` (deck, coins, skills, level) and route
  it through the session character when `NetworkManager.is_active()`.
- Persist-back: on relevant events (card gained, coins changed, level up, skill
  unlocked, position update) the authority updates the member record and marks the
  session dirty. Clients send intents to the authority (reliable RPC) — clients
  never write the file; only the authority does (single source of truth, reuses the
  GID-091 host-authoritative pattern).
- Reconnection resume is the payoff — verified in TID-348.
- CLAUDE.md: guard all by `is_active()`; reliable RPC for character/intent;
  reconnect to fresh state objects must reconnect their signals (see the GID-092
  `from_dict` signal-reconnect learning).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
