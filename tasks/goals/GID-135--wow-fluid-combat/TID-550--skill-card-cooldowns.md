# TID-550: Skill Cards as Reusable Abilities with Cooldowns

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-549, TID-537

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User approved (2026-09-26): skill cards become WoW-style abilities — always available on a small skill bar with their own cooldowns (e.g. 8 s / 30 s / 2 min) — while normal deck cards stay single-use (the hand is their cooldown).

## Research Notes

- Skill cards come from trainers (TID-537). Real-time play paths: `BattleRealtime.run_cast` wraps the solo spell
  paths; GCD / queue in `RealtimeCombat` + CombatTuning.
- Needs: `CardData.cooldown` (s) or a skill-card table, a skill bar UI row (RealtimeVisuals, near your token),
  per-card cooldown sweep, off-GCD flag for utility skills (e.g. an interrupt "Kick" — replaces the Ally-hit
  interrupt as the primary counterplay), tuning knob for a global cooldown multiplier.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
