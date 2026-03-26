extends Resource

@export var id: String = ""
@export var card_name: String = ""
@export var cost: int = 0
@export var attack: int = 0
@export var health: int = 0
@export var card_class: String = "minion"
@export var description: String = ""
@export var color: Color = Color.WHITE

## Converts to the Dictionary format that CardInstance.from_template() and
## legacy callers expect.
func to_template_dict() -> Dictionary:
	return {
		"id": id,
		"name": card_name,
		"cost": cost,
		"attack": attack,
		"health": health,
		"card_class": card_class,
		"description": description,
		"color": color,
	}
