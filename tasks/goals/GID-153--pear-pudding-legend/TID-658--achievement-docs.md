# TID-658: Achievement + Agent Docs

**Goal:** GID-153
**Type:** agent
**Status:** done
**Depends On:** TID-657

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Close the goal: an achievement for brewing the pudding and documentation for the legend systems.

## Research Notes

- `game_logic/AchievementRegistry.gd` `ACHIEVEMENTS` entries `{id, name, description, condition_type,
  target_value, reward_card_id}`; condition `specific_flag` fits (`legend_pudding_owned`). Id `spoonful_of_legend`,
  name "A Spoonful of Legend". Consider hiding description until unlocked (secret achievement) if the UI supports it.
- New doc `docs/agent/legends-pear-pudding.md` (Key Features, How It Works, Integrations, Asset Requirements) and a
  row in the CLAUDE.md docs table; update `home-garden-potions.md` (legendary potion) and
  `story-implementation.md` (legend flags).

## Plan

Secret `specific_flag` achievement on `legend_pudding_owned`, "???" until unlocked; finish the docs.

## Changes Made

- `game_logic/AchievementRegistry.gd`: `spoonful_of_legend` (secret), `display_text()`.
- `scenes/ui/AchievementsScene.gd`: rows use `display_text()`.
- `tests/unit/test_pear_pudding_legend.gd`: achievement test. Full suite + menu smoke, unsafe-hits, gdlint clean.

## Documentation Updates

`legends-pear-pudding.md` (Achievement, Integrations); `story-implementation.md` pointer section.
