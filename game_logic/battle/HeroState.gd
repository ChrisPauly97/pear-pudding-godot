class_name HeroState
extends RefCounted

var player_id: int
var health: int = 30
var max_health: int = 30
var mana: int = 1
var max_mana: int = 1
var attack: int = 0

# Status effects: key = effect_id ("poison","armor","freeze","stun"), value = duration/stacks int
var status_effects: Dictionary = {}

func _init(pid: int) -> void:
	player_id = pid

func is_alive() -> bool:
	return health > 0

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

func gain_mana_for_turn(turn: int) -> void:
	max_mana = min(10, turn)
	mana = max_mana

func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true

# ---------------------------------------------------------------------------
# Status effect helpers
# ---------------------------------------------------------------------------

func apply_status(effect_id: String, value: int) -> void:
	status_effects[effect_id] = value

func has_status(effect_id: String) -> bool:
	return status_effects.has(effect_id)

func get_status_value(effect_id: String) -> int:
	if not status_effects.has(effect_id):
		return 0
	return int(status_effects[effect_id])

func clear_status(effect_id: String) -> void:
	status_effects.erase(effect_id)

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"health": health,
		"max_health": max_health,
		"mana": mana,
		"max_mana": max_mana,
		"attack": attack,
		"status_effects": status_effects.duplicate(),
	}

static func from_dict(d: Dictionary) -> HeroState:
	var h := HeroState.new(int(d.get("player_id", 0)))
	h.health = int(d.get("health", 30))
	h.max_health = int(d.get("max_health", 30))
	h.mana = int(d.get("mana", 1))
	h.max_mana = int(d.get("max_mana", 1))
	h.attack = int(d.get("attack", 0))
	var se = d.get("status_effects", {})
	h.status_effects = se if se is Dictionary else {}
	return h
