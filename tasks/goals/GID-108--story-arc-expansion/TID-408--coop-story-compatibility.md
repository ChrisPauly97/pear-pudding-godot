# TID-408: Co-op Compatibility Pass — Chapters 1 & 2 with up to 4 Players

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** TID-402, TID-405, TID-407

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op story mode (GID-098) made the story playable as a party: story flags are
shared via `SessionState` (not local `SaveManager`), a beat triggered by one player
advances the whole party with exactly-once arbitration (TID-356), and NPC dialogue
is group-aware (TID-357). Every piece of new GID-108 content must obey those rules
so a 4-player party experiences one coherent story — no per-player divergence
within a session, no double-fired beats, no cross-map ghosts.

## Design Rules (decided at goal creation, 2026-07-02)

1. **Shared spine:** all new flags (`chapter1_camp_night`, `chapter1_learned_fire`,
   `chapter1_spoke_queen/_scargroth`, `chapter1_complete`, all `chapter2_*`) go
   through the TID-356 shared-flag arbitration in co-op. First player to trigger
   advances the party; the beat's one-time effect fires exactly once.
   **"Each player affects it differently" is intentionally NOT the model** — any
   member's interaction counts for the whole party (e.g. one player talks to the
   Queen, another to Scargroth: both sub-flags set, ending unlocks). Individual
   contribution is expressed through *who does what*, not through divergent states.
2. **Scripted tutorial battles (rabbit hunt, Ch2 ambush):** in co-op, party members
   present at the trigger join as a joint battle (GID-099/100 co-op PvE engine),
   each seated player receiving the fixed tutorial deck and their own deterministic
   draw sequence; tutorial popups render locally per client. If seating scripted
   decks in the joint engine proves too invasive, fallback: the triggering player
   fights solo and the flag is shared on victory (decide in Plan; fallback is
   acceptable for v1).
3. **Narration overlays (Ch1 ending, Ch2 cliffhanger):** the authority broadcasts a
   narration event; all clients show the overlay simultaneously; the completion
   flag is set once by the authority. Late-join/absent members inherit the shared
   flag state on next sync.
4. **Maiteln journey presence (TID-403):** exactly ONE Maiteln per session — an
   authority-owned follower whose position syncs to clients (same pattern as
   RemotePlayer avatars). He follows the party centroid / the nearest on-map member,
   never duplicates per player. Carry `map_name` in his sync payload and filter on
   receive (CLAUDE.md invariant from the cross-map-ghost fix, GID-096/TID-352).
5. **Story scrolls (larik letter, traitor's seal):** shared-trigger — first
   collector fires it; the journal entry + narration is granted to all session
   members (mirror the GID-096 shared-chest model).
6. **Story siege at marsax_hold (Ch2 beat 4):** in co-op this requires the synced
   siege from GID-103 (Shared World Life — pending). Until GID-103 lands, the
   story siege is host-resolved: the host runs the siege, outcome flag is shared.
   Note the dependency in the Plan; do not block Chapter 2 solo play on it.
7. **War-camp dungeon boss (Ch2 beat 6):** joint co-op PvE battle (GID-099);
   shared dungeon crawl machinery from GID-102/TID-380 applies.
8. **Solo saves stay clean:** co-op story progress lives in `SessionState` and must
   NOT write through to a member's personal `SaveManager.story_flags` — each
   player's solo campaign keeps its own pace (GID-098 invariant; verify for every
   new flag site: gate `set_story_flag` through the same co-op-aware path the
   existing Chapter 1 flags use).

## Research Notes

- Shared flags: game_logic/net/SessionState.gd (`story_flags` dict, to_dict/from_dict),
  tests/unit/test_coop_story_flags.gd (idempotency + round-trip semantics).
- Arbitration + multi-map transitions: GID-098 TID-355/356/357 task files; group
  dialogue pluralization pending as GID-098/TID-358 (human-action, in-progress) —
  new GID-108 dialogue lines added to story.md should be included in that
  pluralization list when TID-358 completes.
- Joint battle engine: GID-099/GID-100 (square battlefield, cross-board cards);
  co-op PvE quirks logged in BID-027/BID-028.
- Avatar/map filtering invariant: CLAUDE.md "Co-op avatar sync was map-blind" —
  carry the map discriminator in any new sync payload (Maiteln follower included).
- Sync layer: scenes/world NetSync/AvatarSync, autoloads/NetworkManager.gd;
  docs/agent/multiplayer-coop.md.
- Pending related goals: GID-103 (synced sieges/night hunts), GID-102/TID-380
  (shared dungeon crawl) — check their status at Plan time.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
