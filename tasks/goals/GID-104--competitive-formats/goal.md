# GID-104: Competitive Formats — Draft Duels, Tournaments & Spectator Wagers

## Objective

Add PvP-adjacent competitive modes layered over the existing duel engine so sessions have varied, fair, and social competition.

## Context

PvP today is a collection-imbalanced duel between connected peers: a veteran always outguns a new player because their `owned_cards` vastly exceeds a newcomer's. A sealed/draft format where both duelists build decks live from identical seeded pools is the fairest possible PvP. Similarly, with 3–4 players in a session there is no structured competition—duels are ad-hoc challenges. A host-run tournament gives a session a marquee event and gives non-combatants something to watch via the new spectate system (TID-367). Finally, spectating today is passive; letting spectators bet coins on the outcome makes watching an activity and gives the 3rd/4th player a stake in a 1v1.

These modes reuse two shipped systems: the Endless Spire draft UI and pick flow (GID-038) and the Card Packs seeded roll logic (GID-050). The existing PvP plumbing—host-authoritative state mirroring, challenge handshake, wagered duel coin escrow (TID-362)—provides the foundation. All code is guarded by `NetworkManager.is_active()` so single-player is byte-for-byte unchanged.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-385 | Draft duels (sealed-deck PvP) | agent | pending | — |
| TID-386 | Session tournament mode | agent | pending | — |
| TID-387 | Spectator wagers | agent | pending | — |

## Acceptance Criteria

- [ ] Two players can challenge each other into a draft duel, pick 1-of-3 cards from identical seeded pools, and duel with only drafted cards (no permanent collection or `owned_cards` changes)
- [ ] A host can run a 3–4 player tournament with authority-scheduled matches, auto-spectate for non-combatants, and a winner-takes-pot payout via SessionState member-record writes
- [ ] Spectators can place coins on a live duel before a cutoff (e.g. end of turn 3), authority holds escrow, and settlement writes to SessionState on battle end
- [ ] Single-player mode is byte-for-byte unchanged (all new code guarded by `NetworkManager.is_active()`)
- [ ] Unit suite passes (headless import clean, parse errors from CLAUDE.md rules caught)
- [ ] All wire formats are pure helpers in `game_logic/net/`, mirroring `AvatarSync`/`BattleNetProtocol` patterns
