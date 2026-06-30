# TID-372: Reconnect into in-progress PvP battle

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/agent/multiplayer-coop.md` states *"there is still no reconnection into an in-progress
PvP battle."* Today a mid-duel disconnect is a **forfeit win** for the remaining player. This
task lets a player who drops rejoin (matched by identity token) and resume the live duel via
the host's existing state mirror.

## Research Notes

- **Authoritative model already fits.** PvP is host-authoritative state-mirroring (GID-091):
  the host owns the canonical `GameState` and broadcasts `sync_state` mirrors; the client is
  a thin renderer that rebuilds `_state` from each mirror via `from_dict`
  (`_on_pvp_state`). A reconnecting client therefore just needs the **current mirror** —
  there is no client-side simulation to rebuild. The `request_sync` RPC
  (`BattleNetSync.gd:42`) already exists precisely to handle "my scene is up, send me the
  state," used today for the startup race — reuse it for reconnect.
- **What blocks it today.** On disconnect the host currently treats it as a forfeit and ends
  the battle (`_on_pvp_ended` / opponent-disconnect → forfeit win, per docs "Rewards & end
  states"). To support reconnect the host must instead **pause** the duel for a grace window
  before declaring forfeit.
- **Token-matched rejoin.** Reconnection of the *session* (world) already resumes a player's
  character + position keyed by `MpProfile.get_token()` (GID-095, `peer_id → token` map,
  one-tap Rejoin list in `MultiplayerLobbyScene`). Extend this: when a peer reconnects, the
  host checks whether that **token** was a combatant in a still-pending duel (track
  `_pvp_combatant_tokens` on the authority alongside the existing `peer_id → idx` maps). If
  so, route the rejoiner into `enter_pvp_battle` with the right `local_player_idx` and have
  it `request_sync`.
- **Grace window.** On `peer_disconnected` during an active duel, start a timer (e.g. 30–60 s)
  instead of immediately forfeiting; pause turn-timeout if any. If the timer expires with no
  rejoin → existing forfeit path. If the token rejoins first → cancel timer, re-mirror.
- **Scene lifetime.** WorldScene is detached-but-alive during a PvP battle and re-attaches on
  return (`_enter_tree` re-runs `_setup_coop`, idempotent — see GID-091 Flow step 4). The
  reconnecting peer, however, comes in cold: it must navigate menu → join → land in the duel.
  Confirm SceneManager can route a fresh client straight into `enter_pvp_battle` from the
  connection handshake (it routes into `enter_map_coop` today; add the duel-redirect analogous
  to the GID-098 late-joiner `recv_map_transition` redirect).
- **Dedicated server (GID-097).** On a dedicated server neither client is the host; the server
  is the referee (`enter_pvp_referee`, `_pvp_peer_to_idx`). The same grace-window + re-mirror
  logic applies there — verify both paths.
- **Scope guard.** Keep it to **PvP** (2-player and, if TID-371 lands, team duels by
  extension). Co-op-PvE reconnect can be a follow-up.
- **Tests:** `tests/net_pvp_reconnect_smoke.gd` (loopback): start duel → drop client →
  reconnect same token within grace → host re-mirrors → client resumes. Mirror
  `net_pvp_client_smoke.gd`.
- **Docs:** update `docs/agent/multiplayer-coop.md` (remove/qualify the "no reconnection into
  an in-progress PvP battle" limitation; document the grace window + token-match).

## Plan

**Key architectural finding that reshapes the task notes' suggested approach:** the task
notes propose authority-side token tracking via the WorldScene identity handshake
(`_session_token_by_peer`, `_on_identity_received`). That handshake **cannot run while a
PvP battle is active**, on either transport: `enter_pvp_battle`/`enter_pvp_referee` both
detach **WorldScene** (`get_tree().root.remove_child`) on every peer that's mid-duel,
including the dedicated server's own WorldScene when it's refereeing. Since
`NetSync`/the identity broadcast/reply and the GID-095 character handshake all live on
WorldScene, a peer reconnecting mid-duel cannot complete a normal join — its identity
broadcast has no live `/root/WorldScene/NetSync` to land on. **`BattleScene` /
`BattleNetSync`, by contrast, stay alive at a fixed path
(`/root/BattleScene/BattleNetSync`) on every participant for the whole duel** — this is
the one stable channel reconnect can use.

**Design:** the reconnecting **client** decides locally (no host-side identify needed) to
skip the normal map-join and go straight back into `enter_pvp_battle`, using its own
remembered duel state; the **host/referee** accepts this re-entry via a grace-window +
lightweight token-announce RPC on `BattleNetSync` (no WorldScene involvement either).

1. **`autoloads/NetworkManager.gd`**: small in-memory (not persisted to disk —
   session-scoped) "pending PvP resume" record: `_pvp_resume: Dictionary = {}`.
   `set_pvp_resume(local_idx, opponent_deck, ante_coins)` / `clear_pvp_resume()` /
   `has_pvp_resume() -> bool` / `get_pvp_resume() -> Dictionary`. Cleared on `leave()`
   (via `_reset_session`) so an intentional disconnect never auto-resumes.
2. **`scenes/battle/BattleScene.gd`** (client side): `_setup_pvp_battle` calls
   `NetworkManager.set_pvp_resume(_local_player_idx, pvp_opponent_deck, pvp_ante_coins)`
   when `_is_pvp_client()` (not for the host/referee — only the client reconnects in this
   slice, consistent with `session_ended` already ending things for a dropped host).
   `_finish_pvp` calls `NetworkManager.clear_pvp_resume()` so a normal battle end doesn't
   leave a stale resume record.
3. **`scenes/ui/MultiplayerLobbyScene.gd`** `_on_connection_succeeded`: if
   `NetworkManager.has_pvp_resume()`, call `SceneManager.enter_pvp_battle(idx, deck,
   ante)` from the cached record instead of `enter_map_coop`. `_setup_pvp_battle`'s
   existing `request_sync` retry loop (`_process`) then naturally re-syncs once
   connected — no new sync-side logic needed.
4. **Token plumbing for host-side verification:**
   - `WorldScene._enter_pvp`/`_enter_pvp_wagered`: resolve the opponent's token via
     `_session_token_by_peer.get(_challenge_target_peer, "")` and pass it through
     `SceneManager.enter_pvp_battle`'s new `opponent_token: String = ""` parameter →
     `_battle_overlay.set("pvp_opponent_token", ...)`.
   - `WorldScene._on_relay_pvp_response` (dedicated server): pass
     `_session_token_by_peer.get(challenger/target, "")` through a new
     `enter_pvp_referee(..., token_a, token_b)` parameter → stored in BattleScene as
     `_pvp_idx_to_token: Dictionary`.
5. **`scenes/battle/BattleScene.gd`** (host/referee side):
   - `_on_pvp_peer_disconnected(pid)`: stop forfeiting immediately. Resolve `idx` for
     `pid` (listen-server: always 1, the sole client; referee: `_pvp_peer_to_idx.get(pid)`).
     Record `_pvp_reconnect_idx = idx`, start a 45 s `Timer`
     (`_pvp_reconnect_timer`, one-shot) wired to the existing forfeit path
     (`_finish_pvp`/broadcast `pvp_ended` with `forfeit: true`) as its `timeout` handler.
     Do **not** call `_finish_pvp` synchronously anymore for this signal.
   - New `BattleNetSync` RPC `announce_reconnect(token: String)` (reliable, any_peer) →
     `BattleScene._on_reconnect_announced(sender, token)`: if a reconnect is pending
     (`_pvp_reconnect_idx != -1`) and the token matches the recorded opponent token for
     that idx (or no token was recorded — logged-warning fallback, since refusing is
     worse than a same-LAN false accept), cancel the timer, clear
     `_pvp_reconnect_idx = -1`, and for referee mode remap
     `_pvp_peer_to_idx[sender] = idx` (replacing the stale old peer id — also prune the
     old id from the dict). Listen-server needs no peer-id remap (broadcasts already
     reach "all connected peers"; incoming-intent routing is hardcoded idx 1 regardless
     of peer id). Finally re-broadcast the current state so the rejoined client's
     `request_sync` (sent moments earlier by `_setup_pvp_battle`) gets a fresh mirror —
     `request_sync`'s existing handler already does this once `_is_pvp_host()`, no change
     needed there.
   - Client side sends `announce_reconnect(MpProfile.get_token())` once, right after
     `_setup_pvp_battle` registers `_net` (alongside the existing `request_sync` retry
     loop — send once in `_setup_pvp_battle` rather than every retry tick, since it's
     idempotent on the host but no need to spam it).
6. **Scope guard (explicit, matches the task notes):** 2-player PvP only. Team duels
   (TID-371) are NOT covered — `_team_pvp`'s disconnect handling is untouched (still
   immediate-forfeit via its own `_on_pvp_peer_disconnected`... actually team PvP reuses
   the same `_on_pvp_peer_disconnected`/`_finish_pvp` path; gate the new grace-window
   logic on `_pvp` specifically (not `_team_pvp`/`_coop_pve`) so team duels and co-op PvE
   keep their current immediate-forfeit-or-equivalent behavior unchanged). Spectators
   (`_pvp_spectating`) are unaffected — they were never part of the grace/forfeit logic.
7. **Tests:** new `tests/net_pvp_reconnect_smoke.gd` (real ENet loopback, mirrors
   `net_pvp_client_smoke.gd`): host + client start a duel, client peer disconnects
   mid-battle (simulated via `NetworkManager.leave()`/peer close on that side), host
   does NOT forfeit immediately (grace timer running), a **new** ENet connection joins
   claiming the same token via `announce_reconnect`, host resumes (cancels timer,
   re-broadcasts), asserts no `pvp_ended` forfeit fired and the new connection receives
   a live mirror.
8. **Docs:** update `docs/agent/multiplayer-coop.md` — qualify/replace the "no
   reconnection into an in-progress PvP battle" limitation line; document the grace
   window + client-initiated-resume design and *why* it bypasses WorldScene (the
   detachment finding above).

Moderate complexity, but the design is now fully converged and contained (additive,
gated on `_pvp` only, no changes to existing 2-player PvP message flow beyond the new
`announce_reconnect` RPC and the disconnect handler's immediate-vs-delayed forfeit).
Proceeding directly to Build.

## Changes Made

- **`autoloads/NetworkManager.gd`**: new in-memory `_pvp_resume` record +
  `set_pvp_resume`/`clear_pvp_resume`/`has_pvp_resume`/`get_pvp_resume`. `leave()`
  clears it; `_reset_session()` (called by `join()`/`host()` too) deliberately does
  **not**, so the record survives the disconnect→rejoin cycle it exists to recover from.
- **`scenes/battle/BattleScene.gd`**:
  - New vars: `pvp_opponent_token`, `_pvp_idx_to_token` (referee), `_pvp_reconnect_idx`,
    `_pvp_reconnect_timer`, `_PVP_RECONNECT_GRACE_SECONDS = 45.0`.
  - `_setup_pvp_battle`: the client branch now calls `NetworkManager.set_pvp_resume(...)`
    and sends `announce_reconnect(MpProfile.get_token())` once (no-op on a fresh
    non-reconnect start).
  - `_on_pvp_peer_disconnected`: no longer forfeits immediately for `_pvp` — resolves
    the disconnecting combatant's idx (listen-server: always 1; referee:
    `_pvp_peer_to_idx`), starts a 45 s one-shot grace `Timer`. Team duels/co-op PvE are
    untouched (gated on `_pvp` specifically).
  - New `_on_pvp_reconnect_grace_expired`: grace-timeout fallback, same shape as the
    original immediate-forfeit code.
  - New `_on_reconnect_announced(sender, token)`: validates the announced token against
    the recorded opponent token (missing-token fallback accepts — same-LAN trust
    model), cancels the timer, remaps `_pvp_peer_to_idx` for referee mode (listen-server
    needs no remap), re-broadcasts state.
  - `_on_pvp_session_ended`: returns early (no false "win", no teardown) when this is
    the client and a resume record is pending, instead of always forfeiting.
  - `_finish_pvp`: now calls `NetworkManager.clear_pvp_resume()` (every genuine
    end-of-duel path funnels through here).
- **`scenes/battle/BattleNetSync.gd`**: new `announce_reconnect(token)` reliable RPC.
- **`autoloads/SceneManager.gd`**: new `resume_pvp_battle(local_player_idx,
  opponent_deck, ante_coins)` — lands in the shared map first (`enter_map_coop`),
  `await`s the world transition actually completing (`TransitionManager.transition` is
  fire-and-forget async), then calls the normal `enter_pvp_battle` (now reachable since
  `_state == State.WORLD`). `enter_pvp_battle` gained an `opponent_token` param;
  `enter_pvp_referee` gained `token_a`/`token_b` params.
- **`scenes/world/WorldScene.gd`**: `_enter_pvp`/`_enter_pvp_wagered` resolve and pass
  the opponent's token via `_session_token_by_peer`; `_on_relay_pvp_response`
  (dedicated server) does the same for both combatants into `enter_pvp_referee`.
- **`scenes/ui/MultiplayerLobbyScene.gd`**: `_on_connection_succeeded` checks
  `NetworkManager.has_pvp_resume()` first and routes to `SceneManager.resume_pvp_battle`
  instead of the normal `enter_map_coop` landing when set.
- **Tests**: new `tests/net_pvp_reconnect_smoke.gd` (real ENet loopback): duel
  starts+syncs, client disconnects (asserts grace window, not forfeit), a new
  connection reconnects + announces, asserts the host resumes (no forfeit) and the
  new client syncs. Full suite 1729 passing (unchanged); all 10 existing net smoke
  tests green (no regressions in 2-player PvP / dedicated-server / co-op / discovery /
  session / world-sync paths); headless import clean.

**Key design deviation from the task notes** (documented, not silent): the task notes
proposed authority-side token tracking via the WorldScene identity handshake. Research
found this **cannot work** — `enter_pvp_battle`/`enter_pvp_referee` detach WorldScene
(and thus `NetSync`/the identity handshake) on every mid-duel peer, including the
dedicated server's own WorldScene while refereeing. The implemented design instead has
the **reconnecting client decide locally** (via `NetworkManager`'s resume record) to
re-enter `enter_pvp_battle` directly, verified host-side via a new lightweight
`announce_reconnect` RPC on the always-alive `BattleNetSync` — see the new docs
subsection for the full reasoning.

**Scope cuts (documented, not silent)**: 2-player PvP only (team duels and a dropped
host/referee still end immediately); no "Reconnecting…" UI — the player navigates back
to the lobby manually (existing pause-menu / Rejoin-list precedent, no auto-navigation
on `session_ended`); the same-process smoke-test constraint means token *mismatch*
rejection isn't exercised by `net_pvp_reconnect_smoke.gd` (only the missing-token
accept-fallback path, which is real production behavior, not a test gap requiring a
backlog item — `MpProfile` is a process-wide singleton, so two distinct tokens can't
coexist in one test process; this mirrors the same limitation noted for other
single-process net smoke tests).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: updated the "no reconnection into an in-progress
  PvP battle" limitation line; new "Reconnecting into an in-progress duel (GID-102 /
  TID-372)" subsection under PvP Card Battles (the WorldScene-detachment finding,
  the client-decides-locally design, token verification, resume-record lifecycle,
  scope cuts); updated the "opponent disconnect" line in Rewards & end states; added
  the `net_pvp_reconnect_smoke.gd` row to the Tests table.
