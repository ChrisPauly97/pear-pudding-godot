class_name HeroState
extends RefCounted

var player_id: int
var health: int = 30
var max_health: int = 30
var mana: int = 1
var max_mana: int = 1
var attack: int = 2

func _init(pid: int) -> void:
	player_id = pid

func is_alive() -> bool:
	return health > 0

func take_damage(dmg: int) -> void:
	health = max(0, health - dmg)

func gain_mana_for_turn(turn: int) -> void:
	max_mana = min(10, turn)
	mana = max_mana

func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true
