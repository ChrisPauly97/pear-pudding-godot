# TID-010: Wire Battle Sound Effects

**Goal:** GID-004
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
