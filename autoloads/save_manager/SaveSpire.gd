## Endless Spire run: start, per-floor prep, advance, drafted cards, hero HP and run
## end.
##
## Owned by SaveManager (`SaveManager.spire`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")
const _SpireFloorGen = preload("res://game_logic/spire/SpireFloorGen.gd")
## Every run's base deck. `draft_deck` holds only the picks, so the battle deck
## is always starter + picks (`run_deck()`); a pick never replaces the deck.
const STARTER_DECK: Array[String] = ["ghost", "ghost", "skeleton", "skeleton",
		"zombie", "zombie", "ghoul", "ghoul"]

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager


func is_spire_active() -> bool:
	return bool(_save.spire_run.get("active", false))

func get_spire_run() -> Dictionary:
	return _save.spire_run

## Drops every Spire floor enemy from the permanent defeated_enemies list.
##
## Floor arenas are per-run scenery, not persistent world state, so their kills
## have no business outliving the floor. Called at each run boundary (start,
## floor advance, run end). It is also the repair path for saves written before
## SpireFloorGen.enemy_id_for(): those carry a single shared "spire_enemy" entry
## that suppressed the enemy on every later floor, leaving an empty arena with a
## locked exit door and no way to progress.
func _clear_spire_enemy_defeats() -> void:
	var kept: Array[String] = []
	for eid: String in _save.defeated_enemies:
		if not _SpireFloorGen.is_spire_enemy_id(eid):
			kept.append(eid)
	if kept.size() == _save.defeated_enemies.size():
		return
	_save.defeated_enemies.assign(kept)
	_save._dirty = true

## Called as a Spire floor map loads, before it is distributed into chunks.
##
## A floor whose cleared flag is unset is a fight the player still owes, so its
## enemy must exist — clear any Spire kill that would suppress the spawn.
## Without this a floor can come up empty with its exit door still locked
## (flag_key never set), which is unwinnable and unleavable: the door is the only
## exit and it only opens on the kill. A cleared floor is left alone so standing
## on one you already beat doesn't resurrect it.
func prepare_spire_floor(floor: int, run_seed: int) -> void:
	if _save.get_story_flag(_SpireFloorGen.cleared_flag_for(floor, run_seed)):
		return
	_clear_spire_enemy_defeats()

## The deck the next Spire battle uses: the starter plus every drafted card.
func run_deck() -> Array[String]:
	var deck: Array[String] = STARTER_DECK.duplicate()
	for id: Variant in _save.spire_run.get("draft_deck", []):
		deck.append(str(id))
	return deck

func start_spire_run(seed: int) -> void:
	_clear_spire_enemy_defeats()
	_save.spire_run = {
		"active": true,
		"floor": 1,
		"draft_deck": [],
		"hero_hp": 30,
		"seed": seed,
		"enemies_defeated": 0,
		"cards_drafted": 0,
	}
	_save._dirty = true

func advance_spire_floor() -> void:
	if not is_spire_active():
		return
	# The floor we're leaving is gone for good — drop its kill (and any stale
	# shared-id entry from an older save) so the next arena spawns its enemy.
	_clear_spire_enemy_defeats()
	_save.spire_run["floor"] = int(_save.spire_run.get("floor", 1)) + 1
	_save.spire_run["enemies_defeated"] = int(_save.spire_run.get("enemies_defeated", 0)) + 1
	_save._dirty = true

func add_drafted_card(card_id: String) -> void:
	if not is_spire_active():
		return
	var deck: Array = _save.spire_run.get("draft_deck", [])
	deck.append(card_id)
	_save.spire_run["draft_deck"] = deck
	_save.spire_run["cards_drafted"] = int(_save.spire_run.get("cards_drafted", 0)) + 1
	_save._dirty = true

## Ends the current spire run and returns the final stats dictionary.
## Awards floor*5 coins, updates spire_best_floor, sets achievement flags.
## Returned dict: floors_cleared, enemies_defeated, cards_drafted, seed,
##                coins_earned, is_new_record, best_floor, draft_deck_ids.
func end_spire_run() -> Dictionary:
	_clear_spire_enemy_defeats()
	var floors_cleared: int = int(_save.spire_run.get("floor", 1)) - 1
	var enemies_defeated: int = int(_save.spire_run.get("enemies_defeated", 0))
	var cards_drafted: int = int(_save.spire_run.get("cards_drafted", 0))
	var run_seed: int = int(_save.spire_run.get("seed", 0))
	var draft_deck_ids: Array = _save.spire_run.get("draft_deck", [])

	var coin_reward: int = floors_cleared * 5
	_save.coins += coin_reward
	_save.coins_changed.emit(_save.coins)

	var is_record: bool = floors_cleared > _save.spire_best_floor
	if is_record:
		_save.spire_best_floor = floors_cleared

	var stats: Dictionary = {
		"floors_cleared": floors_cleared,
		"enemies_defeated": enemies_defeated,
		"cards_drafted": cards_drafted,
		"seed": run_seed,
		"coins_earned": coin_reward,
		"is_new_record": is_record,
		"best_floor": _save.spire_best_floor,
		"draft_deck_ids": draft_deck_ids.duplicate(),
	}

	_save.spire_run = {"active": false}
	_save._dirty = true

	if floors_cleared >= 5 and not _save.story_flags.get("spire_reached_floor_5", false):
		_save.set_story_flag("spire_reached_floor_5")
	if floors_cleared >= 10 and not _save.story_flags.get("spire_reached_floor_10", false):
		_save.set_story_flag("spire_reached_floor_10")

	return stats

func set_spire_hero_hp(hp: int) -> void:
	if not is_spire_active():
		return
	_save.spire_run["hero_hp"] = hp
	_save._dirty = true
