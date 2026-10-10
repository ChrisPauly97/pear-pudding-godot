# BID-100: Battlefield school boost lost on resumed battles

**Category:** code-smell
**Discovered During:** TID-755 (GID-181)

## Description

The battlefield school boost (`BattlefieldRules.school_env_table`, stored on `PlayerState.env_school_mult`) is computed in `BattleModifiers._apply_school_environment()` on the fresh battle setup path only. A battle resumed from a mid-fight save skips that path, so its `env_school_mult` is empty (neutral). Weather is not persisted, so the weather part cannot be recomputed from the save either; biome and night are persisted in GameState.

## Evidence

`scenes/battle/BattleScene.gd` (`_saved_battle` branch vs. the `set_battlefield_context` setup call), `game_logic/battle/PlayerState.gd` (`env_school_mult`, not serialized).

## Suggested Resolution

Recompute the table on resume from the restored biome and night, and persist the weather id in the battle save so the full table is restored.
