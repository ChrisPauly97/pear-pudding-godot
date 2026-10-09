# TID-753: Bestiary reveals school profiles

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-750, TID-752

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Knowledge as progression: learning matchups is part of advancing. First encounter hints, defeat reveals the profile.

## Research Notes

- Save: `SaveManager.bestiary` (L284) is `type_id -> {seen, defeated}` — no new persisted field needed (derive: seen ≥1 → attack school known; defeated ≥1 → resist/weak known). Optionally reveal a single school when the player lands a Weak!/Resisted hit (would need a new field — add via PERSISTED_FIELDS + SaveMigrations only if chosen).
- Journal: `scenes/ui/JournalScene.gd` bestiary tab (see docs/agent/bestiary-codex.md) — add a Weak/Resist row with school icons, '?' when unknown.
- Gate TID-752 nameplate pips on this knowledge; floating Weak!/Resisted always shows (that's how players learn).
- Co-op: bestiary is per-player save; fine.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
