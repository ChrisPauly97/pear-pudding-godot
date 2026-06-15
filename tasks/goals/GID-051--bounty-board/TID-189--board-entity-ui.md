# TID-189: Bounty Board Entity in Towns + Accept/Track/Claim UI

**Goal:** GID-051
**Type:** agent
**Status:** done
**Depends On:** TID-188

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The in-world bounty board entity that players approach in towns, and the overlay UI that lists today's contracts and manages accept/claim flow. The entity follows the same NPC pattern as MerchantNPC (cite **docs/agent/enemies-and-npcs.md** lines 97–105 for the MerchantNPC model: static `CharacterBody3D`, npc_type dict field, WorldScene._handle_interact() routing, SceneManager overlay instantiation).

## Research Notes

- **Bounty board entity:**
  - New scene: `scenes/world/entities/BountyBoardNPC.tscn` (copy **scenes/world/entities/TownspersonNPC.tscn** as template)
  - New script: `scenes/world/entities/BountyBoardNPC.gd` (extends Node3D, minimal — just holds npc_type in data dict and sprite)
  - NPC type string: `"bounty_board"` (add to WorldScene entity type check, cite line 1210–1216 of **scenes/world/WorldScene.gd** for the pattern)
  - Sprite: reuse or commission a small sign/board texture; fallback to a rotated placard if TextureGen doesn't cover it
  - Placed in named maps via `MERCHANT` syntax or equivalent (or manual placement); place one in each of the three town maps:
    - **madrian** (cite **assets/maps/madrian.tres** — check map npc list in the .tres; if not inspectable, document as "place at town center")
    - **maykalene** (cite **assets/maps/maykalene.tres**)
    - **blancogov** (cite **assets/maps/blancogov.tres**)
  - Interact ranges use `IsoConst.INTERACT_RANGE` (1.5 units, cite **autoloads/IsoConst.gd** line 114)
- **BountyBoardScene UI** (new overlay):
  - New scene: `scenes/ui/BountyBoardScene.tscn` + `scenes/ui/BountyBoardScene.gd`
  - Extends Control, emits `closed` signal (standard overlay pattern, cite **scenes/ui/ShopScene.gd** line 1 and **autoloads/SceneManager.gd** line 342–348 for overlay lifecycle)
  - Layout: vertical VBoxContainer with:
    - Header label "Daily Bounties" (viewport-relative font 2.5% vh, cite **CLAUDE.md** UI Sizing section)
    - Three rows, each showing one bounty:
      - Type icon/emoji + type label (e.g., "Defeat 3 Ghoul Packs" or "Open 2 Chests")
      - Progress bar or text (only for accepted bounties; hidden if not yet accepted)
      - Reward label (e.g., "75 coins")
      - Button state: "Accept" (if not accepted), "In Progress" (disabled, if accepted and not complete), "Claim" (if complete and not claimed)
    - Row structure: HBoxContainer with label/icon on left, progress in center, button on right
    - Backdrop: semi-transparent rect (mobile parity: tap the backdrop to close)
    - Buttons sized 12% vh × 5% vh (cite **CLAUDE.md** UI Sizing)
- **Button state machine per bounty row:**
  - `bounty_not_accepted` → "Accept" button (enabled, `button.pressed` → accept flow)
  - `bounty_accepted_incomplete` → "In Progress" label (no button, disabled greyed-out state)
  - `bounty_completed_unclaimed` → "Claim" button (enabled, `button.pressed` → claim flow)
  - `bounty_claimed` → hidden row or greyed text (design choice: hide claimed bounties v1)
- **Accept flow:**
  - Validate: player has < 3 active bounties (cite TID-188 max 3 rule)
  - Call `SaveManager.accept_bounty(bounty_dict)` which moves bounty from `offered_bounties` to `active_bounties` with `progress: 0`
  - Mark SaveManager dirty
  - Update UI to show "In Progress"
  - Emit GameBus signal or call WorldScene to show toast (e.g., "Bounty accepted: Defeat 3 ghoul packs")
- **Claim flow:**
  - Call `SaveManager.claim_bounty(bounty_id)` which sets `claimed: true` and **does not** call `add_coins()` yet
  - Actually pay coins in TID-190 (to keep coin logic in one place); bounty claim just marks claimed state
  - Update UI: hide claimed row or refresh
  - Toast: "Bounty complete! +75 coins"
- **Android/mobile preload pattern:**
  - Cite **CLAUDE.md** "Android: Always preload() .tres Files" section
  - BountyBoardScene instantiation follows SceneManager pattern; no dynamic load() calls
- **Tests (headless):**
  - Row-state logic: given a bounty dict in each state (not accepted, accepted-incomplete, complete-unclaimed, claimed), verify button text and enabled/disabled states
  - Button callbacks: verify accept/claim mutate SaveManager state correctly
  - Max 3 active: 4th accept button is disabled if 3 are already active

## Plan

1. Create `BountyBoardNPC.gd` / `.tscn` — brown-board Node3D with "Bounty Board" label; follows MerchantNPC pattern.
2. Update `ChunkRenderer.gd` — preload BountyBoardNPC, add `npc_type == "bounty_board"` to scene selection.
3. Add `bounty_board_requested` signal to `GameBus.gd`.
4. Update `WorldScene._handle_interact()` — emit `bounty_board_requested` for `npc_type == "bounty_board"`.
5. Update `SceneManager.gd` — add `BOUNTY_BOARD` state, overlay var, preload, connect signal, open/close handlers.
6. Add `accept_bounty(id)` and `claim_bounty(id)` to `SaveManager.gd`.
7. Create `BountyBoardScene.gd` + `.tscn` — overlay with three rows, button-state machine (Accept / In Progress / Claim), tap-backdrop-to-close, viewport-relative sizing.
8. Add `MapNpc` sub-resources to `madrian.tres` (tile 46,30), `maykalene.tres` (tile 60,52), `blancogov.tres` (tile 42,50).
9. Create `tests/unit/test_bounty_board.gd` — SaveManager accept/claim/max-3 logic tests; register in `runner.gd`.

## Changes Made

- **Created `scenes/world/entities/BountyBoardNPC.gd` / `.tscn`**: brown post-and-board Node3D with "Bounty Board" label; follows MerchantNPC pattern exactly (static shared meshes/materials, `init_from_data()`, `get_dialogue()`).
- **Updated `scenes/world/ChunkRenderer.gd`**: preloads `BountyBoardNPC.tscn`, adds `npc_type == "bounty_board"` branch to NPC scene-selection.
- **Updated `autoloads/GameBus.gd`**: added `bounty_board_requested` signal.
- **Updated `scenes/world/WorldScene.gd`**: added `npc_type == "bounty_board"` case in `_handle_interact()` that emits `GameBus.bounty_board_requested`.
- **Updated `autoloads/SceneManager.gd`**: added `BOUNTY_BOARD` state to enum; `_bounty_board_scene_packed` preload; `_bounty_board_overlay` var; connected `bounty_board_requested`; added `_on_bounty_board_requested()` / `_on_bounty_board_closed()`.
- **Updated `autoloads/SaveManager.gd`**: added `accept_bounty(id) -> bool` (moves from offered→active, enforces max-3 cap) and `claim_bounty(id) -> int` (pays coins, marks claimed).
- **Created `scenes/ui/BountyBoardScene.gd` / `.tscn`**: full overlay with dark backdrop (tap-to-close), three bounty rows, button-state machine (Accept / In Progress / Claim / Claimed greyed), viewport-relative sizing, show_toast feedback.
- **Updated `assets/maps/madrian.tres`**: added `MapNpc_11` bounty board at tile (46, 30).
- **Updated `assets/maps/maykalene.tres`**: added `MapNpc_7` bounty board at tile (60, 52).
- **Updated `assets/maps/blancogov.tres`**: added `MapNpc_5` bounty board at tile (47, 56).
- **Updated `tests/unit/test_named_map_npcs.gd`**: updated madrian NPC count assertion from 10 → 11.
- **Created `tests/unit/test_bounty_board.gd`**: 18 tests covering accept flow, max-3 gate, claim flow, coin payout, already-claimed guard, incomplete guard, double-accept guard. All pass.
- **Updated `tests/runner.gd`**: registered `test_bounty_board.gd` suite.

## Documentation Updates

- Updated `docs/agent/bounty-board.md` with BountyBoardScene layout, accept/claim API, and map placement details.
