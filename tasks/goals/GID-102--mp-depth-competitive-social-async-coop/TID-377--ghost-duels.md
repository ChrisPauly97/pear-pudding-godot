# TID-377: Ghost duels vs stored deck snapshots

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP needs both players online and on the same LAN/host. A **ghost duel** lets a player battle
an **AI-piloted snapshot** of another player's deck while that player is offline — async
competition with zero live networking. It reuses the existing single-player battle engine +
`BasicAI`; only the *opponent deck source* changes.

## Research Notes

- **Snapshot source.** A "deck snapshot" is just a deck list + display name + (optional) color
  + rating. The authority already holds every member's `player_deck` + `owned_cards` in
  `SessionState` (GID-095). Capture a snapshot `{token, name, color, deck: [template_ids],
  rating}` per member — either derive on demand from the session roster, or persist a
  `ghost_snapshots` list in `SessionState` updated when a member logs off / on a timer. Prefer
  **deriving from `members`** to avoid a second source of truth; persistence already covers it.
  Note: the deck is stored as UID instances — resolve each UID to its **template id** for the
  ghost (the ghost doesn't need the opponent's specific instances, just a playable deck).
- **No live net.** A ghost duel is a **local single-player battle** against an AI whose deck is
  the snapshot. This is the existing solo battle path (`_local_player_idx == 0`, `is_ai`
  opponent, `BasicAI`), **not** the PvP host-authoritative path — so there is no
  `BattleNetSync`, no mirror, no reconnection concern. Add a `SceneManager.enter_ghost_duel(
  opponent_snapshot)` that builds the AI opponent deck from the snapshot and launches
  BattleScene like an NPC duel. Reuse the NPC-duel scaffolding (`docs/agent` references the
  tavern duel / `enter_pvp_battle` siblings — grep `enter_` in SceneManager).
- **Entry point.** Surface ghost opponents in the lobby or a "Challenge a Rival" panel:
  list known snapshots (from the session roster + friends from TID-375 if their snapshot was
  cached). Show name/color/rating. One tap → `enter_ghost_duel`.
- **Rewards.** Keep modest and clearly *async* — e.g. a small coin reward on win, optionally
  feed TID-370 rating with a **reduced K** or no rating change (ghost is AI-piloted, not the
  real player — recommend **no rating change**, coins only, to avoid farming). Decide in Plan;
  default to coins-only.
- **Deck resolution helper.** Building a playable AI deck from template ids already happens for
  NPC/enemy decks (`EnemyRegistry`, `player.build_deck` with a typed `Array[String]` — see
  CLAUDE.md "assign()" guidance). Reuse it; annotate arrays as `Array[String]` to avoid the
  Variant-inference errors documented in CLAUDE.md.
- **Tests:** a unit test for snapshot extraction (member record → `{name, deck template ids}`),
  including UID→template resolution and empty/garbage tolerance. The battle itself is covered
  by existing battle tests.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Ghost duels" subsection); note it is
  the only PvP-flavored mode that needs **no** live connection.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
