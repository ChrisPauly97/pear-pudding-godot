extends Resource

@export var id: String = ""
@export var display_name: String = ""
## Card IDs that make up this enemy's battle deck. Duplicates allowed.
@export var deck: PackedStringArray = PackedStringArray()
## Cards that may be dropped when this enemy is defeated. One is chosen at random.
@export var drop_pool: PackedStringArray = PackedStringArray()
## Coins awarded to the player when this enemy is defeated.
@export var coin_reward: int = 5
