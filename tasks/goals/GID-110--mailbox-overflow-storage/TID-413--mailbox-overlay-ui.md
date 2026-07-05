# TID-413: Mailbox Overlay UI (Claim/Sell/Scrap)

**Goal:** GID-110
**Type:** agent
**Status:** done
**Depends On:** TID-412

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-412 wires a placeholder `MailboxScene.tscn`/overlay reachable by interacting with the world-placed Mailbox entity. This task replaces the placeholder with a real UI listing `SaveManager.get_mailbox_instances()` (from TID-411) and gives the player Claim / Claim All / Sell / Scrap actions, plus a toast whenever a reward overflows into the mailbox during play.

## Research Notes

**Reuse this session's cube-tile grid pattern** — `scenes/ui/InventoryScene.gd` was reworked (2026-07-04, pre-dates this goal) to render the backpack as a Diablo-3-style grid of cube tiles instead of stacked rows. Read `scenes/ui/InventoryScene.gd`:
- `_make_card_tile(inst: Dictionary, in_deck: bool) -> Control` — the tile builder (rarity-colored border via `StyleBoxFlat`, veterancy chevrons, hover/long-press wiring).
- `_show_instance_detail(inst: Dictionary, anchor: Control)` / `_hide_instance_detail()` — the popup pattern (non-modal `PopupPanel`, positioned via `anchor.get_screen_transform().origin`) showing rolled stats + action buttons (Sell/Scrap/Combine/Rename in the backpack's case).
- `_refresh_cards()` — shows how the grid is rebuilt into a `GridContainer` with `columns` computed from the scroll container's width.

Do not import `InventoryScene.gd` from the new `MailboxScene.gd` — duplicate the relevant tile/popup code adapted for mailbox actions (Claim / Sell / Scrap instead of Add-to-deck / Sell / Scrap / Combine / Rename). If the duplication becomes substantial (it likely will, since the tile visuals are identical), consider extracting a shared helper (e.g. `game_logic/CardTileBuilder.gd` or similar under `scenes/ui/`) that both `InventoryScene` and `MailboxScene` call into — use judgment during Plan; don't force an extraction if the two call sites diverge enough that it'd need a large parameter list.

**Scene structure** — every overlay in this codebase extends `res://scenes/ui/BaseOverlay.gd` (see any of `InventoryScene.gd`, `CharacterScene.gd`, `BountyBoardScene` for the `_build_backdrop`/`_build_centered_panel`/`_build_margin_vbox` helpers already available via that base class — do not hand-roll backdrop/panel sizing). Follow `CLAUDE.md`'s "UI Sizing: Relative to Viewport" rule (`_ref`/`_vw`/`_vh` fractions, not fixed pixels) exactly as the rest of the UI codebase does.

**Backend API to call** (defined in TID-411, `autoloads/SaveManager.gd`):
```gdscript
SaveManager.get_mailbox_instances() -> Array[Dictionary]
SaveManager.claim_mailbox_card(uid: String) -> bool
SaveManager.claim_all_mailbox_cards() -> int
SaveManager.sell_mailbox_card(uid: String) -> void   # or equivalent name landed on in TID-411 — check its final signature, this Research Notes section was written before TID-411 executed
SaveManager.scrap_mailbox_card(uid: String) -> void
```
Claim should be disabled/no-op with a "Bag is full" message (reuse `GameBus.hud_message_requested`, same pattern as the existing "Bag full!" toast in `autoloads/SceneManager.gd` — search for `bag_full.connect`) when `SaveManager.is_bag_full()` is true.

**Overflow toast** — connect to the `GameBus.card_routed_to_mailbox(template_id: String)` signal added in TID-411 (search `autoloads/GameBus.gd`), likely wired in `autoloads/SceneManager.gd` alongside the existing `GameBus.bag_full.connect(...)` handler (`autoloads/SceneManager.gd:131-132`) rather than in `MailboxScene` itself, since the toast needs to fire during normal play regardless of whether the Mailbox overlay is currently open. Message something like `"%s couldn't fit in your bag — sent to the mailbox." % CardRegistry.get_template(template_id).get("name", template_id)`.

**Empty state** — if `get_mailbox_instances()` is empty, show a simple centered label (mirror `InventoryScene.gd`'s "No spare cards" empty-grid label added this session) rather than an empty grid.

**Placeholder file to replace** — `scenes/ui/MailboxScene.tscn` (and its script) was stubbed out in TID-412 purely to make the signal chain (`GameBus.mailbox_requested` → `SceneManager._on_mailbox_requested` → `_open_overlay`) testable; this task overwrites its contents with the real implementation described above without needing to touch `SceneManager.gd`'s wiring again (same `State.MAILBOX` / same preload path).

## Plan

1. Replace the TID-412 placeholder `scenes/ui/MailboxScene.gd` with the real overlay: header (title + Close), count label, Claim All button, scrollable cube-tile grid over `SaveManager.get_mailbox_instances()`.
2. Duplicate (not import) the tile/detail-popup pattern from `InventoryScene.gd`, adapted to Claim/Sell/Scrap actions instead of Add-to-deck/Combine/Rename.
3. Claim is a no-op with a "Bag is full" toast when `is_bag_full()`.
4. Wire the overflow toast: `GameBus.card_routed_to_mailbox` connected in `autoloads/SceneManager.gd` next to the existing `bag_full` handler (fires regardless of whether the overlay is open).
5. Empty-state label when the mailbox has no cards.

## Changes Made

- `scenes/ui/MailboxScene.gd`: full rewrite (was the TID-412 placeholder). Cube-tile grid (`_make_card_tile`) + non-modal detail popup (`_show_instance_detail`) with Claim / Sell / Scrap actions, `Claim All` button, empty-state label, Close button. Same `.tscn`/`State.MAILBOX` wiring from TID-412 untouched.
- `autoloads/SceneManager.gd`: added file-scope `const CardRegistry` preload (needed for the toast's card display name — previously only locally aliased as `_CardRegistry` inside one function); connected `GameBus.card_routed_to_mailbox` next to the existing `GameBus.bag_full` handler, emitting `"<name> couldn't fit in your bag — sent to the mailbox."` via `hud_message_requested`.

**Verification note:** same sandbox limitation as TID-411/412 — the Godot headless binary could not be installed (403 on the GitHub release download used to fetch it), so neither `godot --headless --editor --quit` nor `tests/runner.gd` could be run in this session. All three GID-110 tasks were verified by manual code review against this codebase's existing InventoryScene/BaseOverlay/Waystone/BountyBoard patterns, which they mirror closely. **A human or CI run should execute the headless import and full test suite before merging** — this is the one acceptance criterion ("no new parse/compile errors") this session could not check directly.

## Documentation Updates

Added a "Mailbox (GID-110)" section to `docs/agent/inventory-and-deck.md` covering the overflow queue, routing API, world entity placement, and overlay UI (see that file's diff in this commit).
