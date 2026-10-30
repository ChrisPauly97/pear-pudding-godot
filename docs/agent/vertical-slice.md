# Vertical Slice (GID-188)

A 30–45 minute cut of the full game that proves the core loop is fun:
**explore → real-time card fight → soulbind → the deck changes the next fight and opens the world (Dig)**.
Out-of-slice systems are hidden, never deleted.

## Key Features

- One gate: project setting `pear_pudding/slice_mode` (on in `project.godot`).
- One table: `game_logic/SliceRules.gd` — `LEVEL_CAP`, `LADDER` (learnable UnlockLadder rows), `MENU`
  (main-menu entries), `BATTLE_MODE`.
- Feature freeze: inside the slice, a change lands only if it improves the core loop; other ideas go to the backlog.

## How It Works

| Gate | Where | Effect in the slice |
|---|---|---|
| Ladder | `UnlockLadder.available_at` / `pending` / `for_trainer` / `can_learn` | Only `SliceRules.LADDER` rows (Mend, Kick, Allies, spells, companion, Dig) appear at trainers or can be learned |
| Menu | `MenuScene._ready` | Co-op, Achievements, Map Editor hidden |
| Battle mode | `SaveManager.battle_mode()` → `SliceRules.battle_mode()` | Always real time; the Settings choice is ignored |
| HUD | (indirect) | Mount / Phase buttons are already gated on `has_learned`, so the ladder gate hides them |

Planned (TID-795): level cap enforcement, Madrian + starter camps only (other towns, sea/rivers, caves, rifts
hidden), slice boss + completion screen. Chunk generation is threaded: pass the slice flag in as a pure input
rather than reading `ProjectSettings` from worker code.

## Tests

- `tests/unit/test_slice_rules.gd`. `tests/runner.gd` sets `SliceRules.override = 0`, so every other suite
  tests the full game; a slice test sets `override = 1` and `after_each` resets it.
- Smoke tests run with the shipped setting (slice on). One that exercises full-game-only paths sets
  `override = 0` in `_initialize` (`battle_input_flow_smoke` — turn-based input).

## Integrations

UnlockLadder (trainers, level-up toasts), SaveManager settings, MenuScene. Follow-up tasks: GID-188 goal file.

## Asset Requirements

None.
