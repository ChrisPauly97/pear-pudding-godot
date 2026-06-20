# TID-299: Unified key bindings, in-hub tab cycling, back semantics, docs + tests

**Goal:** GID-081
**Type:** agent
**Status:** pending
**Depends On:** TID-296, TID-297, TID-298

## Lock

**Session:** none
**Acquired:** none
**Expires:** —

## Context

With the Menu Hub (TID-296/297) and decluttered HUD (TID-298) in place, this task makes navigation feel consistent: each player screen gets a key that deep-links into the hub, the hub supports tab cycling, Escape/back behaves predictably, and every key has a mobile tap equivalent. It closes the goal with a docs update and a headless test pass.

## Research Notes

**Input actions** live in `project.godot` `[input]`. Existing relevant actions (verify exact names): `pause`, `inventory` (I), `map_view` (M), `interact` (E). Check for existing `character` / `skills` / `journal` actions; add any missing. Follow the CLAUDE.md Mobile/Desktop Parity table — every key binding needs a visible tap target (provided by the hub tab bar + TID-298 HUD entry).

**Where input is handled:**
- `WorldScene.gd` handles overworld `_unhandled_input` / `_input` for `inventory`, `pause`, `map_view`, `interact`. Add `character`/`skills`/`journal` here, each calling `SceneManager.open_menu_hub(<tab>)` (or emitting the matching `GameBus.*_requested` signal, which TID-296 routes to the hub).
- The Menu Hub (`MenuHubScene.gd`, TID-296) handles its own `_input`: `ui_cancel` closes (inherited from BaseOverlay). Add tab-cycle handling here.

**Key binding plan:**
- I → hub on Deck/Bag, C → Character, K → Skills, J → Journal (confirm no conflicts with existing bindings; M stays map view).
- In-hub tab cycling: e.g. `Q`/`E` or `[`/`]` or Tab/Shift-Tab cycle prev/next tab. Pick one and document it. Provide the same via the tab bar buttons (already tap-accessible).
- Escape / `ui_cancel` / back: closes the entire hub to the world (single back action, not per-tab). On Android the hardware back maps to `ui_cancel` — verify it closes the hub.
- Opening the hub while it's already open on a different tab should switch tabs, not stack a second overlay (SceneManager guards on `MENU_HUB` state — add a path so a request while in `MENU_HUB` calls `hub.show_tab(tab)` instead of being ignored).

**Mobile parity checklist (CLAUDE.md):** every new key has a tap equivalent — hub tab bar buttons cover tab switching; the TID-298 Menu/Bag HUD button covers opening; the hub Close/back button covers closing. No keyboard-only path.

**Docs:** update `docs/agent/ui-and-scene-management.md`:
- New "Menu Hub" section: the shell, the page contract, `SceneManager.open_menu_hub(tab)`, the single hub state replacing INVENTORY/CHARACTER/SKILL_TREE/JOURNAL.
- Update the HUD section to describe the decluttered layout (single system/pause control, single Menu/Bag entry, action cluster).
- Document the key bindings and their mobile tap equivalents.
- Update the "Migrated Overlays" / state-machine notes that reference the four separate overlay states.

**Tests:** run `godot --headless --path . -s tests/runner.gd` (install Godot 4 headless per CLAUDE.md if absent). Exit 0 = pass. Note: BID-018/BID-019 record some pre-existing suite failures — distinguish those from any regression introduced here.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
