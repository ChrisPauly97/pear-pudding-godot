# TID-331: Challenge handshake & SceneManager PvP routing

**Goal:** GID-091
**Type:** agent
**Status:** done
**Depends On:** TID-330

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wires the entry point: how a PvP battle is initiated from the shared co-op world
and how both peers transition into (and back out of) a PvP `BattleScene`. After
this task a player can walk up to the other player, both accept, and they land in a
synced battle that returns them to madrian when done.

## Research Notes

**Initiation pattern (mobile + desktop parity).** Reuse the existing interact-
prompt convention (the same UX as NPC duels / `_handle_interact`). `RemotePlayer`
(`scenes/world/entities/RemotePlayer.gd`) is currently a pure visual Node3D with
**no collision/proximity**. Add a lightweight proximity check in WorldScene's
co-op path: when the local player is within N tiles of a `RemotePlayer`, show a
"Challenge to Battle" prompt (reuse the existing interact prompt UI / a HUD
button so it works on touch). Pressing it sends a challenge.

Alternative considered: a persistent HUD "Challenge" button while a peer exists.
Either is acceptable; proximity matches the duel feel. Decide in Plan; ensure a
**tap target on mobile** (CLAUDE.md mobile/desktop parity rule).

**Challenge handshake (mutual accept) over RPC.** This is a *world-layer* event,
so it belongs on the existing world relay or a small extension of it. Options:
- Add `request_battle` / `respond_battle` RPCs to `scenes/world/NetSync.gd`
  (it already routes to WorldScene), OR
- Add them to NetworkManager-level signaling.

Recommend extending `NetSync` (world is where both players are when challenging):
```gdscript
@rpc("any_peer", "reliable", "call_remote")
func request_battle(from_id: int) -> void   # B shows "X challenges you. Accept?"
@rpc("any_peer", "reliable", "call_remote")
func respond_battle(accepted: bool) -> void # A learns the answer
```
On mutual accept, BOTH peers call into SceneManager to enter the PvP battle. The
**co-op host is the battle authority** regardless of who challenged (TID-329/330).

**SceneManager routing.** Study `_start_battle()` (instantiates
`_battle_scene_packed`, sets `enemy_data`, promotes to current_scene, sets
`_state = State.BATTLE`) and `enter_map_coop()`. Add an analogous
`enter_pvp_battle(opponent_peer_id, local_player_idx)`:
- Detach WorldScene (keep it alive to restore, like normal battles do via
  `_restore_world()` — do NOT free it; both peers must come back to the SAME
  madrian session).
- Instantiate BattleScene; set `_pvp = true`, `_local_player_idx`, and a minimal
  `enemy_data` describing the opponent (display name "Player", no drop_pool, no
  coin_reward, no boss). The opponent's **deck** is each player's own
  `SaveManager` deck: the host builds `players[0]` from its deck and `players[1]`
  from the client's deck. The client's deck must reach the host — send it in the
  challenge/accept payload (a serialized deck-instance array) OR have the client
  send it as the first intent. Decide in Plan; simplest is to include the
  challenger's & accepter's decks in the handshake so the host can build both
  sides authoritatively before broadcasting the initial state.
- Ensure the BattleScene root node name is identical on both peers so the
  TID-329 relay path (`/root/BattleScene/BattleNetSync`) matches. Set it
  explicitly if needed.
- Set `_state = State.BATTLE` (reuse the existing battle state; no new enum value
  needed unless cleaner).

**Initial-state bootstrap.** Only the host builds the canonical `GameState`
(`players[0]` = host deck, `players[1]` = client deck), draws both opening hands,
`start_turn(1)`, then immediately broadcasts `sync_state` so the client's
BattleScene populates from the mirror rather than building its own decks. The
client's BattleScene `_ready()` should, when `_pvp` and not host, skip deck build
and wait for the first `sync_state`.

**Decide who goes first.** Host is `current_player_idx == 0` and acts first by
default — acceptable. Document it.

**Restoring the world.** On battle end (TID-332 drives the result), both peers
call the existing `_restore_world()`-style path to re-attach madrian. Crucially the
co-op session (`NetworkManager`) must stay active — do NOT call
`NetworkManager.leave()`. RemotePlayer avatars resume from the live world relay.

**CLAUDE.md:** guard everything by `NetworkManager.is_active()` / `_coop_active`;
preload scripts; explicit types; headless import after edits. Mobile tap target
for the challenge prompt.

## Plan

Proximity challenge via a HUD button (mobile+desktop parity). Handshake on the
world relay (`NetSync`): `request_battle(deck)` / `respond_battle(accepted, deck)`.
Each peer carries its own deck in the handshake so the host can build both sides.
On mutual accept both peers call `SceneManager.enter_pvp_battle(local_idx,
opponent_deck)` (host = idx 0). World is detached but kept alive; co-op session is
preserved by making `_setup_coop`/`_teardown_coop` idempotent and re-running setup
from `_enter_tree` on world re-attach.

## Changes Made

- **`scenes/world/NetSync.gd`** — added reliable `request_battle` / `respond_battle`
  RPCs routing to WorldScene handlers.
- **`scenes/world/WorldScene.gd`** — challenge HUD button (`_ensure_challenge_button`,
  shown by `_update_challenge_proximity` when within `_CHALLENGE_RANGE` of a
  RemotePlayer, called from `_process`); handshake (`_request_challenge`,
  `_on_battle_requested` + Accept/Decline panel, `_on_battle_responded`,
  `_accept_challenge`/`_decline_challenge`, `_enter_pvp`); `_local_deck_for_net()`
  enforces `DECK_MIN`. **Co-op preservation across the battle detach:** added
  `_enter_tree()` re-setup, `_initial_ready_done` flag, made `_setup_coop` guard
  against double-init and reuse the existing `NetSync`, and `_teardown_coop` now
  leaves `NetSync` alive and only flips `_coop_active` so re-entry reconnects.
- **`autoloads/SceneManager.gd`** — `enter_pvp_battle(local_player_idx,
  opponent_deck)` (detaches+keeps the world, instantiates a fixed-name
  `BattleScene`, sets `_pvp`/`_local_player_idx`/`pvp_opponent_deck` + minimal
  duel-style `enemy_data`); `_on_pvp_battle_ended` restores the shared world (or
  routes to menu if the session ended); `pvp_battle_ended` connected; `_on_battle_fled`
  routes PvP flee to `BattleScene._pvp_surrender`.
- Headless import clean; full unit suite passes (1554, exit 0).

## Documentation Updates

Documented holistically in TID-333.
