# BID-009: No shared Theme; overlay boilerplate copy-pasted across 8 scenes

**Category:** code-smell
**Discovered During:** GID-064 audit

## Description

Every UI overlay builds its entire tree node-by-node in `_ready` with per-node
`add_theme_font_size_override` / `add_theme_constant_override` on every label and
button — hundreds of allocations + theme overrides on the UI thread each time an
overlay opens (worst: InventoryScene with a large collection), blocking the frame on
Android. No shared `Theme` resource exists anywhere in scenes/ui.

The backdrop + centered-panel + margin boilerplate is copy-pasted across 8 scenes, and
`ShopScene._weapon_effect_summary` (ShopScene.gd:283-293) duplicates
`CharacterScene._effect_summary` (CharacterScene.gd:256-262). Styling fixes must be
applied 8×.

## Evidence

- InventoryScene.gd:38-61, ShopScene.gd:27-51, CharacterScene.gd:33-58,
  JournalScene.gd:22-47, AchievementsScene.gd:16-40, SkillTreeScene.gd:180-204,
  TutorialPopup.gd:18-42, SettingsScene.gd:12-53 — identical overlay scaffolding.

## Suggested Resolution

One shared Theme resource (font sizes, separations, button min sizes, styleboxes) set
on the root Control of each overlay; a `UiUtil.gd` (or base overlay scene) providing the
backdrop/panel/margin scaffold and the effect-summary helper; list rows as a small
reusable PackedScene. Sizeable refactor — its own goal/task, not a drive-by.
