# TID-010: Wire Battle Sound Effects

**Goal:** GID-004
**Type:** agent
**Status:** done
**Depends On:** TID-009

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`BattleScene` should play audio feedback when meaningful battle events occur. All calls go through `AudioManager.play_sfx()` — no hard-coded stream paths in `BattleScene`.

## Research Notes

**BattleScene** (`scenes/battle/BattleScene.gd`):
- Listens to `GameBus` signals: `card_played`, `card_attacked`, `battle_ended`
- Read the file before editing to confirm the signal connection methods and their names.

**SFX to wire:**

| Event | Signal / Location | SFX name |
|---|---|---|
| Card played by player | `GameBus.card_played` handler | `"card_play"` |
| Attack lands (either side) | `GameBus.card_attacked` handler | `"attack"` |
| Player wins | `GameBus.battle_ended(winner)` where winner == 0 | `"battle_win"` |
| Player loses | `GameBus.battle_ended(winner)` where winner == 1 | `"battle_lose"` |

**Implementation pattern:**
```gdscript
# In BattleScene._ready() — already connects to GameBus signals
# Just add the play_sfx call inside the existing handlers:

func _on_card_played(card_id: String, zone: String, slot: int) -> void:
    AudioManager.play_sfx("card_play")
    # ... existing UI refresh

func _on_card_attacked(attacker_id: String, target_id: String) -> void:
    AudioManager.play_sfx("attack")
    # ... existing UI refresh

func _on_battle_ended(winner: int) -> void:
    if winner == 0:
        AudioManager.play_sfx("battle_win")
    else:
        AudioManager.play_sfx("battle_lose")
    # ... existing result handling
```

**AI turn SFX:** BasicAI plays cards and attacks automatically. The same `GameBus` signals fire regardless of who acts, so `"card_play"` and `"attack"` will trigger on AI actions too — which is correct (audio confirms the event, not the actor).

## Plan

Add `AudioManager.play_sfx()` calls directly at the 4 battle event points in `BattleScene.gd`:
1. `_finish_hand_drag()` — after successful `play_card()` → `"card_play"`
2. `_on_enemy_card_input()` — before dealing damage → `"attack"`
3. `_on_enemy_hero_input()` — before dealing damage → `"attack"`
4. `_check_game_over()` — before showing overlay or emitting signal → `"battle_win"` / `"battle_lose"`
5. `_execute_ai_actions()` — before each AI action → `"attack"` (AI plays and attacks all produce audio)

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - `_finish_hand_drag()`: added `AudioManager.play_sfx("card_play")` on successful card play
  - `_on_enemy_card_input()`: added `AudioManager.play_sfx("attack")` before minion combat
  - `_on_enemy_hero_input()`: added `AudioManager.play_sfx("attack")` before hero attack
  - `_check_game_over()`: added `AudioManager.play_sfx("battle_win")` and `"battle_lose"` per winner
  - `_execute_ai_actions()`: added `AudioManager.play_sfx("attack")` before each AI action

## Documentation Updates

No agent doc changes needed — `docs/agent/story-implementation.md` covers story; audio is documented under the AudioManager task (TID-009).
