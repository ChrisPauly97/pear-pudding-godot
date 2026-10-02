# TID-658: Achievement + Agent Docs

**Goal:** GID-153
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
