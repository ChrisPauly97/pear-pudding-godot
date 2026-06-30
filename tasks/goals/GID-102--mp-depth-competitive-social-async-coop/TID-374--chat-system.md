# TID-374: Chat system (quick-chat presets + free text)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op has *presence* and *expression* (names, emotes, pings — GID-101) but no **conversation
channel**. This task adds a party chat: a row of quick-chat presets (works one-tap on mobile)
plus an optional free-text input on desktop, with a scrolling HUD log.

## Research Notes

- **Pure wire format — new `game_logic/net/ChatSync.gd`** (scene-free, unit-tested, mirrors
  `SocialSync.gd` exactly). Payload `[text, kind, map]` where `kind` ∈ {`quick`, `text`} and
  `map` enables the same same-map filter the emote/ping layer uses. Provide presets for quick
  chat (e.g. "On my way", "Need help", "Nice!", "Wait", "Let's battle", "Trade?"). **Sanitize
  free text** (cap length ~120 chars, strip control chars) in the pure helper so the authority
  and clients agree.
- **RPC — `scenes/world/NetSync.gd`.** Add `recv_chat(payload: Array)` (unreliable_ordered is
  fine for chat, but **reliable** is safer so messages aren't dropped — chat is low-rate; use
  reliable). Follow the `recv_emote` / `recv_ping` precedent (`multiplayer-coop.md` →
  "Emotes & map pings"). Server-relay fans client→client (same as avatars).
- **Same-map filtering.** Reuse `_remote_player_maps[peer_id]` and the local `map_name`
  (already used for emotes) so chat from an off-map peer is still shown in the log but tagged,
  or filtered — match the emote behaviour for consistency. Author messages carry the sender's
  name + color (resolve from `_remote_identities`).
- **HUD panel.** A scrolling `VBoxContainer` (viewport-relative, CLAUDE.md sizing) in the
  world HUD: timestamped/colored lines, auto-fade or a toggle to show/hide. A quick-chat
  button row (reuse the emote-wheel GridContainer approach). Free-text `LineEdit` shown on
  desktop / behind a button on mobile (parity rule). Bound an action key for chat focus on
  desktop with a visible tap target for mobile.
- **Battle chat (optional).** Consider surfacing the same channel in BattleScene during a duel
  (the relay path differs — `BattleNetSync` vs `NetSync`); keep to the world HUD for the first
  cut unless cheap.
- **Tests:** `tests/unit/test_chat_sync.gd` — round-trip for both kinds, length cap, control-
  char stripping, map field, garbage/empty tolerance (mirror `test_social_sync.gd`).
- **Docs:** update `docs/agent/multiplayer-coop.md` (Social features subsection + Tests
  table); add the `ChatSync` row.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
