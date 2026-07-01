# GID-103: Shared World Life — Synced Clock, Weather, Night Hunts & Town Siege

## Objective

Make the shared co-op world itself feel alive by syncing environmental state (day/night, weather) and adding party-scale events (spectral hunts and town siege) on the shared madrian map.

## Context

Co-op multiplayer (GID-094, docs/agent/multiplayer-coop.md) currently syncs character positions, inventory, and discrete world-object lifecycle events, but environmental systems (day/night, weather) and environmental-gated content remain unsynchronized across peers. This creates divergence: one player experiences night while another sees day, breaking immersion and making shared activities (hunts, sieges) impossible to coordinate. Additionally, the co-op landing map (madrian, BID-024) has no narrative content or enemies, leaving little for parties to do together.

This goal addresses that gap by:
1. Syncing the shared world clock (time_of_day, days_elapsed) and weather state from the authority so all peers see the same moment and sky.
2. Bringing the single-player Night Hunts system (GID-055, docs/agent/night-hunts.md) to co-op: when the synced clock reaches night on the shared map, spectral enemies spawn as deterministic world objects for the whole party to hunt together.
3. Enabling the flagship party event: a co-op Town Siege (reusing GID-054 logic) where the host triggers a defense wave on madrian, culminating in a joint PvE boss battle (GID-099) with rewards distributed to all session members.

All new code is guarded by `NetworkManager.is_active()` to keep single-player byte-for-byte unchanged.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-382 | Synced world clock & weather | agent | pending | — |
| TID-383 | Party night hunts | agent | pending | TID-382 |
| TID-384 | Co-op town siege defense | agent | pending | — |

## Acceptance Criteria

- [ ] All peers see the same time-of-day and weather on the shared world (synced from authority via broadcast RPC); late-joining peers receive the current state in the unicast snapshot.
- [ ] Night hunts spawn spectral enemies as shared world objects on the co-op map at synced night, with deterministic spawn ids and engage-lock collision (GID-096 pattern).
- [ ] Night hunt drop boost scales with connected party member count; hunt completion is announced via HUD toast and recorded to co-op leaderboards.
- [ ] Host can trigger a "Siege" event on madrian from a dedicated HUD button (precedent: TID-380 Dungeon Crawl button); siege waves spawn deterministically and sync via world-object engage-locks.
- [ ] Siege culminates in a joint PvE boss battle (via GID-099 `_coop_pve` path and `CoopBattleScaling`); victory distributes rewards (gold, cards, achievements) to all session members and persists in SessionState.
- [ ] Single-player game is byte-for-byte unchanged (all co-op code guarded by `NetworkManager.is_active()`).
- [ ] All unit tests pass; headless import (`godot --headless --editor --quit`) reports no parse errors.
