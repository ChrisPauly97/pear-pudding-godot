# GID-189: Battle Frames Layout (real-time)

## Objective

A more intuitive real-time battle screen, opt-in behind a setting for playtesting: WoW-style **unit frames** (you
top-left, your target top-right with its cast bar and a warning lane under it), Allies as small frames under yours
and enemy minions under the target, the fight itself in the world (non-combatants dimmed, name tags hidden, hits
landing on the real sprites), and the hand as a bottom action bar with pause / auto-attack at the left end.

## Context

- User (2026-10-30): "is there a more intuitive layout for the real time battle?" → approved the rendered mockup;
  "yes build it, dim others, ally frames, behind a setting".
- Current layout: `RealtimeVisuals` (hero tokens that lunge, diagonal board rows via `DiagonalBoard`, locked Ally
  plates `AllySlotLocks`, side panel top-left). `RealtimeVisuals.gd` sits at the 500-line lint cap: new code goes in
  `scenes/battle/modules/FramesLayout.gd`, with thin hooks only.
- Keep every input target (hero views, unit panels, hand) — frames re-place and restyle them; rules untouched.
- Setting: `battle_layout` = `classic` (default) | `frames`, Settings › Battle › Battle Layout. Takes effect next fight.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-801 | Setting + FramesLayout: frames, target cast bar, warning lane, unit rows, corners | agent | done | — |
| TID-802 | World focus: dim non-combatants, hide name tags, hits / lunges / target ring on world sprites | agent | done | TID-801 |
| TID-803 | Verify with real-fight renders, tests, docs | agent | done | TID-802 |
