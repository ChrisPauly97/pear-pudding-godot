# TID-336: Fix client crash when a co-op PvP battle launches

**Goal:** GID-092
**Type:** agent
**Status:** done
**Depends On:** —

## Context

When a co-op PvP battle is launched (challenge accepted), the **other player** (the one
who did not initiate) crashes. The host appears to enter the battle; the client dies.
Likely the same surface that depends on TID-335 in practice (you can't reach a battle
without a deck), but this is a distinct fault in the PvP launch/mirror path.

## Research Notes

- Challenge flow (scenes/world/WorldScene.gd):
  - `_request_challenge` (556) / `_accept_challenge` (633) → both call `_enter_pvp` (658).
  - `_enter_pvp` sets `local_idx = 0 if NetworkManager.is_host() else 1` and calls
    `SceneManager.enter_pvp_battle(local_idx, opponent_deck)`.
- `SceneManager.enter_pvp_battle` (autoloads/SceneManager.gd:389): detaches the WorldScene
  (kept alive), instantiates BattleScene named `"BattleScene"` (fixed RPC path
  `/root/BattleScene/BattleNetSync`), sets `_pvp`, `_local_player_idx`, `pvp_opponent_deck`,
  and a stub `enemy_data`.
- `BattleScene._ready` (scenes/battle/BattleScene.gd:131) → `_setup_pvp_battle` (1843):
  - Host builds decks (`_build_pvp_decks`, 1876), `start_turn(1)`, broadcasts initial state.
  - Client does **not** simulate; it retries `request_sync` in `_process` (1861) until the
    first mirror lands (`_last_applied_seq >= 0`), then `_on_pvp_state` (1924) rebuilds
    `_state` from the mirror.
- Suspect crash surfaces on the client:
  1. Rendering/`_ready` code that assumes a populated `_state` (e.g. board/hero views,
     `_apply_ui_sizes`, perspective accessors `_my_idx`/`_opp_idx` at 1817/1821) running
     before the first mirror arrives, while `_state` is a bare `GameState.new()` with no
     players/hand built.
  2. `enemy_data` stub missing a key that some `_ready` branch reads.
  3. `pvp_opponent_deck` shape mismatch (Array of Dictionaries vs. expected) when the
     client builds nothing but some code still dereferences it.
  4. A `class_name`/preload load-order issue along the BattleScene preload chain (see
     CLAUDE.md "Parse Errors Cascade" — a crash that looks like a render bug).
- Reproduce headlessly with the PvP smoke test: `godot --headless --path . -s
  tests/net_pvp_smoke.gd` (real ENet loopback: client intent → host apply → mirror). Also
  `tests/unit/test_pvp_protocol.gd` for encode/decode. Extend the smoke test to cover the
  client *scene* launch if the crash is in `_ready`, not just the protocol.
- Always run the headless import after edits (CLAUDE.md rule):
  `godot --headless --editor --quit 2>&1 | grep -iE "Parse Error|Compile Error|Failed to load script"`.

## Plan

Investigation (headless, Godot 4.4.1): the launch path is robust across every suspect in
the Research Notes. Reproductions tried, all crash-free:
- Isolated client `BattleScene` (`_pvp`, idx 1) through full `_ready`.
- Client applying a real encoded state mirror (`_on_pvp_state` → `from_dict` → render).
- A real two-peer ENet loopback with **two real `BattleScene` instances** (host idx 0 +
  client idx 1): client syncs from the host's broadcast over the real `BattleNetSync`
  relay with no crash.
- The seeded-deck path: host builds via `build_deck_from_instances` (rolled stats) →
  `to_dict` → client renders the deserialised mirror.

The premise in suspect #1 ("`_state` is a bare `GameState.new()` with no players/hand") is
false: `GameState._init()` always seeds two full default players, so the client renders a
valid placeholder until the first mirror lands. `CardInstance.to_dict/from_dict` is
symmetric, so no field is dropped across the mirror.

Conclusion: the user-visible "crash on launch" is gated behind **TID-335** — a cold co-op
session has an empty deck, so the only way to perceive a broken launch was the deck gate /
fallback path. With TID-335 seeding a deck, the launch is sound.

Deliverables for this task:
1. Defensive hardening on the client path that's cheap and correct: reconnect
   `_state.turn_ended` after a mirror replaces `_state` in `_on_pvp_state` (the new
   `GameState` was previously left without the connection), and guard `_setup_pvp_battle`
   so `_state`/`_net` are always valid.
2. A real regression smoke test, `tests/net_pvp_client_smoke.gd`, that stands up two real
   `BattleScene` peers over ENet loopback and asserts the client launches + syncs the first
   mirror without crashing — the explicit "extend the smoke test to cover the client scene
   launch" deliverable.

All changes stay under `_pvp` / `_is_pvp_client()` guards; single-player is untouched.

## Changes Made

- `scenes/battle/BattleScene.gd`: in `_on_pvp_state`, reconnect `_state.turn_ended` to
  `_on_turn_ended` after `from_dict` replaces `_state` with a fresh `GameState`. The
  `_ready` connection pointed at the discarded placeholder, so it was lost after the first
  mirror; the new state was left without it.
- `tests/net_pvp_client_smoke.gd`: new on-demand smoke test standing up **two real
  `BattleScene` peers** (host idx 0 + client idx 1) over ENet loopback. Asserts both launch
  without crashing in `_ready` and the client applies the host's first mirror over the real
  `BattleNetSync` relay — the explicit "extend the smoke test to cover the client scene
  launch" deliverable.

Investigation outcome: across every reproduction I could build headlessly (isolated client
`_ready`; client applying a real encoded mirror; the seeded-deck
`build_deck_from_instances`→`to_dict`→client-render path; and the two-peer real-scene
loopback above) the PvP launch path is **crash-free**. The Research Notes' lead suspect
(a "bare `GameState.new()` with no players") is false — `GameState._init()` seeds two full
default players, and `CardInstance.to_dict/from_dict` is symmetric, so the mirror never drops
a field. The user-visible "client crash" was gated behind TID-335 (a cold co-op session had
no deck, so the only broken-launch surface was the deck gate / fallback). With TID-335
seeding a deck the launch is sound; this task adds the regression coverage plus the
signal-reconnection hardening.

Verified: `net_pvp_client_smoke` PASS; `net_pvp_smoke` still PASS; full unit suite 1557/0;
headless import clean.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: documented client mirror application (placeholder state
  + signal reconnection) under the wire-format section, and added the new test row.
- `CLAUDE.md`: Bug Fix Learnings entry (reconnect signals when replacing a cached state
  object; no "bare state" exists because `GameState.new()` seeds players).
