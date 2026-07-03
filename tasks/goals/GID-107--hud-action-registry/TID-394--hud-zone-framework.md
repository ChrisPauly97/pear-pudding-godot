# TID-394: HUD zone framework + action registry in WorldHUD

**Goal:** GID-107
**Type:** agent
**Status:** done
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

Zones are real `Container` nodes childed directly to `_hud`, each anchored at a fixed viewport-relative position and stacking their own children (so overlap within a zone is structurally impossible — Godot's `BoxContainer` skips hidden children when sizing/sorting, which also fixes the "hidden button still reserves a slot" issue for free):

- `ZONE_SYSTEM` ("system") — `VBoxContainer` at `(vh*0.01, vh*0.01)`, top-left. Houses Pause today.
- `ZONE_NAV` ("nav") — `VBoxContainer` at `(vw - btn_w*1.3 - vh*0.01, minimap_bottom)`, top-right under the minimap. Houses Menu/Bag, Mount today; TID-395 adds Party here.
- `ZONE_ABILITY` ("ability") — `VBoxContainer` at `(vh*0.01, vh*0.17)`, left column. Houses Ghost Phase / Skeleton Dig cantrips today.
- `ZONE_CONTEXT` ("context") — `VBoxContainer` at `(vw*0.5 - vh*0.17, vh*0.80)`, bottom-center. Empty until TID-396.
- `ZONE_SOCIAL` ("social") — `HBoxContainer` at `(vw - vh*0.32, vh*0.87)`, bottom-right. Empty until TID-397.

API added to `WorldHUD.gd`:
- `register_action(id, label, zone, callback, visible_when := Callable(), min_size := Vector2.ZERO) -> Button` — creates the button on first call (idempotent on repeat calls, matching the existing `_ensure_*` re-entrancy pattern used everywhere else in this codebase), parents it into the zone container, sizes it (explicit `min_size` or a zone-appropriate default), connects `pressed`, stores `visible_when`, and applies it once immediately.
- `unregister_action(id)` — frees the button and drops the registry entry.
- `set_action_visible(id, v)` — direct setter for the common case where a caller already computed the boolean itself (matches how `_update_challenge_proximity()` etc. already work — no need to force every per-frame caller through a re-evaluated Callable).
- `refresh_visibility(id := "")` — re-evaluates one action's (or, if `id` omitted, every action's) stored `visible_when` Callable. Used for the ability cluster (`GameBus.inventory_changed`-driven, not per-frame).
- `get_action_button(id) -> Button` — accessor for callers that need to mutate text/tooltip dynamically (Mount/Dismount, toggle labels).

Migrate WorldHUD's own 5 buttons (Pause, Menu/Bag, Mount, Ghost Phase, Skeleton Dig) onto `register_action`, replacing their manual `Button.new()` + `add_child` + `position` code. `refresh_action_cluster()` switches to `refresh_visibility()`. `update_mount_btn()` switches to `get_action_button("mount")`.

**Bug found while planning:** `is_touch_on_hud_button()` only scans `_hud.get_children()` one level deep. Once buttons live inside zone `Container`s instead of directly under `_hud`, that scan misses every registered button, silently breaking the "don't let tap-to-move fire through a HUD button" guard on Android. Fix: make the scan recurse into `Container` children (harmless no-op today, required once zones exist).

Not touching WorldScene's other buttons — TID-395/396/397 handle those, using the zones/API this task exposes.

## Changes Made

- `scenes/world/WorldHUD.gd`: added the zone/registry framework — `ZONE_SYSTEM`/`ZONE_NAV`/`ZONE_ABILITY`/`ZONE_CONTEXT`/`ZONE_SOCIAL` constants, `_zones`/`_actions` dictionaries, `_init_zones()`/`_add_zone()`, and the public API `register_action()`, `unregister_action()`, `refresh_visibility()`, `set_action_visible()`, `get_action_button()`, `get_zone_container()`.
- Migrated the 5 WorldHUD-owned buttons (Pause → `ZONE_SYSTEM`; Menu/Bag, Mount → `ZONE_NAV`; Ghost Phase, Skeleton Dig cantrips → `ZONE_ABILITY`) onto `register_action`. Visual position is unchanged (zone anchors match the buttons' old coordinates exactly; per-zone `VBoxContainer` separation matches the old manual offsets), but overlap within a zone is now structurally impossible.
- Cantrip visibility now goes through a `visible_when` Callable re-evaluated by `refresh_action_cluster()` (still triggered by `GameBus.inventory_changed`, unchanged trigger) instead of directly poking `.visible`.
- **Bug fix (found during Plan):** `is_touch_on_hud_button()` only scanned direct `_hud` children; buttons now live one level deeper inside zone containers. Replaced with a recursive `_hits_button()` walk so the Android tap-to-move guard still sees every registered button.
- No behavior change to any WorldScene-owned button in this task — TID-395/396/397 migrate those onto the zones this task exposes.

**Not run:** `godot --headless --editor --quit` compile check — this environment's network policy blocks the Godot release download (403 from the egress proxy for github.com release assets). Reviewed the diff manually against GDScript syntax/typing rules in CLAUDE.md (explicit `Dictionary`/`Container` type annotations to avoid Variant-inference errors, `Dictionary.get(key, default)` two-arg form, preload-not-classname for `WorldHUD`). CI's headless import step will be the first actual compile check for this change.

## Documentation Updates

New API surface for TID-398 to fold into `docs/agent/ui-and-scene-management.md`:
- Zones: `system` (top-left), `nav` (top-right under minimap), `ability` (left column), `context` (bottom-center, empty until TID-396), `social` (bottom-right, empty until TID-397).
- `WorldHUD.register_action(id, label, zone, callback, visible_when := Callable(), min_size := Vector2.ZERO) -> Button` / `unregister_action(id)` / `refresh_visibility(id := "")` / `set_action_visible(id, v)` / `get_action_button(id)` / `get_zone_container(zone)`.
- Idempotent like the existing `_ensure_*_button()` pattern: calling `register_action` again with the same `id` updates the existing button in place rather than duplicating it.
