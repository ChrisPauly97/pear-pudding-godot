class_name MapDoor
extends Resource

## A tile-positioned door that transitions the player to another map.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## Name of the destination map. Empty string means pop the map stack (__exit__).
@export var target_map: String = ""
## Optional door ID to teleport to on the target map. Empty = use that map's SPAWN.
@export var target_door_id: String = ""
## Story flag that must be set for this door to be usable. Empty = always open.
@export var flag_key: String = ""
