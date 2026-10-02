# GID-153: The Pear Pudding — Secret Legendary Potion

## Objective

Write the game's name into the lore: a hidden world-puzzle quest, learned from townsfolk tales, that rewards one
permanent legendary item — Perrine's Bottomless Pudding.

## Context

The app icon (pear-shaped potion flask over a sword, `tools/generate_app_icon.py`) made "Pear Pudding" a potion.
This goal makes it a legend: Pear Pudding was the lost royal remedy of Old Mother Perrine, alchemist to King Eldar's
grandfather. It is an easter egg — no quest-giver "!", no compass/map waypoint, no Quest Log row. The player hears
tales from certain people, each a riddle, and solves them in the world.

Flow:
1. **Tales** — four NPCs (old soldier in Madrian, child's rhyme in Maykalene, tavern bard in Blancogov, grumbling
   farmer in Larik) each tell one fragment when a condition fits. Fragments go to a Journal "Old Tales" page as riddle
   text only.
2. **Puzzles** — each riddle points to a real spot that reacts only under its condition:
   - "Where three stones lean and the sun goes down, the earth remembers." → Skeleton Dig at dusk by a standing-stone
     trio → the Burnt Recipe.
   - "The pear that never rots hangs where no orchard grows." → lone golden pear tree on a cliff in the wilds.
   - "Ask the dead what they sighed." → defeat a spectre on a Night Hunt while carrying the recipe → Spectre's Sigh.
   - "Stir it where the old queen drank, when the rain sings." → brew at a ruined well while it rains.
3. **Payoff** — brew scene, then **Perrine's Bottomless Pudding**: a unique, never-consumed legendary flask. Refills
   before every battle, one sip per fight (full heal, clear statuses, +1 mana), shares the potion cooldown.
   Achievement "A Spoonful of Legend".

Reward is deliberately one-off and permanent (user direction): it must feel rewarding, not consumable.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-653](TID-653--story-legend.md) | Pear Pudding legend + four tales in `story.md` | human-action | pending | — |
| [TID-654](TID-654--tale-system.md) | Tale system: conditional rumour lines, Journal "Old Tales", puzzle flags | agent | pending | — |
| [TID-655](TID-655--riddle-spot-entity.md) | Riddle-spot entity gated by time/weather/cantrip/item | agent | pending | — |
| [TID-656](TID-656--bottomless-pudding.md) | Perrine's Bottomless Pudding legendary item + battle effect + icon | agent | pending | — |
| [TID-657](TID-657--puzzle-content.md) | Puzzle content: tales, spots, brew scene, reward, tests | agent | pending | TID-654, TID-655, TID-656 |
| [TID-658](TID-658--achievement-docs.md) | Achievement + agent docs | agent | pending | TID-657 |

## Acceptance Criteria

- [ ] No marker, waypoint, quest-giver mark or Quest Log row ever points at the quest
- [ ] Each of the four tales is only heard from its NPC and lands on the Journal "Old Tales" page as riddle text
- [ ] Each puzzle spot does nothing outside its condition and progresses the legend inside it
- [ ] Brewing grants Perrine's Bottomless Pudding exactly once; it is never consumed and refills every battle
- [ ] Progress persists through save/load and the full chain is covered by tests
- [ ] Achievement unlocks on brewing; agent docs describe the system
