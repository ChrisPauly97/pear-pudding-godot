class_name HeroState
extends RefCounted

const _StatusEffects = preload("res://game_logic/battle/StatusEffects.gd")

var player_id: int
var health: int = 30
var max_health: int = 30
var mana: int = 1
var max_mana: int = 1
var bonus_mana: int = 0  # permanent per-game mana bonus from skills/equipment
## Mana points per card-cost unit: 1 in turn-based fights, RealtimeCombat.MANA_SCALE (100)
## in real time, so regen and level/gear bonuses can move in small steps while a
## 3-cost card still costs 3 × scale. `mana`/`max_mana` are in points; card costs,
## `bonus_mana` and effect values stay in units — convert with gain_mana/drain_mana.
var mana_scale: int = 1
var attack: int = 0
## Leaderless pack (BID-077): a hidden stand-in with no leader to hit. It takes
## no damage and never swings; GameState kills it once its board is empty.
var leaderless: bool = false
## Hero school resistances (GID-181 / TID-751): school → fraction of incoming damage of
## that school soaked (0..CombatTuning.max_player_resist). Filled at battle start by
## BattleModifiers; empty = no resistance. Serialized (co-op / resume).
var school_resist: Dictionary = {}

# Status effects: key = effect_id ("poison","armor","freeze","stun"), value = duration/stacks int
var status_effects: Dictionary = {}

func _init(pid: int) -> void:
	player_id = pid

func is_alive() -> bool:
	return health > 0

# Reduces health by dmg, consuming armor first.
func take_damage(dmg: int) -> void:
	if dmg <= 0 or leaderless:
		return
	dmg = _StatusEffects.absorb_armor(status_effects, dmg)
	health = max(0, health - dmg)

func heal(n: int) -> void:
	health = mini(max_health, health + n)

func gain_mana_for_turn(turn: int) -> void:
	max_mana = mini(10, turn + bonus_mana) * mana_scale
	mana = max_mana

## Adds `units` card-cost units of mana (scaled), capped at max_mana — or at the
## 10-unit hard cap when `allow_overflow` (companion/attuned start-of-battle bonuses).
func gain_mana(units: int, allow_overflow: bool = false) -> void:
	var cap: int = 10 * mana_scale if allow_overflow else max_mana
	mana = mini(mana + units * mana_scale, maxi(cap, mana))

## Removes `units` card-cost units of mana (scaled), never below 0.
func drain_mana(units: int) -> void:
	mana = maxi(0, mana - units * mana_scale)

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

## Stacks on any armor already applied (gear + companion bonuses add up).
func add_armor(amount: int) -> void:
	if amount > 0:
		apply_status("armor", get_status_value("armor") + amount)

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
		"bonus_mana": bonus_mana,
		"mana_scale": mana_scale,
		"attack": attack,
		"status_effects": status_effects.duplicate(),
		"leaderless": leaderless,
		"school_resist": school_resist.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	player_id = int(d.get("player_id", player_id))
	health = int(d.get("health", 30))
	max_health = int(d.get("max_health", 30))
	mana = int(d.get("mana", 1))
	max_mana = int(d.get("max_mana", 1))
	bonus_mana = int(d.get("bonus_mana", 0))
	mana_scale = maxi(1, int(d.get("mana_scale", 1)))
	attack = int(d.get("attack", 0))
	leaderless = bool(d.get("leaderless", false))
	var sr: Variant = d.get("school_resist", {})
	school_resist = (sr as Dictionary).duplicate() if sr is Dictionary else {}
	var se = d.get("status_effects", {})
	status_effects = se if se is Dictionary else {}
