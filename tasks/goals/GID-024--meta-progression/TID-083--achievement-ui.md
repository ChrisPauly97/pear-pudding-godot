# TID-083: Achievement UI — Toast Notification and List Screen

**Goal:** GID-024
**Type:** agent
**Status:** pending
**Depends On:** TID-082

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With achievements tracked (TID-082), players need two UI surfaces: an in-game toast notification when an achievement unlocks, and a list screen accessible from the main menu.

## Research Notes

- **Toast notification:**
  - Add an `AchievementToast` CanvasLayer node to WorldScene and BattleScene (or one global CanvasLayer in SceneManager)
  - On `GameBus.achievement_unlocked` signal: show a Panel with achievement name and description; animate slide-in from top-right, display for 3s, slide out
  - Follow CLAUDE.md UI sizing (viewport-relative); toast panel ~20% viewport width, ~8% viewport height
  - Do not block input while toast is visible

- **Achievement list screen:**
  - New scene `scenes/ui/AchievementsScene.gd` — a ScrollContainer of achievement rows
  - Each row: achievement name, description, progress bar (current / target), lock icon if not unlocked
  - Unlocked achievements show in full color; locked ones are greyed out
  - Add "Achievements" button to MenuScene (the main menu)
  - `SceneManager` needs a route to AchievementsScene (add state `ACHIEVEMENTS`)
  - Back button returns to menu
  - Follow CLAUDE.md UI sizing and mobile parity rules

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
