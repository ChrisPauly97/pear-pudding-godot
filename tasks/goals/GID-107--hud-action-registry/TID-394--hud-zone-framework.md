# TID-394: HUD zone framework + action registry in WorldHUD

**Goal:** GID-107
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

This is the anti-clutter mechanism the rest of GID-107 depends on. Every HUD button added since GID-081 (co-op roster, stash, leaderboard, ghost duels, team duel, dungeon crawl, loot-mode toggle, challenge/ranked, trade, spectate, chat, emote, ping — all in `scenes/world/WorldScene.gd`) was placed with a hand-picked `position = Vector2(vh*..., vw*...)`, because there was no shared placement primitive to plug into. This produces silent overlaps (see GID-107 goal.md Context for the specific colliding pairs, e.g. Leaderboard on top of Pause, Stash on top of the bounty tracker, Team Duel and Dungeon Crawl sharing the same row). Without a registry, every future feature will keep adding one more manually-positioned button.

## Research Notes

- `scenes/world/WorldHUD.gd` already owns and positions 5 HUD buttons cleanly via `setup()`: Pause (`_create_nav_buttons`, line ~84), Menu/Bag (line ~96), Mount (line ~104), Ghost Phase cantrip and Skeleton Dig cantrip (`_create_cantrip_buttons`, line ~114). These use manual `vh`/`vw` math today but are the least-cluttered part of the HUD — good precedent to convert first.
- `scenes/world/WorldScene.gd` creates the other ~13+ buttons directly (not through WorldHUD) at various `_ensure_*_button()` functions: `_ensure_loot_mode_toggle_button` (~1019), `_ensure_dungeon_button` (~1719), `_ensure_challenge_button` (~1758, also creates `_ranked_toggle_btn`), `_ensure_team_duel_button` (~1845), `_ensure_social_buttons` (~4579, creates `_emote_btn`, `_ping_btn`, `_trade_window_mine`, `_spectate_btn`, `_leaderboard_btn`, `_stash_btn`), `_ensure_ghost_duel_button` (~4650), and the chat block (~4940-4980, `_chat_toggle_btn`, `_chat_input`, `_chat_send_btn`). These are the buttons TID-395/396/397 will migrate onto the new registry — this task only needs to build the registry and prove it on WorldHUD's own buttons.
- `scenes/ui/MenuHubScene.gd` is the closest existing precedent for a shared UI framework file (tab bar `_TABS`/`_TAB_LABELS`/`_tab_buttons` dict pattern) — not directly reusable (different problem: tabs vs. HUD placement) but shows the project's preferred style: a small typed registry backed by a `Dictionary`, iterated to build/refresh UI.
- `scenes/ui/BaseOverlay.gd` and `scenes/ui/UiUtil.gd` are the shared overlay/style helpers (GID-073) — follow the same "preload the const, don't rely on class_name" rule from CLAUDE.md's `class_name` section when this new framework file is referenced from WorldScene/WorldHUD.
- CLAUDE.md's "UI Sizing: Relative to Viewport, Never Fixed Pixels" rule still applies — zones must be viewport-relative, and must re-apply on `NOTIFICATION_RESIZED` (see existing pattern in `WorldHUD.setup()` which reads `get_viewport().get_visible_rect().size`).

## Plan

_Written during Plan phase._ Suggested shape (confirm/adjust during Plan):
- Add named zones to `WorldHUD.gd` as string constants or an enum, each backed by an actual `VBoxContainer`/`HBoxContainer` Control anchored at a fixed viewport-relative position (top-left system, top-right nav-under-minimap, left ability cluster, bottom-center contextual bar, bottom-right social strip, and a new party-entry slot near nav). Using real Container nodes for auto-stacking is the mechanism that makes overlap structurally impossible — do not keep manual per-button Y-offset math.
- Add `register_action(id: String, label: String, zone: String, callback: Callable, visible_when: Callable = Callable()) -> Button` — creates or returns the button, reparents it into the zone container, connects `pressed`, and remembers `visible_when` for later re-evaluation.
- Add `unregister_action(id: String) -> void` and `refresh_visibility() -> void` (iterates all registered actions, calls `visible_when` if set, updates `.visible`).
- Migrate WorldHUD's own 5 buttons (Pause, Menu/Bag, Mount, Ghost Phase, Skeleton Dig) onto the new API in this task, replacing their current manual positioning — this is both the proof of the API and the first real usage.
- Do not touch WorldScene's other buttons yet (TID-395/396/397 handle those) — but do expose whatever WorldHUD API those tasks will need (e.g. a way for WorldScene to call `_world_hud.register_action(...)`).

## Changes Made

_Filled after Build phase._

## Documentation Updates

_Leave the full `docs/agent/ui-and-scene-management.md` rewrite to TID-398 to avoid duplicate/conflicting edits across parallel-ish tasks in this goal. You may note the new API surface briefly in this section for TID-398's reference._
