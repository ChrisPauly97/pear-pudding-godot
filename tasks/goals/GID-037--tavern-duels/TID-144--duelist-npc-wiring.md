# TID-144: Duelist TownspersonNPC Wiring + Save Tracking

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-143

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
