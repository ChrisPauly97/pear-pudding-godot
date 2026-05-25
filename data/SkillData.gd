extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## "passive" or "active"
@export var skill_type: String = "passive"
## Passive: "passive_hp", "passive_mana", "passive_atk", "passive_draw"
## Active:  "active_damage_all", "active_heal", "active_draw", "active_mana"
@export var effect_type: String = ""
@export var effect_value: int = 0
@export var prerequisites: Array[String] = []
@export var tree_row: int = 0
@export var tree_col: int = 0
