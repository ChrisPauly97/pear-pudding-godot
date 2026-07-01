# BID-025: Ghost duels are host-only — a client has no roster to pick a ghost from

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
