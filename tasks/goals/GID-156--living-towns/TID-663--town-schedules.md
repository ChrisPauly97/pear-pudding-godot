# TID-663: Daily Schedules for Townsfolk

**Goal:** GID-156
**Type:** agent
**Status:** pending
**Depends On:** TID-662

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make towns change over the day: busy streets by day, quieter at dusk, mostly empty at night with a lantern-carrying
guard on patrol. Builds on the TownLife walkers.

## Research Notes

- Clock: `DayNightCycle` (`scenes/world/DayNightCycle.gd`): `get_time_of_day()` 0..1, `is_night_now()`,
  signals `night_started`, `dawn_arrived`, `day_passed`. Built by `WorldClock` module as `_world._dnc`; co-op
  clock is host-synced. Keep schedule a pure function of time-of-day so peers agree.
- Add roles to `game_logic/world/TownLife.gd`: e.g. `villager`, `shopper` (market stops), `reveller` (tavern
  door at dusk/night), `guard` (patrol loop gate → square → gate). Role is seeded per NPC id. Slots:
  day / dusk / night → stop set + walking yes/no + "indoors" (hidden).
- Indoors: hide the node (`visible = false`) and remove/skip its `_active_npc_data` entry so the interact prompt
  doesn't target an invisible NPC; restore at dawn. Prefer fading (`modulate:a` on the Sprite3D child, not the
  Node3D — CLAUDE.md nocturnal learning). Fixed (non-walker) NPCs are untouched.
- Guard lantern: small warm OmniLight3D or reuse `NightLights` rig (`scenes/world/modules/NightLights.gd`
  — respect its tier caps); only at night. Guard may be a walker repurposed, not a new spawn.
- Story overrides: during a town siege (`TownSiege` module) keep townsfolk indoors.
- Tests: pure schedule tests in `tests/test_town_life.gd` (role → slot at sample times, guard only at night,
  indoors count at night > day).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
