# TID-144: Duelist TownspersonNPC Wiring + Save Tracking

**Goal:** GID-037
**Type:** agent
**Status:** done
**Depends On:** TID-143

## Lock

_Released._

## Context

With duel mode in place (TID-143), this task makes townsfolk into duelists: a flagged TownspersonNPC offers a wager duel on interact, and defeated duelists are tracked per save so the ladder (TID-145) can gate the champion.

## Research Notes

- `scenes/world/entities/TownspersonNPC.gd` — has `npc_id`, `dialogue_key`, proximity interact. Add export vars: `is_duelist: bool`, `duelist_enemy_id: String` (EnemyRegistry key), `wager_coins: int`.
- **Interact flow:** If `is_duelist`, the interact prompt becomes a two-line dialogue: "Care for a friendly duel? Wager: N coins. [Duel] [Decline]". Check how NPC dialogue UI is built (likely a panel in WorldScene or the NPC itself) — a simple two-button popup is enough; size buttons relative to viewport per the UI sizing rule.
- **Insufficient coins:** If the player has fewer coins than the wager, show "Come back when you can cover the wager" instead of the duel offer.
- `autoloads/SaveManager.gd` — add `defeated_duelists: Array` (of npc_id strings) with migration. Append on duel win via a `GameBus.duel_won(npc_id)` signal or directly from BattleScene's duel-end handler (which knows the duel context from TID-143).
- **Rematch rule:** Beaten duelists still offer duels (dialogue changes to "A rematch?") but with wager halved — keeps towns interactive without grinding value.
- **Map placement:** Flag 2–3 existing townspeople in `assets/maps/madrian.tres` and `assets/maps/blancogov.tres` as duelists. Map entities are stored in the `.tres` map resources (GID-017 migration) — check `game_logic/world/WorldEntity.gd` and `MapRegistry.gd` for the entity property schema before editing.
- **Mobile parity:** The duel offer must be tappable buttons, not a key prompt (per CLAUDE.md mobile parity rule).
- `docs/agent/enemies-and-npcs.md` — document the duelist NPC variant.

## Plan

1. Add `duelist_enemy_id` and `wager_coins` export vars to `MapNpc.gd`.
2. Update `WorldMap.gd` NPC parse block + `to_map_data()` to round-trip those fields.
3. Add `defeated_duelists: Array[String]` to `SaveManager`, bump save version to 15, add migration.
4. Add `_current_duel_npc_id` tracking + `duel_won`/`duel_lost` handlers in `SceneManager`.
5. Add `_show_duel_offer_panel()` in `WorldScene` (wager display, insufficient-coins guard, rematch halving, Duel/Decline buttons).
6. Create `data/enemies/duelist_novice.tres` and `duelist_adept.tres` with .uid sidecars.
7. Place duelist NPCs in `madrian.tres` (novice, wager 15) and `blancogov.tres` (adept, wager 25).
8. Update `test_named_map_npcs.gd` madrian NPC count 8 → 9.

## Changes Made

- **`game_logic/world/resources/MapNpc.gd`** — added `@export var duelist_enemy_id: String` and `@export var wager_coins: int`.
- **`game_logic/world/WorldMap.gd`** — NPC parse block reads `duelist_enemy_id`/`wager_coins` from resource; `to_map_data()` writes them back.
- **`autoloads/SaveManager.gd`** — added `defeated_duelists: Array[String]`, `mark_duelist_defeated()`, save version 15 + `_migrate_v14_to_v15()`.
- **`autoloads/SceneManager.gd`** — added `_current_duel_npc_id`, connected `duel_requested`/`duel_won`/`duel_lost` signals; `_on_duel_won()` calls `mark_duelist_defeated`.
- **`scenes/world/WorldScene.gd`** — added `_show_duel_offer_panel(npc)`: shows wager offer or insufficient-funds message; rematch halves wager; tappable Duel/Decline buttons.
- **`data/enemies/duelist_novice.tres`** + `.uid` — deck: Ghost×3, Skeleton×3, Zombie×2, Ghoul, Mend; difficulty 1.
- **`data/enemies/duelist_adept.tres`** + `.uid` — deck: Ghost×2, Skeleton×2, Zombie×2, Ghoul×2, Mend, Wither, SurgeSpirit, EmberImp; difficulty 2.
- **`assets/maps/madrian.tres`** — added duelist NPC at tile (30, 20), enemy=duelist_novice, wager=15.
- **`assets/maps/blancogov.tres`** — added duelist NPC at tile (35, 50), enemy=duelist_adept, wager=25.
- **`tests/unit/test_named_map_npcs.gd`** — updated madrian NPC assertion from 8 → 9.

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` — added Duelist NPC section covering MapNpc fields, interact flow, rematch rule, and new enemy resources.
