# TID-145: Regional Champion NPC + Legendary Reward

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-144

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
