class_name CardInstance
extends RefCounted

const _StatusEffects = preload("res://game_logic/battle/StatusEffects.gd")

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
var emergence_effect: String = ""
var emergence_power: int = 0

var keywords: Array[String] = []
var shroud_active: bool = false  # true until the first hit is absorbed; set false by game logic after absorption

var collection_uid: String = ""
var rarity: String = "common"  # collection rarity, for the card face (GID-151)
var battle_kills: int = 0

# Last damage this unit took (GID-181 / TID-752): the school and matchup outcome that
# DamageResolver.deal recorded, and a serial that advances on every hit so the battle
# UI can label a hit that dealt 0 (Immune). Serialized so PvP / co-op viewers see it.
var hit_school: String = ""
var hit_outcome: String = ""
var hit_serial: int = 0
var dual_card_id: String = ""
var active_face: String = ""

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
	emergence_effect = str(tmpl.get("emergence_effect", ""))
	emergence_power = int(tmpl.get("emergence_power", 0))
	keywords.assign(tmpl.get("keywords", []))
	shroud_active = keywords.has("shroud")
	dual_card_id = str(tmpl.get("dual_card_id", ""))
	active_face = str(tmpl.get("active_face", ""))

func note_hit(school: String, outcome: String) -> void:
	hit_school = school
	hit_outcome = outcome
	hit_serial += 1

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
	dmg = _StatusEffects.absorb_armor(status_effects, dmg)
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
		"card_class": card_class,
		"description": description,
		"magic_type": magic_type,
		"magic_branch": magic_branch,
		"spell_effect": spell_effect,
		"spell_power": spell_power,
		"auto_resolve": auto_resolve,
		"emergence_effect": emergence_effect,
		"emergence_power": emergence_power,
		"keywords": keywords.duplicate(),
		"shroud_active": shroud_active,
		"dual_card_id": dual_card_id,
		"active_face": active_face,
		"summoning_sick": summoning_sick,
		"attack_count": attack_count,
		"out_of_play": out_of_play,
		"status_effects": status_effects.duplicate(),
		"collection_uid": collection_uid,
		"rarity": rarity,
		"battle_kills": battle_kills,
		"hit_school": hit_school,
		"hit_outcome": hit_outcome,
		"hit_serial": hit_serial,
	}

func from_dict(d: Dictionary) -> void:
	instance_id = str(d.get("instance_id", ""))
	template_id = str(d.get("template_id", ""))
	name = str(d.get("name", "?"))
	cost = int(d.get("cost", 1))
	attack = int(d.get("attack", 1))
	health = int(d.get("health", 1))
	max_health = int(d.get("max_health", 1))
	card_class = str(d.get("card_class", "minion"))
	description = str(d.get("description", ""))
	magic_type = str(d.get("magic_type", ""))
	magic_branch = str(d.get("magic_branch", ""))
	spell_effect = str(d.get("spell_effect", ""))
	spell_power = int(d.get("spell_power", 0))
	auto_resolve = bool(d.get("auto_resolve", false))
	emergence_effect = str(d.get("emergence_effect", ""))
	emergence_power = int(d.get("emergence_power", 0))
	keywords.assign(d.get("keywords", []))
	shroud_active = bool(d.get("shroud_active", false))
	dual_card_id = str(d.get("dual_card_id", ""))
	active_face = str(d.get("active_face", ""))
	# "armor" key tolerated from old saves but field is removed — armor lives in status_effects
	summoning_sick = bool(d.get("summoning_sick", true))
	attack_count = int(d.get("attack_count", 1))
	out_of_play = int(d.get("out_of_play", 0))
	var se = d.get("status_effects", {})
	status_effects = se if se is Dictionary else {}
	collection_uid = str(d.get("collection_uid", ""))
	rarity = str(d.get("rarity", "common"))
	battle_kills = int(d.get("battle_kills", 0))
	hit_school = str(d.get("hit_school", ""))
	hit_outcome = str(d.get("hit_outcome", ""))
	hit_serial = int(d.get("hit_serial", 0))
