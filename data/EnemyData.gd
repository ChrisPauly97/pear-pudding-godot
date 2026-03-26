extends Resource

@export var id: String = ""
@export var display_name: String = ""
## Card IDs that make up this enemy's battle deck. Duplicates allowed.
@export var deck: PackedStringArray = PackedStringArray()
