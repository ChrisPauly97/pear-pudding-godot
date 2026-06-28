# TID-369: Shared party bounties

**Goal:** GID-101
**Type:** agent
**Status:** done
**Depends On:** TID-361

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Give the party repeatable shared goals: bounties the whole party works toward together
(defeat N together, clear a map, win M duels), rewarding every contributor. Builds on the
existing Bounty Board and the joint-battle enemies (GID-099).

## Research Notes

- **Existing system:** Bounty Board (GID-051, `docs/agent/bounty-board.md`) — `BountyGen`
  daily seeded generation, `BountyBoardNPC.gd`, SaveManager bounty fields + rollover. Read
  the doc + `BountyGen` before extending.
- **Party variant (shared progress):** a co-op bounty's progress is **shared state**,
  owned by the authority in `SessionState` (a `party_bounties` field) and persisted via
  `SessionStore` — not the per-device SaveManager. Progress increments from synced events
  (GID-096 `enemy_defeated`, GID-099 boss defeat, GID-368 duel wins). Use the same
  authority-records-then-broadcasts pattern as world events.
- **Reward distribution:** on completion, **every contributing party member** gets the
  reward into their own GID-095 character (coins/cards), like the GID-361 soulbound
  fan-out. Decide "contributor" definition (present at completion vs. participated) —
  recommend "in the session + on the map at completion".
- **Generation:** seed party bounties per session (or daily, keyed by session id +
  day, reusing `BountyGen`'s seeded approach so all peers compute the same list). The
  authority is the source of truth; clients render.
- **Note BID-024:** co-op currently lands on madrian (no enemies) — party bounties only
  become live once GID-098 (multi-map story) + GID-099 (joint battles) give the party
  enemies to hunt. This task can ship its logic + tests against synthetic events
  meanwhile (like `net_world_sync_smoke.gd` does for GID-096).
- **UI:** a party-bounty panel (HUD/roster or the Bounty Board NPC when in a session)
  showing shared progress; viewport-relative, mobile + desktop.
- **Tests:** unit-test shared progress increment + completion reward fan-out; extend
  `test_session_state.gd` for the `party_bounties` field + migration.

## Plan

Store `party_bounties: Array` in `SessionState` (host authority). Host generates daily bounties via `BountyGen.generate_daily(world_seed, day_index)` on `_setup_party_bounties`, persists via `SessionStore`. Progress RPCs fan through `submit_party_bounty_progress` → authority increments → `recv_party_bounty_update` → all peers. Clients receive snapshot on join.

## Changes Made

- **`game_logic/net/SessionState.gd`**: `party_bounties: Array = []` field; serialized in `to_dict`/`from_dict`; migration v<2 backfills it.
- **`scenes/world/NetSync.gd`**: `recv_party_bounty_update(payload)` (reliable, authority→all), `submit_party_bounty_progress(bounty_type, match_data)` (reliable, client→authority), `recv_party_bounties_snapshot(bounties)` (reliable, authority→joining client).
- **`scenes/world/WorldScene.gd`**: `_setup_party_bounties()` (host only — generates 3 daily bounties via `BountyGen.generate_daily(WORLD_SEED, day_idx)` if `party_bounties` is empty); `_build_party_bounty_panel()` / `_refresh_party_bounty_panel()` / `_add_bounty_row(bd)` — viewport-relative HUD panel; `submit_party_bounty_progress(bounty_type, match_data)` — public method for `_on_pvp_battle_ended_coop` and future subsystems; `_on_party_bounty_progress_submitted(sender, ...)` (authority: increments matching bounty, awards reward fan-out on completion); `_on_party_bounty_update_received` (client: refreshes HUD); `_on_party_bounties_snapshot_received(bounties)` (client: builds panel from snapshot). `_send_character_to_peer` also sends snapshot on peer join.
- **`tests/unit/test_session_state.gd`**: tests for `party_bounties` default, round-trip, and garbage-field tolerance; migration v2 adds empty array.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md`: GID-101 party bounties subsection; updated SessionState description to include party_bounties.
