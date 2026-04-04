class_name MapChest
extends Resource

## A tile-positioned chest inside a named map.
## Runtime state (opened) is tracked by SaveManager, not stored here.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## Card IDs awarded when this chest is opened.
@export var card_ids: PackedStringArray = PackedStringArray()
