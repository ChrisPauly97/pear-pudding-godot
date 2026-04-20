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
var auto_resolve: bool = false

var armor: int = 0
var summoning_sick: bool = true
var attack_count: int = 1
var out_of_play: int = 0  # stun counter (kept for backward compat; synced with status_effects["stun"])

# Status effects: key = effect_id ("poison","armor","freeze","stun"), value = duration/stacks int
var status_effects: Dictionary = {}

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
	c.auto_resolve = tmpl.get("auto_resolve", false)
	return c

func take_damage(dmg: int) -> void:
	health = maxi(0, health - maxi(0, dmg - armor))

func is_alive() -> bool:
	return health > 0

func can_attack() -> bool:
	return not summoning_sick and attack_count > 0 and out_of_play == 0 and not has_status("freeze")

# Reduces health by dmg, consuming armor first.
func take_damage(dmg: int) -> void:
	if dmg <= 0:
		return
	if has_status("armor"):
		var av: int = get_status_value("armor")
		var absorbed: int = mini(av, dmg)
		dmg -= absorbed
		var remaining: int = av - absorbed
		if remaining <= 0:
			clear_status("armor")
		else:
			status_effects["armor"] = remaining
	health = max(0, health - dmg)

func start_turn() -> void:
	attack_count = 1
	summoning_sick = false
	if out_of_play > 0:
		out_of_play -= 1
		# Sync stun dict to match out_of_play
		if out_of_play <= 0:
			status_effects.erase("stun")
		else:
			status_effects["stun"] = out_of_play

# ---------------------------------------------------------------------------
# Status effect helpers
# ---------------------------------------------------------------------------

func apply_status(effect_id: String, value: int) -> void:
	status_effects[effect_id] = value
	# Bridge stun to out_of_play so can_attack() works without dict checks
	if effect_id == "stun":
		out_of_play = value

func has_status(effect_id: String) -> bool:
	return status_effects.has(effect_id)

func get_status_value(effect_id: String) -> int:
	if not status_effects.has(effect_id):
		return 0
	return int(status_effects[effect_id])

func clear_status(effect_id: String) -> void:
	status_effects.erase(effect_id)
	if effect_id == "stun":
		out_of_play = 0

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
