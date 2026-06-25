# TID-347: Reconnection + recent-servers list + join-by-address + public-IP guidance

**Goal:** GID-095
**Type:** agent
**Status:** done
**Depends On:** TID-345

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make rejoining a server you were in before a first-class flow, and make
joining-across-the-internet workable on the existing ENet transport (no relay):
remember recent servers, support join-by-address, and surface public-IP /
port-forward guidance + actionable connection diagnostics.

## Research Notes

_To be expanded when TID-345 lands._

- **Recent-servers store:** a small local list (in the `mp_profile` store from
  GID-094, or a sibling file) of `{address, port, label, last_session_id,
  last_joined}`. Surface in `MultiplayerLobbyScene` as a "Rejoin" list above the
  "Find Games" discovery list. Selecting one calls `NetworkManager.join(addr, port)`.
- **Join-by-address over the internet:** the existing `Join by IP` already accepts
  any address — for internet play the user types the **host's public IP** and the
  host forwards the ENet UDP port (`DEFAULT_PORT = 24565`) + discovery is LAN-only
  so it won't help across the internet (document that). Show the host its public IP
  is *not* auto-detectable on LAN (`get_lan_ip` returns the private one) — present
  port-forward guidance text: forward UDP 24565 to the host, share public IP,
  joiner uses Join by IP.
- **Connection diagnostics:** the lobby already has a 12 s watchdog
  (`_arm_join_timeout`). Extend messaging to distinguish: bad address, host not
  listening, port not forwarded, and add a retry button. Consider a longer/clearer
  timeout for WAN.
- **Reconnect UX:** on `session_ended` / `server_disconnected` mid-session, offer
  "Reconnect" that re-joins the same address and (via GID-094 token + TID-346)
  resumes the same character. Don't auto-spam; one tap, with backoff per the git
  push retry ethos.
- CLAUDE.md: viewport-relative UI; mobile + desktop parity (tap targets).

## Plan

1. **`MpProfile` recent-servers store** — persist a small `recent_servers` list
   (`{address, port, label, last_session_id, last_joined}`) in `mp_profile.json`.
   `add_recent_server(...)` (dedupe by address:port, most-recent-first, cap 6) +
   `get_recent_servers()`. Re-host reuse already covered by `get_host_session_id`.
2. **Lobby — Rejoin list** above "Find Games": one tap per recent entry →
   `NetworkManager.join(address, port)`. Recorded on every successful connect
   (host's `label` from discovery, or the typed IP).
3. **WAN guidance** — a collapsible "Play over the internet" block: host forwards
   UDP 24565 + shares its **public** IP (not the LAN IP `get_lan_ip` returns);
   joiner uses Join by IP; Find Games is LAN-only.
4. **Connection diagnostics** — track the pending attempt; on the 12 s watchdog or a
   hard failure show a **Retry** button that re-runs the same join.
5. **Reconnect UX** — on an unexpected client-side `session_ended` mid-session, route
   back to the menu with a toast pointing at Co-op → Rejoin (the recent list makes it
   one tap; the host's stable session id resumes the same world + character).
6. Mobile/desktop parity (all tap targets, viewport-relative). Import + runner gate.

## Changes Made

- **`autoloads/MpProfile.gd`** — recent-servers store persisted in `mp_profile.json`
  (`recent_servers` field). `add_recent_server(address, port, label, session_id="")`
  (dedupe by address:port, most-recent-first, cap 6) and `get_recent_servers()`.
- **`scenes/ui/MultiplayerLobbyScene.gd`:**
  - **Rejoin list** above "Find Games" — one tap per remembered server →
    `NetworkManager.join(address, port)` (the host's stable session id resumes the
    same world + character). Populated from `MpProfile.get_recent_servers()`.
  - Recorded on every successful connect (`_on_connection_succeeded` →
    `MpProfile.add_recent_server`), tracking the in-flight attempt via
    `_pending_addr/_port/_label`. All three join paths (IP, discovered, rejoin) now
    funnel through one `_start_join(ip, port, label)`.
  - **Retry** button (hidden until a timeout/failure) re-runs the same attempt.
  - **"Play over the internet"** collapsible guidance: forward UDP 24565, share the
    **public** IP (not the LAN IP), Find Games is LAN-only. Watchdog message extended
    with the WAN hint.
- **Reconnect UX:** delivered via the persistent one-tap Rejoin list rather than
  auto-navigating on `session_ended` — `NetworkManager` conflates the host's own
  `leave()` with a client losing the host into one signal, so force-routing there
  would regress existing host-exit flows. (Also: WorldScene already closes/flushes
  `SessionStore` on session end, from TID-346.)
- Mobile/desktop parity: every new control is a `Button` tap target, viewport-relative,
  preserved across the resize rebuild.
- Validation: headless import clean; `tests/runner.gd` 1572 passed / 0 failed.

## Documentation Updates

Deferred to TID-348 (the goal's docs task).
