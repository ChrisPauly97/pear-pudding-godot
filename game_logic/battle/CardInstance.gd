class_name CardInstance
extends RefCounted

static var _next_id: int = 0

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

var keywords: Array[String] = []
var shroud_active: bool = false  # true until the first hit is absorbed; set false by game logic after absorption

var armor: int = 0
var summoning_sick: bool = true
var attack_count: int = 1
var out_of_play: int = 0  # stun counter (kept for backward compat; synced with status_effects["stun"])

# Status effects: key = effect_id ("poison","armor","freeze","stun"), value = duration/stacks int
var status_effects: Dictionary = {}

func _init(tmpl: Dictionary = {}) -> void:
	if tmpl.is_empty():
		return
	_next_id += 1
	instance_id = "%s_%d" % [tmpl.get("id", "card"), _next_id]
	template_id = tmpl.get("id", "")
	name = tmpl.get("name", "?")
	cost = tmpl.get("cost", 1)
	attack = tmpl.get("attack", 1)
	health = tmpl.get("health", 1)
	max_health = health
	card_class = tmpl.get("card_class", "minion")
	description = tmpl.get("description", "")
	magic_type = tmpl.get("magic_type", "")
	magic_branch = tmpl.get("magic_branch", "")
	spell_effect = tmpl.get("spell_effect", "")
	spell_power = tmpl.get("spell_power", 0)
	auto_resolve = tmpl.get("auto_resolve", false)
	keywords.assign(tmpl.get("keywords", []))
	shroud_active = keywords.has("shroud")

func is_alive() -> bool:
	return health > 0

func can_attack() -> bool:
	return not summoning_sick and attack_count > 0 and out_of_play == 0 and not has_status("freeze")

# Reduces health by dmg, consuming Shroud then armor first.
func take_damage(dmg: int) -> void:
	if dmg <= 0:
		return
	if shroud_active:
		shroud_active = false
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
