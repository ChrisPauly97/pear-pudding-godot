# TID-347: Reconnection + recent-servers list + join-by-address + public-IP guidance

**Goal:** GID-095
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
