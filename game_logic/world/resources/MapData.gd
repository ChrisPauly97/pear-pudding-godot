class_name MapData
extends Resource

## Top-level resource describing a named map.
## Tile grid and entity lists are stored here; runtime state (alive, opened, etc.)
## is layered on by WorldMap.load_from_resource() at load time.

## Map identifier — matches the key used in MapRegistry.
@export var map_name: String = ""

## Grid dimensions (always 100×100 for named maps; stored for forward-compat).
@export var width: int = 100
@export var height: int = 100

## Flat tile-type array, row-major: index = tz * width + tx.
## Values: 0=GRASS, 1=WALL, 2=HILL, 3=PATH (see IsoConst).
@export var tiles: PackedInt32Array = PackedInt32Array()

## Flat height array, same indexing as tiles. 0 = default height.
@export var heights: PackedInt32Array = PackedInt32Array()

## Player start position in tile coordinates.
@export var spawn_x: int = 5
@export var spawn_z: int = 5

## Entity arrays — each element is a MapEnemy/MapChest/etc. resource (cast at load time).
@export var enemies: Array[Resource] = []
@export var chests: Array[Resource] = []
@export var doors: Array[Resource] = []
@export var npcs: Array[Resource] = []
@export var scrolls: Array[Resource] = []

## Extensibility: scripted triggers and named rectangular regions.
@export var triggers: Array[Resource] = []
@export var regions: Array[Resource] = []

## Optional per-map metadata.
@export var music_track: String = ""
@export var difficulty: int = 0
@export var author: String = ""
@export var version: int = 1
