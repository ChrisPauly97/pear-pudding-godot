# GID-034: Battle State Pause/Resume Persistence

## Objective

Save the full mid-battle GameState whenever the player exits a battle via the pause menu or the app is backgrounded, and restore it on re-entry so the battle continues from the exact point it was left.

## Context

When a player opens the in-game pause overlay and taps "Return to Menu" → "Yes, leave", the live `GameState` is discarded. `pending_battle_enemy_data` is still in the save file, so on "Continue" the battle restarts completely from scratch (new shuffled deck, full HP, turn 1). This is especially painful on Android where the back button or OS process kill can trigger the same path accidentally.

The existing `ZoneState.snapshot()` / `restore_snapshot()` stubs hint at a planned checkpoint system but were never wired up.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-129 | Serialize GameState to/from Dictionary | agent | done | — |
| TID-130 | Add pending_battle_state field to SaveManager | agent | done | TID-129 |
| TID-131 | Save battle state on exit and app background | agent | done | TID-130 |
| TID-132 | Restore saved battle state on battle re-entry | agent | pending | TID-131 |
| TID-133 | Update agent docs (battle-system, save-system) | agent | pending | TID-132 |

## Acceptance Criteria

- [ ] Returning to menu mid-battle and continuing restores the exact board, hands, HP, mana, and turn number
- [ ] Backgrounding the app (Android focus-out) also persists state
- [ ] Battle state is cleared on normal win or loss (not left as stale data)
- [ ] Old saves without `pending_battle_state` load without error (migration v14 backfills `{}`)
