## Gear sources follow the curve (GID-187 / TID-791): what a chest, boss, co-op loot roll or
## shop hands out at a player level. Drops are items the player can wear (`level_req` <= level)
## whose item level is near theirs, so playing normally keeps every slot on the curve; a slot
## more than one band behind (or empty) is filled first ("pity"). `expected_loadout(level)` is the
## same table read as "what a typical player wears" by the balance profiles (TID-778).
##
## Pure: reads the item registry (static data) only.
extends RefCounted

const _GearCurve = preload("res://game_logic/items/GearCurve.gd")
const _WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const _WeaponData = preload("res://data/WeaponData.gd")

const SLOTS: Array[String] = ["weapon", "armor", "helmet", "shoulders", "boots", "offhand", "ring", "trinket"]
## A drop's item level is at most this far below the player's level.
const DROP_BELOW: int = 4
## Shop stock: items up to this far below the player's level.
const SHOP_BELOW: int = 9
## The free starter weapon never drops or sells.
const STARTER_WEAPON: String = "rusty_dagger"

## Every item that can drop or sell (all registered items but the starter weapon).
static func _all_items() -> Array[_WeaponData]:
	var out: Array[_WeaponData] = []
	for id: String in _WeaponRegistry.get_all_ids():
		var w: _WeaponData = _WeaponRegistry.get_weapon(id)
		if w != null and id != STARTER_WEAPON:
			out.append(w)
	return out

## Wearable items of `slot` ("" = any) with item level in [level - below, level]. When the
## window is empty for a slot, that slot's best wearable item stands in, so no slot has a gap.
static func candidates(level: int, slot: String = "", below: int = DROP_BELOW) -> Array[String]:
	var out: Array[String] = []
	for s: String in SLOTS:
		if slot != "" and s != slot:
			continue
		var found: bool = false
		for w: _WeaponData in _all_items():
			if _GearCurve.slot_of(w) == s and w.level_req <= level and w.item_level >= level - below:
				out.append(w.id)
				found = true
		if not found:
			var best: String = best_for(s, level)
			if best != "":
				out.append(best)
	return out

## The best item of `slot` a level-`level` player can wear: highest item level, then rarity
## budget, then id (stable).
static func best_for(slot: String, level: int) -> String:
	var best: _WeaponData = null
	for w: _WeaponData in _all_items():
		if _GearCurve.slot_of(w) != slot or w.level_req > level:
			continue
		if best == null or _better(w, best):
			best = w
	return best.id if best != null else ""

static func _better(a: _WeaponData, b: _WeaponData) -> bool:
	if a.item_level != b.item_level:
		return a.item_level > b.item_level
	var ra: float = float(_GearCurve.RARITY_BUDGET.get(a.rarity, 1.0))
	var rb: float = float(_GearCurve.RARITY_BUDGET.get(b.rarity, 1.0))
	if not is_equal_approx(ra, rb):
		return ra > rb
	return a.id < b.id

## {slot: item id} a typical level-`level` player wears: the best wearable item per slot.
static func expected_loadout(level: int) -> Dictionary:
	var out: Dictionary = {}
	for s: String in SLOTS:
		var id: String = best_for(s, level)
		if id != "":
			out[s] = id
	return out

## Index of a band id in GearCurve.BANDS (-1 unknown).
static func band_index(band_id: String) -> int:
	for i: int in _GearCurve.BANDS.size():
		if str(_GearCurve.BANDS[i][0]) == band_id:
			return i
	return -1

## Slots more than one band behind the player's level band: empty, or wearing an item whose
## band is two or more below. `equipped` = {slot: item id}.
static func behind_slots(level: int, equipped: Dictionary) -> Array[String]:
	var current: int = band_index(str(_GearCurve.band_for_level(level)[0]))
	var out: Array[String] = []
	for s: String in SLOTS:
		var w: _WeaponData = _WeaponRegistry.get_weapon(str(equipped.get(s, "")))
		var have: int = band_index(w.band) if w != null else -1
		if have < current - 1 or (w == null and current >= 1):
			out.append(s)
	return out

## One drop for a level-`level` player: an unowned candidate when there is one (else an owned
## one), from the behind slots first. "" when nothing can drop.
static func pick(level: int, owned: Array, equipped: Dictionary, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	for s: String in behind_slots(level, equipped):
		pool.append_array(candidates(level, s))
	if pool.is_empty():
		pool = candidates(level)
	var fresh: Array[String] = []
	for id: String in pool:
		if not owned.has(id):
			fresh.append(id)
	if not fresh.is_empty():
		pool = fresh
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]

## Shop stock for a level-`level` player in `slot`: wearable items up to one band below.
static func shop_stock(level: int, slot: String) -> Array[String]:
	return candidates(level, slot, SHOP_BELOW)

## Coin price of an item: a stat item's grows with its stat budget; a legacy mechanic item keeps
## its old effect-based price.
static func price(w: _WeaponData) -> int:
	if not w.stats.is_empty():
		return 20 + roundi(_GearCurve.budget(w.item_level, _GearCurve.slot_of(w), w.rarity) * 4.0)
	match w.battle_effect_type:
		"deck_inject":
			return 35 + w.injected_card_count * 5
		"starting_mana":
			return w.battle_effect_value * 30
		"starting_hp":
			return w.battle_effect_value * 5
		"passive_atk":
			return w.battle_effect_value * 25
		"starting_armor":
			return w.battle_effect_value * 15
		"offhand_atk":
			return w.battle_effect_value * 20
	return 50

## The roll a granted item records: its authored rarity and item level, no random affix (the
## random rarity / ilvl / affix rolls retired with hand-made gear, TID-791).
static func authored_roll(item_id: String) -> Dictionary:
	var w: _WeaponData = _WeaponRegistry.get_weapon(item_id)
	if w == null:
		return {"rarity": "common", "ilvl": 1}
	return {"rarity": w.rarity, "ilvl": w.item_level}
