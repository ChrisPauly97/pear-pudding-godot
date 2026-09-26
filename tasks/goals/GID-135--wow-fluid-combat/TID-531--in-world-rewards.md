# TID-531: In-World Loot & XP Toasts

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-528

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

WoW doesn't stop you with a result screen: loot and XP pop up and you keep moving. Replace the full-screen result card for routine wins.

## Research Notes

- Result card: `scenes/battle/BattleResultUI.gd` `_build_result_overlay(bg, sep_frac)`, count-up steps; victory logic in
  `autoloads/scene_manager/BattleVictory.gd` (`SceneManager.victory`), defeat in `BattleDefeat.gd`.
- Rewards: coins/essence (`SaveManager` ~L1151), XP/level-up (`_compute_level`, ~L1214), card drops (`CardDropUtil`).
- Plan: routine wins → floating "+XP / +coins / card" toasts over the world plus an XP bar tick (WorldHUD); keep the
  full card for bosses, level-ups (short banner), captures/soulbind choices, and defeats.
- Card-choice rewards need a lightweight non-blocking picker or deferral to a loot notification.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
