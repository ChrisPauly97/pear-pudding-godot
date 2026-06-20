class_name CardData
extends Resource

@export var id: String = ""
@export var card_name: String = ""
@export var cost: int = 0
@export var attack: int = 0
@export var health: int = 0
@export var card_class: String = "minion"
@export var description: String = ""
@export var color: Color = Color.WHITE
@export var magic_type: String = ""
@export var magic_branch: String = ""
@export var spell_effect: String = ""
@export var spell_power: int = 0
@export var auto_resolve: bool = false
@export var emergence_effect: String = ""
@export var emergence_power: int = 0
@export var keywords: PackedStringArray = PackedStringArray()
@export var can_craft: bool = true
@export var is_unique: bool = false

# Dual-face support (GID-062). When is_dual_face == true, the base fields above
# represent the Light face; dark_* fields below define the Dark face.
# All dark_* fields are ignored when is_dual_face == false.
@export var is_dual_face: bool = false
@export var dark_card_name: String = ""
@export var dark_cost: int = 0
@export var dark_attack: int = 0
@export var dark_health: int = 0
@export var dark_card_class: String = ""
@export var dark_description: String = ""
@export var dark_color: Color = Color.WHITE
@export var dark_magic_type: String = "dark"
@export var dark_spell_effect: String = ""
@export var dark_spell_power: int = 0
@export var dark_emergence_effect: String = ""
@export var dark_emergence_power: int = 0
@export var dark_keywords: PackedStringArray = PackedStringArray()

## Converts to the Dictionary format that CardInstance._init() and callers expect.
## face: "light" (default) or "dark". Dark fields only used when is_dual_face == true.
func to_template_dict(face: String = "light") -> Dictionary:
	if is_dual_face and face == "dark":
		return {
			"id": id,
			"name": dark_card_name,
			"cost": dark_cost,
			"attack": dark_attack,
			"health": dark_health,
			"card_class": dark_card_class if dark_card_class != "" else card_class,
			"description": dark_description,
			"color": dark_color,
			"magic_type": dark_magic_type,
			"magic_branch": magic_branch,
			"spell_effect": dark_spell_effect,
			"spell_power": dark_spell_power,
			"auto_resolve": auto_resolve,
			"keywords": dark_keywords,
			"emergence_effect": dark_emergence_effect,
			"emergence_power": dark_emergence_power,
			"dual_card_id": id,
			"active_face": "dark",
		}
	return {
		"id": id,
		"name": card_name,
		"cost": cost,
		"attack": attack,
		"health": health,
		"card_class": card_class,
		"description": description,
		"color": color,
		"magic_type": magic_type,
		"magic_branch": magic_branch,
		"spell_effect": spell_effect,
		"spell_power": spell_power,
		"auto_resolve": auto_resolve,
		"keywords": keywords,
		"emergence_effect": emergence_effect,
		"emergence_power": emergence_power,
		"dual_card_id": id if is_dual_face else "",
		"active_face": "light" if is_dual_face else "",
		"is_unique": is_unique,
		"can_craft": can_craft,
	}
