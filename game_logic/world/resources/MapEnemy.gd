class_name MapEnemy
extends Resource

## A tile-positioned enemy entity inside a named map.
## This is a *world entity*, not a battle template (see data/EnemyData.gd for that).
## Runtime state (alive, tracking, enemy_deck) is populated at load time.

@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
## Enemy type key — resolved via EnemyRegistry at load time (e.g. "undead_basic").
@export var enemy_type: String = "undead_basic"
