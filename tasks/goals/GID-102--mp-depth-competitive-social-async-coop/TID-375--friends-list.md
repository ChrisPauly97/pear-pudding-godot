# TID-375: Token-keyed friends list + online status

**Goal:** GID-102
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
