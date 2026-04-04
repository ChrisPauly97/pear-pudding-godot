class_name MapTrigger
extends Resource

## A tile-positioned scripted trigger inside a named map.
## When the player steps on this tile, event_id is emitted via GameBus.
## Designed for cutscenes, ambushes, or quest checkpoints.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## Event identifier emitted on GameBus when the trigger fires.
@export var event_id: String = ""
## Story flag required for this trigger to fire. Empty = always active.
@export var flag_key: String = ""
## If true, the trigger fires only once per save (tracked by SaveManager).
@export var once: bool = true
