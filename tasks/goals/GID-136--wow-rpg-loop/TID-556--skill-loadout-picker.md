# TID-556: Skill Loadout Picker

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** TID-537

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A screen to choose which learned abilities occupy the real-time skill bar's 3
slots, writing `SaveManager.skill_bar`. Reachable from the trainer panel
(TID-537) and from somewhere always available (deck/inventory screen, pause
menu, or party panel), following the HUD button rules in CLAUDE.md.
Touch-friendly: tap a slot, tap an ability.

## Research Notes

- `game_logic/battle/SkillBar.gd` (TID-550/537) already owns the ability
  table and `SaveManager.learned_abilities`/`skill_bar` fields; the picker
  only needs to read/write them, plus a small pure helper to seed its editing
  state (`SkillBar.resolved_bar`/`known_ids`, added in this task).
- `scenes/ui/MenuHubScene.gd` (GID-081) is the existing "always available"
  tabbed shell (Deck/Bag, Character, Skills, Journal), opened from a HUD
  "Menu"/"Inventory" button (`WorldHUD.gd` → `SceneManager.open_menu_hub`).
  Adding a tab here satisfies "always available" without a new HUD button
  (CLAUDE.md: "Always-on buttons usually belong in `PartyPanel.gd`, not the
  HUD" — the Menu Hub tab bar is the equivalent for a full screen, not a
  single action button, so no HUD Action Registry entry was needed).
- Every hub page follows a `hub_mode: bool` contract
  (`docs/agent/ui-and-scene-management.md` "MenuHubScene"): skip backdrop/
  close button, build into a full-rect `MarginContainer`, don't consume
  `ui_cancel`. `SkillTreeScene.gd`/`CharacterScene.gd` are the templates.

## Plan

1. `SkillBar.gd`: add `known_ids(learned)` (always-known + learned) and
   `resolved_bar(bar, learned)` (always exactly `SLOTS` entries: kept where
   still known, padded with unused known ids, `DEFAULT_BAR` first).
2. New `scenes/ui/SkillBarScene.gd` (+ `.tscn`), extends `BaseOverlay`,
   `hub_mode` aware: 3 slot buttons (tap to select, highlighted gold) above a
   scrollable grid of every known ability (tap to slot it into the selected
   slot; already-slotted ability swaps instead of duplicating). Every change
   calls `SaveManager.set_skill_bar()` immediately.
3. `MenuHubScene.gd`: add a `"loadout"` tab ("Skill Bar"), `L` key binding,
   and shrink each tab button's width by `_TABS.size()` so a 5th tab doesn't
   overflow the row.
4. `NpcInteractions.show_trainer_panel()`: add a "Loadout" button next to
   Close that opens the hub straight to the new tab
   (`SceneManager.open_menu_hub("loadout")`).
5. Update `tests/menu_hub_smoke.gd`'s tab list to include `"loadout"`.

## Changes Made

- `game_logic/battle/SkillBar.gd`: `known_ids(learned)`,
  `resolved_bar(bar, learned)`.
- `scenes/ui/SkillBarScene.gd` + `SkillBarScene.tscn`: the picker screen
  (tap-slot / tap-ability, immediate `SaveManager.set_skill_bar()` writes,
  swap-on-duplicate).
- `scenes/ui/MenuHubScene.gd`: `"loadout"` tab (label "Skill Bar"), `KEY_L`
  binding, dynamic tab-button width (`_ref * (0.80 / _TABS.size())`) so the
  row keeps fitting as tabs are added.
- `scenes/world/modules/NpcInteractions.gd`: trainer panel's close row gained
  a "Loadout" button → `SceneManager.open_menu_hub("loadout")`.
- Tests: `tests/unit/test_skill_bar.gd` — `known_ids()` is always-known plus
  learned, `resolved_bar()` is always exactly `SLOTS` long, a fresh save
  resolves to the default bar, a learned choice is kept and padded with
  unused defaults, and an unlearned id is dropped entirely.
  `tests/menu_hub_smoke.gd`'s tab loop now covers `"loadout"` (page mounts,
  `hub_mode` set, parented under the content area, margin wrapper fills the
  page) — ran and passing (41 checks, 0 failed).

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: MenuHubScene's tab list, layout
  and key-binding table updated for the 5th tab; new "SkillBarScene —
  loadout picker" subsection covering the tap-slot/tap-ability flow,
  `resolved_bar`/`known_ids`, and both entry points.
- `docs/agent/combat-model.md`: "Learning abilities & the loadout" now points
  at the ui-and-scene-management doc for the picker's own details.
