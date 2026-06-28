# GID-101: Multiplayer Social & Rewards

## Objective

Add the social and reward layer that makes multiplayer expressive and worth grinding:
emotes & map pings, card trading/gifting, duel spectating, wagered duels with a
persistent record, and shared party bounties.

## Context

Co-op has *presence* (avatars, names, colors) but no way to **communicate**, **trade**,
or earn from playing together. PvP duels are documented as **"duel-style": no cards, no
coins, no XP, no record** — winning is invisible. This goal closes those gaps.

Each task is largely independent and additive, built on existing systems:
identity/roster (GID-094), the avatar sync layer, the host-authoritative duel mirror
(GID-091), per-player session characters (GID-095), Gambits wagers (GID-063), and
BountyGen (GID-051). All guarded by `NetworkManager.is_active()`.

**Out of scope:** the co-op story foundation (GID-098) and the joint-battle engine/
design (GID-099/GID-100) — though Party Bounties (TID-369) depends on the joint-battle
enemies existing.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-365 | Emote wheel & map pings | agent | done | TID-355 |
| TID-366 | Card trading & gifting | agent | done | — |
| TID-367 | Spectate a duel | agent | done | — |
| TID-368 | Wagered duels & Champion record | agent | done | — |
| TID-369 | Shared party bounties | agent | done | TID-361 |

## Acceptance Criteria

- [ ] Players can trigger emotes (wheel) and place a brief map/world ping, visible to
      same-map party members, on both mobile and desktop.
- [ ] Two players can trade/gift cards (and/or coins) host-authoritatively with no
      duplication; the trade is confirmed by both sides before committing.
- [ ] A party member can spectate an in-progress duel read-only (fan-out of the existing
      state mirror); spectators can't input.
- [ ] PvP duels support an optional ante (cards/coins) paid to the winner, and a
      win-streak / "Champion" record persists in the session character.
- [ ] Shared party bounties generate goals the party works toward together; all
      contributors receive the reward. Single-player bounties unchanged.
- [ ] Single-player unchanged; full unit suite passes; headless import clean.
