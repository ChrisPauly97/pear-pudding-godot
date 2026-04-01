class_name CardInstance
extends RefCounted

var instance_id: String
var template_id: String
var name: String
var cost: int
var attack: int
var health: int
var max_health: int
var card_class: String
var description: String
var magic_type: String
var magic_branch: String
var spell_effect: String
var spell_power: int

var summoning_sick: bool = true
var attack_count: int = 1
var out_of_play: int = 0  # stun counter

static func from_template(tmpl: Dictionary) -> CardInstance:
	var c := CardInstance.new()
	c.instance_id = "%s_%d" % [tmpl.get("id", "card"), Time.get_ticks_msec()]
	c.template_id = tmpl.get("id", "")
	c.name = tmpl.get("name", "?")
	c.cost = tmpl.get("cost", 1)
	c.attack = tmpl.get("attack", 1)
	c.health = tmpl.get("health", 1)
	c.max_health = c.health
	c.card_class = tmpl.get("card_class", "minion")
	c.description = tmpl.get("description", "")
	c.magic_type = tmpl.get("magic_type", "")
	c.magic_branch = tmpl.get("magic_branch", "")
	c.spell_effect = tmpl.get("spell_effect", "")
	c.spell_power = tmpl.get("spell_power", 0)
	return c

func is_alive() -> bool:
	return health > 0

func can_attack() -> bool:
	return not summoning_sick and attack_count > 0 and out_of_play == 0

func start_turn() -> void:
	attack_count = 1
	summoning_sick = false
	if out_of_play > 0:
		out_of_play -= 1

func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"template_id": template_id,
		"name": name,
		"cost": cost,
		"attack": attack,
		"health": health,
		"max_health": max_health,
		"can_attack": can_attack()
	}
