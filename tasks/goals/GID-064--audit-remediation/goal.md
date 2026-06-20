# GID-064: Codebase Audit Remediation — Performance, Native Patterns & Bug Fixes

## Objective

Fix the high- and medium-severity bugs, performance gaps, and non-native-Godot patterns
identified by the full-codebase audit (June 2026), prioritising issues that affect the
Android primary platform.

## Context

A four-slice audit (world/terrain, battle system, UI scenes, autoloads/save system)
surfaced ~90 verified findings. The most serious: a split-brain dual SaveManager that
silently loses scroll persistence; saves that can be wiped by an Android background-kill;
two registries that come up empty inside an exported APK; chunk streaming that leaves
permanent terrain holes; battle passives that are completely non-functional; and a
battle save/resume soft-lock. This goal remediates them in dependency order. Larger
refactors surfaced by the audit (shared Theme, native drag-and-drop, overlay boilerplate
dedup, persistence test coverage) are logged as backlog items BID-009..BID-014 rather
than tasks.

User decisions captured at goal creation:
- The AI's permanent +1 mana edge (shared half-turn counter) is a **bug** — both players
  ramp equally. Tests codified the old behaviour and must be updated.
- AI minions attacking the player hero **take hero-attack retaliation**, matching the
  player-side rule, so `passive_atk` matters on defense.
- Enemy engagement becomes **mixed**: some enemies start battles on proximity (the
  existing `tracking: true` field becomes meaningful), others remain interact-first.
  Tutorial tip text updated to match.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-226 | Unify the split-brain SaveManager instances | agent | done | — |
| TID-227 | Android save robustness | agent | done | TID-226 |
| TID-228 | Convert EnemyRegistry & WeaponRegistry to preload consts | agent | done | — |
| TID-229 | Fix lambda signal-connection leaks & overlay ownership | agent | done | — |
| TID-230 | Chunk streaming correctness | agent | done | — |
| TID-231 | Chunk streaming & rendering performance | agent | done | TID-230 |
| TID-232 | Battle rules fixes | agent | done | — |
| TID-233 | Battle save/resume fixes | agent | done | TID-232 |
| TID-234 | Battle UI performance & enemy hand concealment | agent | done | TID-232 |
| TID-235 | UI scene fixes | agent | done | — |
| TID-236 | Dead code & config cleanup sweep | agent | done | — |
| TID-237 | Proximity battle engagement for tracking enemies | agent | done | TID-236 |

## Acceptance Criteria

- [ ] Exactly one SaveManager instance exists; scroll pickups, journal entries, and NPC
      flag-gated dialogue persist across restarts.
- [ ] Backgrounding the app on Android flushes the save; a kill mid-write cannot wipe
      the save file (atomic write + fallback).
- [ ] EnemyRegistry and WeaponRegistry resolve all enemies/equipment inside an exported
      APK (preload consts; no DirAccess/dynamic load).
- [ ] Walking out of and back into the spawn area never leaves terrain holes.
- [ ] No connection-to-freed-node errors after repeated map transitions.
- [ ] `starting_mana`, `passive_mana`, and `bonus_draw` measurably work in battle;
      `time_warp` and `soul_harvest` resolve their effects.
- [ ] Both players ramp mana equally; AI minions take hero retaliation on face attacks.
- [ ] A battle saved during the AI turn resumes and completes without soft-locking.
- [ ] Enemy hand renders as card backs; inventory taps no longer rebuild the full list
      or reset scroll position.
- [ ] Enemies with `tracking: true` engage on proximity; others remain interact-first.
- [ ] All tests pass headless (`godot --headless --path . -s tests/runner.gd`).
