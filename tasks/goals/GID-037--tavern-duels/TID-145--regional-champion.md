# TID-145: Regional Champion NPC + Legendary Reward

**Goal:** GID-037
**Type:** agent
**Status:** done
**Depends On:** TID-144

## Lock

_Released._

## Context

The champion is the payoff for the duel ladder: an NPC who refuses to play until every regional duelist is beaten, then offers the toughest friendly duel in the region for a legendary card. This is the Gym Leader beat that turns scattered duels into a progression.

## Research Notes

- **Champion NPC:** A duelist TownspersonNPC (TID-144 schema) in `assets/maps/blancogov.tres` with an extra export `required_duelist_ids: Array[String]` — the npc_ids that must appear in `SaveManager.defeated_duelists` before the duel is offered.
- **Gating dialogue:** If requirements unmet, interact shows "I only duel proven players. Beat the others in town first." Optionally list remaining count ("2 more to go").
- **Champion deck:** New EnemyData `.tres` (`duelist_champion`) with a strong deck using keyword minions from GID-025 and spells from GID-018. High wager (e.g. 50 coins).
- **Legendary reward:** On first champion defeat, award a legendary card directly to the collection (one-time, gated by a `champion_defeated` entry in `defeated_duelists` or a dedicated save flag). Check `data/cards/` for an existing legendary to use, or create one new CardData `.tres` + `.uid` following the rarity schema from GID-028 (`CraftingRegistry.gd` has the rarity definitions).
- **Reward presentation:** Reuse the post-battle card reward flow from GID-002 (check `BattleScene` / reward overlay) so the legendary is shown, not silently added.
- **Achievement hook:** Consider an `AchievementRegistry` entry "Regional Champion" — check `game_logic/AchievementRegistry.gd` for the registration pattern (GID-024).
- `docs/agent/meta-progression.md` — note the achievement if added.
- `docs/agent/enemies-and-npcs.md` — document champion gating.

## Plan

1. Add `required_duelist_ids: PackedStringArray` and `champion_reward_card: String` to `MapNpc.gd`.
2. Update `WorldMap.gd` NPC parse + `to_map_data()` to round-trip them.
3. Create `data/enemies/duelist_champion.tres` + `.uid` (strong 10-card deck, difficulty 3).
4. Create `data/cards/duel_crown.tres` + `.uid` (new legendary reward for champion defeat).
5. Update `WorldScene._show_duel_offer_panel` — check `required_duelist_ids` gate before wager, pass `champion_reward_card` in enemy_data.
6. Update `SceneManager` — track `_current_champion_reward`, award legendary + story flag on first champion win.
7. Add `regional_champion` achievement to `AchievementRegistry.gd` (specific_flag: champion_blancogov_defeated).
8. Add champion NPC to `blancogov.tres` (tile 55,50, requires duelist_2 defeated, wager 50).
9. Update `docs/agent/enemies-and-npcs.md` and `docs/agent/meta-progression.md`.

## Changes Made

- **`game_logic/world/resources/MapNpc.gd`** — added `required_duelist_ids: PackedStringArray` and `champion_reward_card: String` export fields.
- **`game_logic/world/WorldMap.gd`** — NPC parse block reads both new fields; `to_map_data()` writes them back.
- **`data/enemies/duelist_champion.tres`** + `.uid` — 10-card deck: Ghoul×2, BlitzGhoul×2, ShroudedWraith, VoidWyrm, Wither×2, SoulRend, DarkPact; difficulty 3.
- **`data/cards/duel_crown.tres`** + `.uid` — new legendary card (5 mana, 4/4) awarded on champion defeat.
- **`autoloads/CardRegistry.gd`** — added `_C_DUEL_CROWN` preload and registered in `_ensure_loaded()`.
- **`scenes/world/WorldScene.gd`** — `_show_duel_offer_panel` checks `required_duelist_ids` gate; shows remaining count; only shows Duel button if gate cleared; passes `champion_reward_card` in `enemy_data`.
- **`autoloads/SceneManager.gd`** — added `_current_champion_reward`; `_on_duel_requested` stores it; `_on_duel_won` awards legendary + sets story flag on first win; `_on_duel_lost` clears it.
- **`game_logic/AchievementRegistry.gd`** — added `regional_champion` achievement (specific_flag: `champion_blancogov_defeated`).
- **`assets/maps/blancogov.tres`** — added champion NPC at tile (55,50): enemy=duelist_champion, wager=50, requires duelist_2 defeated, reward=duel_crown.

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` — expanded Duelist NPC section: champion gate fields, interact flow priority, champion legendary reward path, updated enemy table.
- `docs/agent/meta-progression.md` — updated achievement count (9→10), noted duel_crown award path differs from achievement card grants.
