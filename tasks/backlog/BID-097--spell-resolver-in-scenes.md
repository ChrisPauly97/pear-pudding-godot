# BID-097: SpellEffectResolver lives in scenes/ but is core game logic

**Category:** code-smell
**Discovered During:** GID-181 research

## Description

`scenes/battle/SpellEffectResolver.gd` holds the bulk of damage/spell resolution (12 `take_damage` sites) and is driven by the headless balance sim (`game_logic/battle/BalanceBot.gd` `act(caster, resolver)`), yet sits in the scene layer. Pure rules in `scenes/` blur the game_logic/scene split and make it easy to reach scene state from the sim path.

## Evidence

- `game_logic/battle/BalanceBot.gd:83` takes a `SpellEffectResolver`.
- `take_damage` call sites spread over `SpellEffectResolver`, `BattleInput`, `BattleNet`, `BattleFx`, `RealtimeCombat`, `PlayerState`, `BattleModifiers`.

## Suggested Resolution

When TID-749 introduces the single damage resolver, consider moving the pure parts of `SpellEffectResolver` to `game_logic/battle/` (keeping sfx/fx hooks in the scene layer).
