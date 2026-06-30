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
| TID-373 | Ranked queue UI + season leaderboard panel | agent | pending | TID-370 |
| TID-374 | Chat system (quick-chat presets + free text) | agent | pending | — |
| TID-375 | Token-keyed friends list + online status | agent | pending | — |
| TID-376 | Shared party stash (deposit/withdraw) | agent | pending | — |
| TID-377 | Ghost duels vs stored deck snapshots | agent | pending | — |
| TID-378 | Async card auction house | agent | pending | TID-376 |
| TID-379 | Global leaderboards (Spire + co-op clears) | agent | pending | — |
| TID-380 | Shared procedural dungeon crawl (synced seed) | agent | pending | — |
| TID-381 | Party loot rolls (need/greed on drops) | agent | pending | — |

## Acceptance Criteria

- [ ] PvP duels update a persistent rating per session character; a cross-session
      leaderboard ranks players, viewable in a UI panel. Single-player unaffected.
- [ ] Two teams of allies (2v2) can fight a duel reusing the N-player battle engine; the
      existing solo / 2-player PvP / co-op-PvE paths are unchanged.
- [ ] A player who drops mid-duel can rejoin (token-matched) and the host re-mirrors the
      live `GameState` so the battle resumes.
- [ ] Party members can chat with quick-chat presets and free text; messages reach same-map
      peers on mobile + desktop.
- [ ] A token-keyed friends list persists across sessions; online/offline status shows in
      the lobby/roster; players can add friends from the roster.
- [ ] A shared party stash lets members deposit/withdraw cards and coins host-authoritatively
      with no duplication; state persists in the session file.
- [ ] A player can battle an AI-piloted snapshot of another player's deck while that player
      is offline (ghost duel), earning a configured reward.
- [ ] Players can list cards for sale, bid/buy, and have trades settle host-authoritatively;
      listings persist in the session file with no duplication.
- [ ] Endless Spire scores and co-op boss clears are recorded to authority-persisted global
      leaderboards, viewable in a panel.
- [ ] A co-op party can enter a procedural dungeon generated from a shared seed so geometry,
      enemies, and chests are identical for every member, reusing GID-096 sync.
- [ ] Shared chest/boss drops can be resolved by a need/greed party roll; first-opener-takes
      remains the default when rolls are disabled.
- [ ] Single-player is unchanged; the full unit suite passes; the headless import is clean.
