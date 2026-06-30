# TID-374: Chat system (quick-chat presets + free text)

**Goal:** GID-102
**Type:** agent
**Status:** done
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

1. **`game_logic/net/ChatSync.gd`** (new, `extends RefCounted`, mirrors `SocialSync.gd`):
   - `QUICK_PRESETS: Array[String]` fixed list: "On my way", "Need help", "Nice!", "Wait",
     "Let's battle", "Trade?" (6 presets, same count/style as the 6 emotes).
   - `KIND_QUICK = "quick"`, `KIND_TEXT = "text"`.
   - `MAX_TEXT_LEN = 120`.
   - `static func _sanitize(raw: String) -> String` — strips ASCII control chars (0x00-0x1F,
     0x7F) via character-code filtering, then truncates to `MAX_TEXT_LEN`.
   - `static func encode_quick(preset: String, map_name: String = "") -> Array` — validates
     preset is in `QUICK_PRESETS` (falls back to first preset text if not, sanitized), returns
     `[text, KIND_QUICK, map_name]`.
   - `static func encode_text(raw_text: String, map_name: String = "") -> Array` — sanitizes
     `raw_text`, returns `[text, KIND_TEXT, map_name]`.
   - `static func decode(payload: Variant) -> Dictionary` — garbage-tolerant, fully defaulted,
     returns `{"text": "", "kind": KIND_TEXT, "map": ""}` shape, re-sanitizes the decoded text
     defensively (so a malicious/garbled payload can't bypass the cap).
2. **`scenes/world/NetSync.gd`** — add `recv_chat(payload: Array)` RPC:
   `@rpc("any_peer", "reliable", "call_remote")`, routes to
   `world_scene._on_chat_received(sender, payload)`. Reliable per task notes (chat must not
   drop).
3. **`scenes/world/WorldScene.gd`**:
   - `const _ChatSync = preload(...)`, state vars: `_chat_log_panel`, `_chat_log_vbox`,
     `_chat_lines: Array` (capped to 40), `_chat_input: LineEdit`, `_chat_quick_panel`,
     `_chat_toggle_btn`, `_chat_send_btn` (mobile free-text reveal toggle).
   - `_ensure_chat_ui()` called from `_setup_coop()` alongside `_ensure_social_buttons()`.
   - Quick-chat button row mirrors `_show_emote_wheel()`/`GridContainer` pattern but sends
     via `_send_chat_quick(preset)`.
   - `_send_chat_quick(preset)` / `_send_chat_text(raw)` → `_ChatSync.encode_*` →
     `_net_sync.rpc("recv_chat", payload)` → append to local log immediately (no echo needed
     back from network).
   - `_on_chat_received(sender, payload)` — decode, same-map filter matching emote behavior
     (off-map sender → message dropped/hidden, not shown tagged, for consistency with
     `_on_emote_received`'s early-return pattern), resolve name+color from
     `_remote_identities`, append to log.
   - `_append_chat_line(name, color, text)` — adds a `Label` (or `RichTextLabel` line) to
     `_chat_log_vbox`, evicts oldest beyond 40, auto-scrolls.
   - Keyboard: extend `_unhandled_input` with a dedicated key (`KEY_ENTER`/`KEY_KP_ENTER` when
     chat input not already focused) to focus `_chat_input`, following the existing `KEY_G`/
     `KEY_D` raw-keycode precedent (no new project.godot input action needed — keeps the
     change minimal and self-contained).
   - Mobile parity: a "Chat" HUD button toggles the quick-chat row and reveals the LineEdit +
     send button (so touch users reach both quick and free text without a keyboard).
   - Log visibility: keep the log panel always visible while in co-op (simplest, matches the
     always-visible party bounty panel) rather than auto-fade — documented as the chosen
     behavior.
4. **Tests** — `tests/unit/test_chat_sync.gd`: round-trip quick/text, length cap (>120 chars
   truncated to 120), control-char stripping, map field round-trip, garbage/empty payload
   tolerance, preset list sanity. ~15-18 cases mirroring `test_social_sync.gd`'s structure.
   `.gd.uid` sidecars for both new `.gd` files.
5. **Docs** — `docs/agent/multiplayer-coop.md`: new `#### Chat (GID-102 / TID-374)`
   sub-subsection under "Social features", plus a new row in the Tests table.
6. **Validate**: headless import clean, full test suite passes, no regressions.
7. Battle chat: explicitly out of scope for v1 (relay path differs — `BattleNetSync` vs
   `NetSync` — not cheap to bolt on safely in this slice); documented as a scope cut.

## Changes Made

- **`game_logic/net/ChatSync.gd`** (new) — pure encode/decode for chat packets
  `[text, kind, map]`. `KIND_QUICK`/`KIND_TEXT`, `QUICK_PRESETS` (6 fixed presets:
  "On my way", "Need help", "Nice!", "Wait", "Let's battle", "Trade?"), `MAX_TEXT_LEN
  = 120`, `LOG_MAX_LINES = 40`. `_sanitize()` strips ASCII control chars (0x00-0x1F,
  0x7F) and truncates to the cap; both `encode_text()` and `decode()` sanitize, so the
  cap can't be bypassed by a forged payload. `encode_quick()` falls back to the first
  preset for an unrecognized id. `decode()` is fully defaulted and garbage-tolerant
  (never throws on null/string/dict/short-array input), mirroring
  `SocialSync.decode_emote`/`decode_ping` exactly. `game_logic/net/ChatSync.gd.uid`
  sidecar added.
- **`scenes/world/NetSync.gd`** — added `recv_chat(payload: Array)` RPC,
  `@rpc("any_peer", "reliable", "call_remote")` (reliable, unlike the
  unreliable_ordered avatar/emote/ping RPCs — chat must not drop per task notes).
  Routes to `world_scene._on_chat_received(sender, payload)`, same shape as
  `recv_emote`/`recv_ping` so it benefits from the existing automatic host
  server-relay.
- **`scenes/world/WorldScene.gd`**:
  - New `const _ChatSync` preload + state vars (`_chat_log_panel`, `_chat_log_vbox`,
    `_chat_lines`, `_chat_quick_panel`, `_chat_input`, `_chat_send_btn`,
    `_chat_toggle_btn`).
  - `_ensure_chat_ui()` (called from `_setup_coop()` alongside
    `_ensure_social_buttons()`) builds: a viewport-relative scrolling chat log
    (`ScrollContainer` + `VBoxContainer`, always visible while in co-op, capped to
    `ChatSync.LOG_MAX_LINES` lines with oldest evicted first), a "Chat" HUD toggle
    button, an always-present free-text `LineEdit` + "Send" button.
  - `_show_chat_quick_panel()` / `_toggle_chat_quick_panel()` — reuses the
    emote-wheel's `GridContainer` radial-button pattern (`_show_emote_wheel`) for the
    6 quick-chat presets; opening it also focuses the free-text input (mobile users
    reach both quick and free text from one "Chat" tap).
  - `_send_chat_quick()` / `_send_chat_text()` / `_submit_chat_input()` — encode via
    `ChatSync`, broadcast `_net_sync.rpc("recv_chat", payload)`, append locally
    (no echo-back needed).
  - `_on_chat_received(sender, payload)` — decodes, applies the **same same-map
    filter as `_on_emote_received`**: a message whose `map` is non-empty and differs
    from local `map_name` is dropped (not shown-but-tagged), for HUD consistency with
    how emotes already behave. Resolves sender name/color from
    `_remote_identities[peer_id]`.
  - `_append_chat_line()` — adds a colored `[HH:MM] Name: text` `Label` row, evicts
    oldest beyond the cap.
  - `_unhandled_input` extended with an Enter/Numpad-Enter shortcut (same raw-keycode
    pattern as the existing `KEY_G`/`KEY_D` handlers) that focuses the chat input on
    desktop when not already focused; the "Chat" HUD button is the mobile-parity
    equivalent (CLAUDE.md mobile/desktop parity rule).
- **`tests/unit/test_chat_sync.gd`** (new, 26 cases) — round-trip for quick and text
  kinds (incl. all 6 presets and unknown-preset fallback), length-cap enforcement
  (under/at/over 120 chars, plus a forged-payload re-sanitization case proving
  `decode()` itself enforces the cap), control-character + newline/tab/DEL stripping,
  normal-punctuation preservation, `map` field round-trip, and garbage/null/empty/
  short-array/invalid-kind decode tolerance (never throws). `tests/unit/
  test_chat_sync.gd.uid` sidecar added.
- **Validation**: `godot --headless --editor --quit` headless import produced no
  Parse/Compile/Failed-to-load-script errors. `godot --headless --path . -s
  tests/runner.gd` → **1716 passed, 0 failed, 1 pending** (pre-existing pending case,
  unrelated to this task), including all 26 new `test_chat_sync` cases.
- **Scope cut (documented, not implemented)**: battle chat (surfacing the same
  channel during a PvP duel via `BattleNetSync`) was left out of this slice — the
  relay path differs from world `NetSync` and bridging it safely wasn't judged
  "genuinely cheap" once the world-HUD version worked. The pure `ChatSync` helper is
  reusable as-is if a future task wires up the `BattleNetSync` relay side.

## Documentation Updates

- **`docs/agent/multiplayer-coop.md`**:
  - Added a new `#### Chat (GID-102 / TID-374)` sub-subsection under "Social features
    (GID-101 / TID-365 & TID-366)", positioned after "Card trading & gifting" and
    before "Shared party bounties", matching the existing `####` heading level used
    by its sibling sections. Documents the wire format, sanitization-in-the-pure-
    helper design, the reliable RPC choice and why, the same-map filter (drop vs
    tag, matching emotes), the HUD panel design (always-visible log, retention cap,
    quick-chat row reuse, free-text input + desktop/mobile parity), and the
    documented battle-chat scope cut.
  - Added a `tests/unit/test_chat_sync.gd` row to the Tests table, positioned
    immediately after the `test_social_sync.gd` row.
  - Edits were surgical (new bounded sections only) since TID-373 and TID-375 are
    editing the same file in parallel worktrees and will need to be merged.
