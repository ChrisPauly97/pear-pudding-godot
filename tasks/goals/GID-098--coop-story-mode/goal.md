# GID-098: Co-op Story Mode

## Objective

Make the real single-player story playable together in a co-op session: the party
moves through the named story maps and dungeons as a group, shares story
progression, and is addressed as a group by NPCs.

## Context

Co-op today is pinned to **one** shared map (madrian) and the avatar layer
deliberately **drops cross-map peers** (TID-352) — it is explicitly *not* multi-map
co-op. madrian is a town with no enemies/chests, so a co-op session has nothing to
*do* together (logged as BID-024). The user wants the existing story (The Tale of
Saimtar) to be the co-op content: walk it together, fight together, progress
together.

This goal is the foundation for GID-099 (joint battles) and GID-101 (social). It
builds on the persistent-session machinery (GID-095: `SessionState`, `SessionStore`,
identity tokens) and the world-object sync (GID-096: engage-locks, shared chests),
generalizing both from single-map to multi-map.

**Out of scope:** the joint-battle engine (GID-099), the square battlefield design
(GID-100), social/reward features (GID-101), and the infinite chunk world (co-op
stays on finite named maps).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-355 | Multi-map co-op — map-transition & cross-map avatar sync | agent | done | — |
| TID-356 | Shared story progression & flag arbitration | agent | done | TID-355 |
| TID-357 | Group-aware NPC & story dialogue system | agent | done | TID-356 |
| TID-358 | Pluralize authored story dialogue in story.md | human-action | in-progress | TID-357 |

## Acceptance Criteria

- [ ] A party in a co-op session can transition between named maps and dungeons
      together; peers on the same map render each other (cross-map filtering keeps
      peers on *different* maps hidden, but transitions are synced/followable).
- [ ] Story flags are shared via `SessionState`, not local `SaveManager`; a story
      beat triggered by one player advances the whole party and fires its one-time
      effect exactly once (arbitration).
- [ ] NPC and story dialogue addresses the group when more than one player is
      present, and falls back to the single-player text solo.
- [ ] The exact list of authored `story.md` lines needing pluralization is prepared
      for the human to apply (TID-358).
- [ ] Single-player is byte-for-byte unchanged when no session is active; full unit
      suite still passes; headless import clean.
