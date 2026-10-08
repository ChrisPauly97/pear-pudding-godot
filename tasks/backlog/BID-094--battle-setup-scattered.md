# BID-094: Battle setup is scattered across the scene and reads autoloads

**Category:** code-smell
**Discovered During:** GID-176 / research

## Description

What a fight starts with (enemy tier and zone scaling, boss HP, packs, unlock stripping, gear, caps, opening hand) is spread across `BattleScene._ready`, about 15 `BattleModifiers` helpers and `BattleRealtime.maybe_start`. Most of it reads `SceneManager.save_manager` directly, so none of it can be tested or simulated without the full scene.

## Evidence

`scenes/battle/BattleScene.gd` ~480–575, `scenes/battle/modules/BattleModifiers.gd`, `scenes/battle/modules/BattleRealtime.gd` `maybe_start`.

## Suggested Resolution

GID-176 / TID-714 extracts the real-time PvE path into `BattleSetup.gd`. Afterwards, migrate the remaining modifiers (weather, gambits, ambush, blight, spire / siege HP) to take values instead of reading autoloads.
