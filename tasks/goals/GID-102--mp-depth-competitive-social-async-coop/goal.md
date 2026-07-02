# GID-102: Multiplayer Depth — Competitive, Social, Async & Co-op Content

## Objective

Deepen multiplayer across four fronts — competitive (ranked ladder, team duels,
reconnection), social (chat, friends, shared stash), asynchronous meta (ghost duels,
auction house, global leaderboards), and co-op content (shared procedural dungeons,
party loot rolls) — building entirely on the existing net stack.

## Context

The multiplayer foundation is mature: co-op for up to 4 players (GID-090/094), persistent
sessions + per-player characters (GID-095), shared world-object sync (GID-096), a dedicated
server (GID-097), co-op story mode (GID-098), the N-player joint battle engine (GID-099/100),
and the social/rewards layer (GID-101 — emotes, pings, trading, wagered duels, party bounties).

Two gaps are called out explicitly in `docs/agent/multiplayer-coop.md`:
- *"there is still no reconnection into an in-progress PvP battle"*
- *"there is still no ranked ladder across sessions"*

Beyond those, the systems built so far enable several natural, high-value extensions. This
goal collects them into four phases. Every task is **additive and guarded** by
`NetworkManager.is_active()` so single-player remains byte-for-byte unchanged, and every new
wire format follows the established pure-helper pattern in `game_logic/net/` (scene-free,
unit-tested, mirroring `AvatarSync`/`BattleNetProtocol`).

**Recommended build order:** Phase A (fills the two explicit spec gaps) → Phase B → Phase D
→ Phase C. Phases are independent; tasks within a phase are mostly independent except where
noted in Depends On.

**Out of scope:** NAT traversal / matchmaking service (still LAN/loopback + dedicated server
only), Steam transport (still stubbed), and ranked *matchmaking* across the internet (the
ladder is a persistent rating + leaderboard, not a global queue).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-370 | PvP rating model + persistence (MMR/ELO) | agent | done | — |
| TID-371 | 2v2 team duels (allies-vs-allies battle mode) | agent | done | — |
| TID-372 | Reconnect into in-progress PvP battle | agent | done | — |
| TID-373 | Ranked queue UI + season leaderboard panel | agent | done | TID-370 |
| TID-374 | Chat system (quick-chat presets + free text) | agent | done | — |
| TID-375 | Token-keyed friends list + online status | agent | done | — |
| TID-376 | Shared party stash (deposit/withdraw) | agent | done | — |
| TID-377 | Ghost duels vs stored deck snapshots | agent | done | — |
| TID-378 | Async card auction house | agent | done | TID-376 |
| TID-379 | Global leaderboards (Spire + co-op clears) | agent | done | — |
| TID-380 | Shared procedural dungeon crawl (synced seed) | agent | done | — |
| TID-381 | Party loot rolls (need/greed on drops) | agent | done | — |

## Acceptance Criteria

- [x] PvP duels update a persistent rating per session character; a cross-session
      leaderboard ranks players, viewable in a UI panel. Single-player unaffected.
- [x] Two teams of allies (2v2) can fight a duel reusing the N-player battle engine; the
      existing solo / 2-player PvP / co-op-PvE paths are unchanged.
- [x] A player who drops mid-duel can rejoin (token-matched) and the host re-mirrors the
      live `GameState` so the battle resumes.
- [x] Party members can chat with quick-chat presets and free text; messages reach same-map
      peers on mobile + desktop.
- [x] A token-keyed friends list persists across sessions; online/offline status shows in
      the lobby/roster; players can add friends from the roster.
- [x] A shared party stash lets members deposit/withdraw cards and coins host-authoritatively
      with no duplication; state persists in the session file.
- [x] A player can battle an AI-piloted snapshot of another player's deck while that player
      is offline (ghost duel), earning a configured reward.
- [x] Players can list cards for sale, bid/buy, and have trades settle host-authoritatively;
      listings persist in the session file with no duplication.
- [x] Endless Spire scores and co-op boss clears are recorded to authority-persisted global
      leaderboards, viewable in a panel.
- [x] A co-op party can enter a procedural dungeon generated from a shared seed so geometry,
      enemies, and chests are identical for every member, reusing GID-096 sync.
- [x] Shared chest/boss drops can be resolved by a need/greed party roll; first-opener-takes
      remains the default when rolls are disabled.
- [ ] Single-player is unchanged; the full unit suite passes; the headless import is clean.
      **Not independently re-verified for TID-378**: this session's sandbox blocked the
      GitHub release download needed to install the `godot` headless binary (org egress
      policy 403 on `github.com`, not retried per proxy guidance), so the new/changed
      GDScript could only be reviewed by hand (bracket/type-safety pass, mirrored against
      the already-CI-green Stash/Trade/Leaderboard patterns) rather than executed. All
      *other* tasks in this goal were previously verified green; only TID-378's addition
      is unverified by an actual run. Flag for a CI check / follow-up session with Godot
      available before treating this box as checked.
