class_name MapScroll
extends Resource

## A tile-positioned lore scroll inside a named map.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## Scroll registry key — looked up in ScrollRegistry to get the full text.
@export var scroll_id: String = ""
## Story flag required to interact with this scroll. Empty = always interactable.
@export var flag_key: String = ""
