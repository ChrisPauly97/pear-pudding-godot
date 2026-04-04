class_name MapNpc
extends Resource

## A tile-positioned NPC inside a named map.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## What this NPC says when interacted with (before flag is set, or always if no flag).
@export var dialogue: String = "..."
## NPC variant: "" = default villager, "merchant" = merchant shop.
@export var npc_type: String = ""
## Story flag key. If set, dialogue shows before the flag; after_dialogue shows after.
@export var flag_key: String = ""
## Dialogue shown after flag_key has been set in SaveManager.
@export var after_dialogue: String = ""
