class_name MapNpc
extends Resource

## A tile-positioned NPC inside a named map.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## What this NPC says when interacted with (before flag is set, or always if no flag).
@export var dialogue: String = "..."
## NPC variant: "" = default villager, "merchant" = merchant shop, "duelist" = wager duel.
@export var npc_type: String = ""
## Story flag key. If set, dialogue shows before the flag; after_dialogue shows after.
@export var flag_key: String = ""
## Dialogue shown after flag_key has been set in SaveManager.
@export var after_dialogue: String = ""
## For duelist NPCs: the EnemyRegistry type ID used in the duel battle.
@export var duelist_enemy_id: String = ""
## For duelist NPCs: the coin wager amount.
@export var wager_coins: int = 0
## Champion gate: entity_ids that must appear in SaveManager.defeated_duelists before this NPC will accept a duel.
@export var required_duelist_ids: PackedStringArray = []
## One-time legendary card awarded to the player on first defeat (champion NPCs only).
@export var champion_reward_card: String = ""
## Co-op group dialogue (GID-098): shown instead of `dialogue` when ≥2 players
## are present on the same map. Leave blank to always use the solo dialogue.
@export var dialogue_group: String = ""
