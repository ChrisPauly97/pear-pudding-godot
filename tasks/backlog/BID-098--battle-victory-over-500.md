# BID-098: BattleVictory.gd over the 500-line cap

**Category:** code-smell
**Discovered During:** GID-182 / TID-761

## Description

The material drops in TID-761 pushed `autoloads/scene_manager/BattleVictory.gd` to about 517 lines, so it now carries the `# gdlint: disable=max-file-lines` tracked-debt pragma.

## Evidence

The header of `autoloads/scene_manager/BattleVictory.gd`.

## Suggested Resolution

Move the joined-enemy rewards (`_reward_joined_enemies`) and the chain pull (`_chain_candidate` / `_start_chain`) into a sibling module under `autoloads/scene_manager/`, then remove the pragma.
