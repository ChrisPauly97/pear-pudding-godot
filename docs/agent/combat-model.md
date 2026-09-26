# Combat Model — Hero Spells, Allies, Enemy Packs (GID-135 / TID-540)

**Status:** **Option A approved** by the user (2026-09-26). TID-537, TID-541, TID-542, TID-543, TID-544 and TID-545 build on it.

## Problem

1. The user wants battle to be "mostly spells", with skill cards as your abilities, regular
   (creature) cards as companions, and consumables used from the inventory / a D3-style quick slot.
2. A world enemy is **one** sprite, but in battle it has a 20–30 card deck and summons a board of
   ghouls. What you see in the world is not what you fight.
3. Fights should feel WoW-fluid: short, readable, few dead turns.

## Where we are today (facts)

| Area | Today |
|---|---|
| Card pool | 117 cards: **85 spells**, 26 minions, 6 legendaries (`data/cards/*.tres`) — already spell-heavy |
| Structure | Hearthstone-like: two heroes (30 HP), 5 board slots each, mana +1/turn to 10, 1 draw/turn |
| Enemy | `EnemyRegistry` deck of minions (e.g. `ghoul_pack` = 5 ghoul + zombies + skeleton); `phase2_deck` for bosses |
| Skills | 32 passive + 16 active; one active = **hero power button** (`BattleConsumables`) |
| Consumables | `SaveManager.potions`; one potion per battle via picker |
| Gear | 4 slots; gear can inject cards (`WeaponData.injected_card_id`) |
| Soulbinding | Winning under a capture condition earns an enemy's signature **minion** card |
| "Companion" | Already a term: Maiteln etc., one equipped passive (`CompanionRegistry`). Avoid the name clash. |

## Options

### A. Hero & Allies (recommended)

You are the fighter; spells are your abilities; creature cards are a small band of **Allies**.

- **Deck:** spells + skill cards (learned from trainers, TID-537) + gear-injected cards, plus
  **at most 5 Ally cards** (creature/soulbound cards). Deck size rules unchanged (5–30).
- **Your turn:** play spells/skills with mana; summon an Ally into one of **3** ally slots;
  your hero **auto-attacks** once per turn with the equipped weapon (WoW auto-attack).
  Weapon damage from gear gives gear a direct, felt effect.
- **Faster start:** start at **3 mana** (ramp +1 to 10), draw 4 opening cards — fights are 3–6 turns, not 8–12.
- **Enemy side = encounter** (fixes problem 2), three shapes defined in `EnemyRegistry`:
  | Shape | World | Battle | Win |
  |---|---|---|---|
  | **Pack** (ghoul_pack, undead_horde, spectres) | 2–4 sprites | those units **start on the board**; no enemy hero | clear the board |
  | **Solo** (elite, duelist, most bosses) | 1 sprite | enemy hero only; plays **ability cards** (strike, cleave, enrage, heal) from an ability deck; no summons | hero to 0 |
  | **Summoner** (necromancer, Martarquas shaman, bosses' phase 2) | 1 sprite + ritual FX | current model: hero + summoning deck | hero to 0 |
- **Telegraphs:** the enemy's next action shows as a **cast bar** on the unit that will act
  (evolves today's intent banner) — reads like WoW and lets you react.
- **Consumables:** 2 quick slots (TID-542), usable any time on your turn, **no mana cost**, shared
  **3-turn cooldown** instead of "one per battle". Same buttons usable in the world.
- **Hero power button removed:** active skills become skill cards; passives stay in the tree.
- **Soulbinding stays:** signature cards become Allies (more attractive — they're your party).
- **PvP/co-op:** duels keep hero-vs-hero with the same deck rules (Ally cap applies to both).
  Co-op PvE vs pack/boss works unchanged in shape.

Cost: medium-high. Touches GameState setup/win check, BasicAI (per-unit pack AI + ability AI),
deck validation, weapon data, save migration for decks with >5 minions (auto-move extras to collection).

### B. Keep the Hearthstone model, fix the encounters only

Only the Pack/Solo/Summoner encounter shapes + faster start + quick slot. Minions stay unlimited,
hero power stays. Cheap and low-risk, but battles don't become "mostly spells" and your hero is still passive.

### C. Full action bar (no hand)

A fixed bar of 6 abilities with cooldowns and mana, like WoW itself; cards are only collected to
fill the bar. Most WoW-like, but drops draw/hand/deckbuilding — the game's core TCG identity and
the spec positioning ("every enemy can be soulbound into your deck"). Not recommended.

## Recommendation

**Option A**, rolled out in phases so each ships on its own:

1. **Encounter shapes** (TID-541) — pack/solo/summoner; enemy side only; biggest "makes sense" win.
2. **Pace + controls** (TID-529/530/542) — 3-mana start, quick slots with cooldown, cast bars.
3. **Hero kit** (TID-537 + new work in TID-538) — weapon auto-attack, skill cards replace hero power, 3 Ally slots + deck cap with save migration.

## Battle control layout (landscape phone)

```
┌────────────────────────────────────────────┬────────┐
│  enemy units / enemy hero  (cast bars)     │ ⓘ      │
│────────────────────────────────────────────│        │
│  your 3 ally slots        [HERO ⚔ auto]    │ END    │
│                                            │ TURN   │
│ [Q potion][2 potion]   hand: spells/skills │        │
└────────────────────────────────────────────┴────────┘
```
Keyboard: `Q`/`1`–`2` quick slots, `Space` end turn, number row for hand cards (TID-530).

## Decisions (2026-09-26)

1. **Option A** — Hero & Allies.
2. **Allies are ordinary deck cards**: drawn and played like any card, never auto-deployed at battle start.
   Cap: at most 5 Ally cards per deck, 3 Ally board slots (tunable in TID-545).
3. **Hero HP carries over between fights**, with slow out-of-combat regen and a full heal in towns / beds.
   Healing must be accessible early: more low-level hero heal spells, **food** consumables (out-of-combat
   regen, WoW-style) alongside the existing persistent potions (TID-543).
4. **Terminology** (use everywhere — UI text, docs, code names for new work):
   | Term | Meaning |
   |---|---|
   | **Mentor** | Maiteln-style passive helper; one equipped at a time (today's in-game "Companion") |
   | **Ally** | A player creature card / unit on the player's board |
   | **Minion** | An enemy creature unit on the enemy board |
