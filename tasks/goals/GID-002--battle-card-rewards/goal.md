# GID-002: Post-Battle Card Rewards

## Objective

Award the player a card from the defeated enemy's drop pool after winning a battle, completing the "earn cards from battles" game loop described in the spec.

## Context

The spec states cards are earned "from chests and battles." Chest drops are implemented (`Chest.gd` → `SaveManager.add_cards_to_deck`). Battle rewards are not: `SceneManager._on_battle_won()` marks the enemy defeated and restores the world with no card grant. This goal adds a per-enemy drop pool, picks a card on victory, and shows the player a reward overlay before returning to the world.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-005 | Add `drop_pool` field to EnemyData resource | agent | done | — |
| TID-006 | Implement post-battle reward flow + BattleScene reward UI | agent | pending | TID-005 |

## Acceptance Criteria

- [ ] Each `EnemyData` resource has a `drop_pool: PackedStringArray` field
- [ ] All four enemy `.tres` files have non-empty drop pools populated
- [ ] After a battle win, exactly one card from the drop pool is added to `SaveManager.owned_cards`
- [ ] A reward overlay in `BattleScene` displays "You won! You earned: [Card Name]" with a confirm button
- [ ] Confirming the reward dismisses the overlay and triggers the normal world restore
- [ ] `GameBus.battle_won` result dict includes a `"card_reward"` key with the card ID
