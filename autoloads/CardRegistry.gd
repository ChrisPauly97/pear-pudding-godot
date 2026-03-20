extends Node

# Card templates keyed by ID
var _templates: Dictionary = {}

func _ready() -> void:
	_register_defaults()

func _register_defaults() -> void:
	_templates["ghost"] = {
		"id": "ghost",
		"name": "Ghost",
		"cost": 1,
		"attack": 1,
		"health": 2,
		"card_class": "minion",
		"description": "A wispy spirit.",
		"color": Color(0.7, 0.7, 1.0)
	}
	_templates["skeleton"] = {
		"id": "skeleton",
		"name": "Skeleton",
		"cost": 2,
		"attack": 2,
		"health": 2,
		"card_class": "minion",
		"description": "Bones that won't stay down.",
		"color": Color(0.9, 0.9, 0.8)
	}
	_templates["zombie"] = {
		"id": "zombie",
		"name": "Zombie",
		"cost": 3,
		"attack": 2,
		"health": 4,
		"card_class": "minion",
		"description": "Slow but durable.",
		"color": Color(0.4, 0.7, 0.4)
	}
	_templates["ghoul"] = {
		"id": "ghoul",
		"name": "Ghoul",
		"cost": 4,
		"attack": 4,
		"health": 3,
		"card_class": "minion",
		"description": "Fast and hungry.",
		"color": Color(0.8, 0.4, 0.4)
	}

func get_template(id: String) -> Dictionary:
	if _templates.has(id):
		return _templates[id].duplicate()
	return {}

func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for k in _templates.keys():
		result.append(k)
	return result
