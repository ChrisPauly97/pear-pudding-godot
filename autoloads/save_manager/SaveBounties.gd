## Bounty board: the daily offer refresh, accepting, progress tracking and claiming.
##
## Owned by SaveManager (`SaveManager.bounties`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

var _save: Node


func _init(save_manager: Node) -> void:
	_save = save_manager


func _refresh_bounties() -> void:
	if _save.days_elapsed == _save.bounty_day and not _save.offered_bounties.is_empty():
		return
	if _save.days_elapsed < _save.bounty_day:
		return
	const BountyGen = preload("res://game_logic/BountyGen.gd")
	_save.offered_bounties.clear()
	var daily: Array[Dictionary] = BountyGen.generate_daily(_save.world_seed, _save.days_elapsed)
	for b: Dictionary in daily:
		var entry: Dictionary = b.duplicate()
		entry["offered_at_day"] = _save.days_elapsed
		_save.offered_bounties.append(entry)
	_save.bounty_day = _save.days_elapsed
	_save._dirty = true

## Returns today's offered bounties, refreshing if the day has rolled over.
func get_offered_bounties() -> Array[Dictionary]:
	_refresh_bounties()
	return _save.offered_bounties

## Returns active (accepted, in-progress) bounties.
func get_active_bounties() -> Array[Dictionary]:
	return _save.active_bounties

## Accepts a bounty by id. Moves it from offered_bounties to active_bounties.
## Returns false if bounty not found in offered or 3 bounties are already active.
func accept_bounty(bounty_id: String) -> bool:
	if _save.active_bounties.size() >= 3:
		return false
	var found_idx: int = -1
	for i: int in range(_save.offered_bounties.size()):
		if str(_save.offered_bounties[i].get("id", "")) == bounty_id:
			found_idx = i
			break
	if found_idx < 0:
		return false
	var entry: Dictionary = _save.offered_bounties[found_idx].duplicate()
	entry["accepted_at_day"] = _save.days_elapsed
	entry["progress"] = 0
	entry["claimed"] = false
	_save.active_bounties.append(entry)
	_save.offered_bounties.remove_at(found_idx)
	_save._dirty = true
	return true

## Claims a completed bounty by id. Pays out coins and marks it as claimed.
## Returns the coin reward if successful, or 0 if not found / not yet complete / already claimed.
## Increments progress for all active bounties that match the given type and data.
## bounty_type: "defeat_enemy_type" | "defeat_in_biome" | "open_chests"
## match_data: {"enemy_type": String} | {"biome_name": String} | {}
func increment_bounty_progress(bounty_type: String, match_data: Dictionary) -> void:
	var changed: bool = false
	for i: int in range(_save.active_bounties.size()):
		var b: Dictionary = _save.active_bounties[i]
		if bool(b.get("claimed", false)) or bool(b.get("completed", false)):
			continue
		if str(b.get("type", "")) != bounty_type:
			continue
		var matches: bool = false
		match bounty_type:
			"defeat_enemy_type":
				matches = str(b.get("target", "")) == str(match_data.get("enemy_type", ""))
			"defeat_in_biome":
				matches = str(b.get("target", "")) == str(match_data.get("biome_name", ""))
			"open_chests":
				matches = true
		if not matches:
			continue
		_save.active_bounties[i]["progress"] = int(b.get("progress", 0)) + 1
		var new_progress: int = int(_save.active_bounties[i]["progress"])
		var needed: int = int(b.get("count", 1))
		var bid: String = str(b.get("id", ""))
		if new_progress >= needed:
			_save.active_bounties[i]["completed"] = true
			GameBus.bounty_completed.emit(bid)
		GameBus.bounty_progress_changed.emit(bid, new_progress, needed)
		changed = true
	if changed:
		_save._dirty = true

func claim_bounty(bounty_id: String) -> int:
	for i: int in range(_save.active_bounties.size()):
		var b: Dictionary = _save.active_bounties[i]
		if str(b.get("id", "")) != bounty_id:
			continue
		if bool(b.get("claimed", false)):
			return 0
		var needed: int = int(b.get("count", 0))
		var done: int = int(b.get("progress", 0))
		if done < needed:
			return 0
		_save.active_bounties[i]["claimed"] = true
		var reward: int = int(b.get("reward", 0))
		_save.add_coins(reward)
		_save._dirty = true
		return reward
	return 0
