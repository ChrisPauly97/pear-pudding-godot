# BID-032: Ghost duels are host-only — a client has no roster to pick a ghost from

**Type:** gap (feature completeness)
**Discovered during:** GID-102 / TID-377 (Ghost duels vs stored deck snapshots)
**Severity:** low

## Context

TID-377 added ghost duels: a local, AI-piloted battle against a snapshot of another session
member's deck, derived on demand via `SessionState.get_ghost_snapshot(token)`. The natural
data source is `SessionStore.get_state().members` — but `SessionStore` is only ever opened
on the **authority** (the host in the listen-server model; see `WorldScene._setup_session`,
which explicitly early-returns for non-hosts: "clients adopt later, in
`_on_character_received`"). A client never has a local `SessionState` to read.

So the "Ghost Duels" HUD button (`WorldScene._ensure_ghost_duel_button`, gated on
`SessionStore.is_open()`) only ever appears for the host. A client in the same co-op session
currently has no way to see the roster or launch a ghost duel at all.

## Why this was left out of TID-377's scope

Extending this to clients needs a new wire message: the host would have to push a
`{token, name, rating}` roster snapshot to each client (mirroring how
`recv_party_bounties_snapshot` / `_send_character_to_peer` already push other session-derived
data at identify-time and periodically), and the client would need its own copy of
`get_ghost_snapshot`'s *result* (not the full `SessionState`, which is authority-only) — i.e.
the host would need to resolve the snapshot for a client-requested token and send it over,
similar to how `_leaderboard_lookup_by_token` patterns work elsewhere in this codebase. That's
a reasonably self-contained follow-up task, not a one-line fix, so it was deliberately left
for later rather than scope-creeping TID-377.

## Suggested fix (future task)

1. New reliable RPC, e.g. `NetSync.request_ghost_roster()` (client → host) and
   `NetSync.recv_ghost_roster(rows: Array)` (host → client), rows being the same
   `{token, name, rating}` shape `_toggle_ghost_duel_overlay` already builds locally for the
   host's own overlay.
2. New reliable RPC `NetSync.request_ghost_snapshot(token: String)` (client → host) and
   `NetSync.recv_ghost_snapshot(snapshot: Dictionary)` (host → client) so a client can resolve
   a specific opponent's deck without ever touching `SessionStore` directly.
3. `GhostDuelOverlay` already accepts plain `{token, name, rating}` rows and an
   `on_duel_requested(token)` callback — no changes needed there; only the *source* of the
   rows and the snapshot resolution differ for a client (RPC round-trip instead of a direct
   `SessionStore.get_state()` call).
4. `SceneManager.enter_ghost_duel` is already snapshot-shape-agnostic (just needs
   `{name, deck}`), so no changes needed there either.

## Impact if unaddressed

Ghost duels remain a host-only convenience feature. Not a regression (net-new feature,
correctly scoped and documented as host-only in `docs/agent/multiplayer-coop.md`), but a
completeness gap worth closing so every session member can use the feature symmetrically.

## Note on ID numbering

Originally filed as BID-025 from an isolated worktree (branched before BID-025 was claimed
elsewhere for an unrelated finding); renumbered to BID-032 during integration.

## Resolution

Implemented exactly the suggested fix: two round-trip RPCs on `scenes/world/NetSync.gd`,
both routed to `scenes/world/coop/CoopSocial.gd` (the module that already owned the
host-only ghost-duel overlay logic):

- `request_ghost_roster()` (client → host) / `recv_ghost_roster(rows: Array)` (host →
  client) — `rows` is the same `{token, name, rating}` shape the host's own overlay
  build already used, sent as-is (mirrors `recv_party_bounties_snapshot` /
  `recv_leaderboard`).
- `request_ghost_snapshot(token: String)` (client → host) / `recv_ghost_snapshot(snapshot:
  Dictionary)` (host → client) — `snapshot` is `SessionState.get_ghost_snapshot()`'s
  output (or `{}` if unresolvable).

`CoopSocial.gd` changes:
- `_ghost_roster_rows(exclude_token)` — new helper extracted from the old inline roster
  build, shared by the host's local overlay open and the new `_on_ghost_roster_requested`
  handler so both compute identical rows.
- `_toggle_ghost_duel_overlay()` — now gated on `NetworkManager.is_active()` instead of
  `SessionStore.is_open()`. The host still populates the overlay immediately from its own
  `SessionStore`; a client opens it empty and sends `request_ghost_roster`.
- `_request_ghost_duel(token)` — new helper wired as `GhostDuelOverlay.on_duel_requested`.
  Host resolves the snapshot directly (unchanged); a client sends `request_ghost_snapshot`.
- Four new handlers: `_on_ghost_roster_requested` / `_on_ghost_roster_received` /
  `_on_ghost_snapshot_requested` / `_on_ghost_snapshot_received`, following the existing
  `_on_<rpc>_requested/received` naming convention used throughout the file.

`scenes/world/coop/CoopSession.gd`: `_open_party_panel()`'s `panel.show_ghost_duels` gate
changed from `SessionStore.is_open()` to `NetworkManager.is_active()` so the Party-panel
action now shows for clients too.

`GhostDuelOverlay.gd` and `SceneManager.enter_ghost_duel` needed **no code changes** — both
were already shape-agnostic, exactly as anticipated in the "Suggested fix" section above;
only their doc comments were updated to describe the now-dual host/client data source.

**Verification:** `godot --headless --editor --quit` parse-clean; full unit suite
(`tests/runner.gd`) 2374 passed / 0 failed / 1 pre-existing pending; `tests/world_scene_smoke.gd`
18/18 checks passed (confirms all 4 new RPC handlers resolve and dispatch cleanly through
`NetSync._route()`, including a cold call with empty/default synthesized arguments); the
existing live-networking smoke tests (`net_session_smoke.gd`, `net_coop_smoke.gd`,
`net_coop_npeer_smoke.gd`, `net_world_sync_smoke.gd`, `net_leaderboard_smoke.gd`) still pass
unchanged.

No new unit-test file was added specifically for this RPC pair — the round-trip is thin
enough (a request forwarded to an existing pure query, `SessionState.get_ghost_snapshot`,
which already has full unit coverage in `test_session_state.gd`) that the smoke-test
coverage above (real `_route()` dispatch through both new request/response handler pairs)
was judged sufficient; a dedicated live 2-peer ghost-duel scenario test would mostly
re-verify Godot's RPC plumbing rather than new logic.
