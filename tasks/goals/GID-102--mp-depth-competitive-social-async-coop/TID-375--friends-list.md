# TID-375: Token-keyed friends list + online status

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players can meet in a session but cannot **remember each other**. This task adds a persistent,
device-local friends list keyed by the stable identity token (GID-094), with add-from-roster,
friend labels, and online/offline status surfaced in the lobby and session roster.

## Research Notes

- **Storage — `autoloads/MpProfile.gd`.** `MpProfile` already persists device-local data to
  `user://mp_profile.json` (token, name, color, `recent_servers` capped/deduped list — see
  `multiplayer-coop.md` → "Reconnection & recent servers"). Add a parallel `friends` list:
  `{token, name, color_hex, last_seen}`, deduped by token, with `add_friend(...)`,
  `remove_friend(token)`, `get_friends()`, `is_friend(token)`. Persist exactly like
  `recent_servers` (same dirty/write path). This is **device-local**, not session state — it
  works cold from the menu, consistent with how `MpProfile` is deliberately separate from the
  game save.
- **Add from roster.** The session roster (WorldScene `_build_coop_roster`) lists connected
  peers with token/name/color (from `_remote_identities`). Add an "Add friend" affordance per
  remote entry → `MpProfile.add_friend(...)`. The token is the join key (already exchanged in
  the identity handshake, `NetSync.recv_identity`).
- **Online status.** "Online" is only knowable for peers in the **current** session
  (`multiplayer.get_peers()` + the identity map). There is no global presence service (no
  matchmaking backend — out of scope). So: in the **lobby**, mark a friend "online here" if
  their token is among the connected peers, and show their `last_seen` otherwise; in the
  **recent-servers/Rejoin list**, you could hint "a friend is on this server" only if a
  discovery reply carried tokens — it does not today, so keep status to in-session presence.
  Update `last_seen` whenever a friend's token is seen in a session.
- **Lobby integration — `scenes/ui/MultiplayerLobbyScene.gd`.** Add a "Friends" section
  (above or beside Rejoin / Find Games) listing saved friends with color swatch + name +
  online/last-seen. Keep it viewport-relative + rebuilt on resize (existing pattern). No
  global "invite" (no presence backend) — a friend entry can pre-fill a join when you know
  their server via the recent-servers entry; keep the coupling light.
- **Privacy/sanity:** cap the friends list (e.g. 50), sanitize stored names (reuse the
  identity decode defaults). No tokens are ever displayed (token is opaque, never shown — per
  GID-094 rule).
- **Tests:** `tests/unit/test_mp_profile_friends.gd` (or extend an existing MpProfile test if
  present) — add/remove/dedupe/cap, persistence round-trip via a temp `user://` path.
- **Docs:** update `docs/agent/multiplayer-coop.md` (identity/MpProfile subsection).

## Plan

1. **`autoloads/MpProfile.gd`** — add `_friends: Array` (loaded/persisted in `_ensure_loaded`/`_save`,
   mirroring `_recent_servers`), `_MAX_FRIENDS = 50`. New API:
   - `add_friend(token, name, color_hex) -> void` — idempotent upsert by token (re-adding updates
     name/color_hex/last_seen, moves to front, same dedupe pattern as `add_recent_server`). Sanitizes
     name/color via the same robust-default rules as `PlayerIdentity.decode` (blank name -> "Player",
     invalid hex -> "ffffff"). No-op on blank token. Caps at `_MAX_FRIENDS` by dropping the oldest
     `last_seen` entry when exceeded (since the list is already most-recent-first via push_front, this
     is just a trim to size, consistent with `add_recent_server`'s `resize`).
   - `remove_friend(token) -> void` — drop matching entry, persist.
   - `get_friends() -> Array` — duplicated copy, most-recent-first (mirrors `get_recent_servers`).
   - `is_friend(token) -> bool` — token lookup.
   - `touch_friend_last_seen(token) -> void` — update `last_seen` for an existing friend only (no-op /
     no upsert if not already a friend); persists.
2. **`game_logic/net/PlayerIdentity.gd`** — no changes needed; its `decode()` already provides the
   sanitization pattern to mirror (reused directly in `add_friend`, not duplicated).
3. **`scenes/world/WorldScene.gd`** — extend the roster:
   - `_add_roster_row` gains an optional "add friend" button for remote (non-"(you)") entries: pass
     the peer's token through `_refresh_coop_roster` so the row can call
     `MpProfile.add_friend(token, name, color_hex)` and toggle to a "Friend" indicator via
     `MpProfile.is_friend(token)`.
     - Concretely: change `_add_roster_row(text, col)` to `_add_roster_row(text, col, token := "")`;
       when `token != ""`, append a small square button (viewport-relative sizing) showing "+" (not a
       friend) or a checkmark glyph (already a friend, disabled/non-interactive).
   - `_refresh_coop_roster` calls `MpProfile.touch_friend_last_seen(token)` for every remote peer
     token currently in `_remote_identities` (covers "Update last_seen whenever a friend's token is
     observed").
4. **`scenes/ui/MultiplayerLobbyScene.gd`** — add a "Friends" section: viewport-relative, rebuilt on
   resize like Rejoin/Find-Games. Lists `MpProfile.get_friends()` as swatch + name + status line
   ("Online here" if the friend's token is found among `_remote_identities`-equivalent — but the lobby
   itself has no active NetSync/session, so realistically this only fires if the lobby is later reused
   post-connect; otherwise shows "Last seen <date>" from `last_seen`, sanitized/formatted). No
   join-shortcut added (documented as skipped per task guidance — keeping coupling light; recent-servers
   already covers one-tap rejoin for sessions a friend hosted).
5. **Tests** — new `tests/unit/test_mp_profile_friends.gd` following `test_save_manager.gd`'s
   snapshot/restore pattern for live-autoload state (no risk to the real `mp_profile.json` since we
   only mutate in-memory arrays directly via the public API and restore via snapshot, never call
   `_ensure_loaded`'s file path differently). Cases: add new friend, re-add same token updates not
   duplicates, remove, is_friend true/false, cap eviction at 50, sanitization of blank name / invalid
   color hex, touch_last_seen updates an existing friend and no-ops for a non-friend, get_friends
   returns a defensive copy. Add `.gd.uid` sidecar.
6. **Docs** — add a new "#### Friends list (GID-102 / TID-375)" sub-subsection in
   `docs/agent/multiplayer-coop.md` right after the "Reconnection & recent servers" subsection, plus a
   row in the Tests table.
7. Validate: headless import clean, full test suite passes increased by the new test count.
8. Fill in Changes Made / Documentation Updates, release lock, commit.

## Changes Made

- **`autoloads/MpProfile.gd`**: added `_friends: Array` + `_MAX_FRIENDS = 50`, loaded/saved
  alongside `_recent_servers` in `_ensure_loaded`/`_save`. New public API:
  `add_friend(token, name, color_hex)` (idempotent upsert by token, dedupe/move-to-front/cap
  identical to `add_recent_server`, sanitizes blank name → `DEFAULT_NAME` and invalid hex →
  `"ffffff"`, no-ops on a blank token), `remove_friend(token)`, `get_friends() -> Array`
  (defensive copy), `is_friend(token) -> bool`, `touch_friend_last_seen(token)` (updates only
  an existing friend, never upserts).
- **`scenes/world/WorldScene.gd`**: `_add_roster_row` gained an optional `token` parameter
  (empty for the local "(you)" row). Remote roster rows now render a small "+ Add friend"
  button that calls `MpProfile.add_friend(...)`, swapping to a disabled "✓ Friend" indicator
  once `MpProfile.is_friend(token)` is true. `_refresh_coop_roster` now calls
  `MpProfile.touch_friend_last_seen(token)` for every remote peer's token currently in
  `_remote_identities`, so a friend's `last_seen` advances automatically while co-present in
  a session.
- **`scenes/ui/MultiplayerLobbyScene.gd`**: new "Friends" section (viewport-relative, rebuilt
  on `NOTIFICATION_RESIZED` like the existing Rejoin/Find-Games rows) listing
  `MpProfile.get_friends()` as a color swatch + name + status line ("Online here" vs.
  "Last seen <timestamp>"). `_online_friend_tokens()` checks `NetworkManager.is_active()` and
  reads `WorldScene._remote_identities` via `get_node_or_null` + `get()` (no direct reference
  available from the lobby). No invite mechanism and no join-shortcut were added — both
  intentionally skipped per task scope (no presence backend to back an invite; a friend's
  server, if known, is already one-tap-rejoinable via the existing recent-servers list).
- **`tests/unit/test_mp_profile_friends.gd`** (+ `.gd.uid`): 17 new test cases covering
  add/dedupe-by-token/move-to-front, blank-token no-op, name/color sanitization, remove
  (existing + missing), `is_friend` true/false/blank, 50-entry cap eviction (newest survives,
  oldest evicted), `touch_friend_last_seen` (updates existing, no-op for non-friend),
  `get_friends` defensive-copy semantics, and a JSON persistence-shape round-trip via a
  scratch `user://` file (cleaned up, never touches the real `mp_profile.json`).
- The token is never displayed anywhere in the new UI — both the roster button and the lobby
  Friends rows render only name + color swatch, per the GID-094 opaque-token rule.
- Validation: `godot --headless --editor --quit` parse/compile-error grep is empty; full
  suite `godot --headless --path . -s tests/runner.gd` reports **1707 passed, 0 failed, 1
  pending** (pending is pre-existing and unrelated to this task).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added a new "#### Friends list (GID-102 / TID-375)"
  sub-subsection immediately after "Reconnection & recent servers (TID-347)", documenting the
  `MpProfile` friends storage/API, the roster add-friend affordance + `touch_friend_last_seen`
  hook, the in-session-only online-status semantics, and the lobby Friends section (including
  the documented decision to skip an invite mechanism / join-shortcut). Added a row for
  `tests/unit/test_mp_profile_friends.gd` to the Tests table.
