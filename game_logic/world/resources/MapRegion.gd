class_name MapRegion
extends Resource

## A named rectangular zone inside a named map, in tile coordinates.
## Used for safe zones, biome tinting, fog-of-war, music transitions, etc.
## region_type is a free-form string; consumers check it to decide behaviour.

@export var region_id: String = ""
@export var region_name: String = ""
## Semantic type string, e.g. "safe_zone", "fog", "music", "biome".
@export var region_type: String = ""
## Top-left corner in tile coordinates.
@export var tile_x: int = 0
@export var tile_z: int = 0
## Size in tiles.
@export var tile_width: int = 10
@export var tile_height: int = 10
