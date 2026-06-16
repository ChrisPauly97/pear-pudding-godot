# GID-054: Town Siege Defense

## Objective

Martarquas raiders periodically besiege a town; the player defends it in a 3-battle gauntlet where hero damage carries between fights, earning rewards and a temporary shop discount.

## Context

The Martarquas tribe is the story's rising threat but never does anything. Sieges make the threat real, and the carry-over-HP gauntlet is a pressure no other mode has (Spire heals between floors via drafting; sieges don't). The gratitude discount ties defense back into the economy.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-197 | Siege model: trigger conditions, 3-battle gauntlet state with carry-over hero HP, save fields | agent | done | — |
| TID-198 | Siege presentation: raider entities at the town gate, start/retreat flow, siege banner HUD state | agent | done | TID-197 |
| TID-199 | Victory rewards + town gratitude shop discount + defeat consequence | agent | done | TID-197 |

## Acceptance Criteria

- [ ] A siege can trigger on entering a town when conditions are met (a mid-chapter story flag is set, at least N days since the last siege, seeded so it's deterministic per save+day); active/cooldown state persists in SaveManager with migration
- [ ] The gauntlet chains 3 battles against raider decks of rising difficulty; the player's hero HP carries over between battles (healing between fights only via potions/effects if those exist); deck is the player's normal deck
- [ ] Raider entities visibly mass at the town gate during a siege; talking to any raider (or a banner prompt) starts the gauntlet; the player can walk away and return — the siege persists until fought or 1 in-game day passes (town "holds out")
- [ ] Winning all 3 battles awards coins + a rare-or-better card and starts a gratitude window: that town's shop prices are discounted ~20% for 3 in-game days; losing any battle ends the siege with no reward and a small coin loss, never blocking story progress
- [ ] Sieges never trigger in dungeons, the infinite world, or before the gating story flag
- [ ] All tests pass headless
