# TID-477: MagicTypes Registry + Generalized Skill Tree UI

Goal: [GID-127](goal.md) · Type: agent · Status: done

## Problem

Four places assume exactly two magic types. Adding a third and fourth type is
impossible until they are table-driven.

## Plan

1. New `game_logic/MagicTypes.gd` — static tables + accessors, no state.
2. `SkillTreeScene` reads from it: branch lookup, tab labels, tab colors,
   choose-your-path modal, cross-magic tab, cross-currency.
3. Choose-your-path becomes a 2×2 grid so four options fit on a phone screen.

## Changes Made

- **`game_logic/MagicTypes.gd`** (new) — the single source of truth:
  - `TYPES` — ordered dictionary, one entry per magic type, carrying
    `display`, `branches`, `color`, `tagline`, and `cross_currency`.
  - `BRANCH_COLORS` — per-branch tint, used by the skill tree tabs and the
    procedural card rune generator.
  - `CURRENCY_BRANCHES` — the one signature branch per type whose cards accrue
    that type's cross-magic currency.
  - Accessors: `all_types()`, `branches_for()`, `type_for_branch()`,
    `display_name()`, `type_color()`, `branch_color()`, `tagline()`,
    `cross_currency()`, `currency_for_branch()`, `is_valid_type()`.
  - `type_for_branch()` derives its answer by scanning `TYPES`, so a branch can
    never be listed under one type and coloured as another.

- **`scenes/ui/SkillTreeScene.gd`**:
  - Dropped the local `MAGIC_BRANCHES` constant and `_opposing_magic()`.
  - `_branch_for_tab()`, `_tab_label()`, `_tab_color()` now read `MagicTypes`.
  - `_build_magic_choice()` builds its columns by iterating `MagicTypes.all_types()`
    into a 2-column `GridContainer` instead of two hand-written HBox children.
    Column width dropped from 28% to 24% vw and the header/description font
    sizes were trimmed so four cards fit without scrolling on a phone.
  - `_cross_magic_ids()` now walks every non-home type, not just the opposing one.
  - `_cross_currency()` reads `MagicTypes.cross_currency(magic_type)` — identical
    results for light/dark, defined results for verdant/rift.
  - `_make_skill_node()` no longer treats "not my type" as "the opposing type".

## Judgment Call

`MagicTypes.gd` lives in `game_logic/` rather than being an autoload. It is pure
static data with no per-session state, matching `SkillRegistry` and `BiomeDef`,
and CLAUDE.md's `class_name` rule means every consumer preloads it explicitly
anyway. Adding an autoload for a constant table would cost engine startup work
for no benefit.

## Documentation Updates

`docs/agent/skill-trees.md`, `docs/agent/magic-system.md` (TID-481).
