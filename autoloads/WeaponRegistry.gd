const WeaponData = preload("res://data/WeaponData.gd")

const _W_BERSERKER_AXE  := preload("res://data/weapons/berserker_axe.tres")
const _W_BONE_CHARM     := preload("res://data/weapons/bone_charm.tres")
const _W_CHAINMAIL      := preload("res://data/weapons/chainmail.tres")
const _W_DAWN_STAFF     := preload("res://data/weapons/dawn_staff.tres")
const _W_DUSK_BLADE     := preload("res://data/weapons/dusk_blade.tres")
const _W_EMBER_FLASK    := preload("res://data/weapons/ember_flask.tres")
const _W_EMBER_WAND     := preload("res://data/weapons/ember_wand.tres")
const _W_IRON_SHIELD    := preload("res://data/weapons/iron_shield.tres")
const _W_LEATHER_VEST   := preload("res://data/weapons/leather_vest.tres")
const _W_LUCKY_COIN     := preload("res://data/weapons/lucky_coin.tres")
const _W_MANA_CRYSTAL   := preload("res://data/weapons/mana_crystal.tres")
const _W_OBSIDIAN_LOOP  := preload("res://data/weapons/obsidian_loop.tres")
const _W_RING_OF_FOCUS  := preload("res://data/weapons/ring_of_focus.tres")
const _W_RUSTY_DAGGER   := preload("res://data/weapons/rusty_dagger.tres")
const _W_SCHOLAR_BAND   := preload("res://data/weapons/scholar_band.tres")
const _W_WARDED_CLOAK   := preload("res://data/weapons/warded_cloak.tres")

static var _weapons: Dictionary = {}  # id -> WeaponData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var all: Array = [
		_W_BERSERKER_AXE, _W_BONE_CHARM, _W_CHAINMAIL, _W_DAWN_STAFF, _W_DUSK_BLADE,
		_W_EMBER_FLASK, _W_EMBER_WAND, _W_IRON_SHIELD, _W_LEATHER_VEST, _W_LUCKY_COIN,
		_W_MANA_CRYSTAL, _W_OBSIDIAN_LOOP, _W_RING_OF_FOCUS, _W_RUSTY_DAGGER,
		_W_SCHOLAR_BAND, _W_WARDED_CLOAK,
	]
	for res in all:
		var weapon := res as WeaponData
		if weapon == null:
			continue
		if weapon.id != "":
			_weapons[weapon.id] = weapon
		else:
			push_error("WeaponRegistry: a preloaded weapon has empty id, skipped")
	if _weapons.is_empty():
		push_error("WeaponRegistry: no weapons loaded")

## Returns the WeaponData for the given id, or null if not found.
static func get_weapon(id: String) -> WeaponData:
	_ensure_loaded()
	if _weapons.has(id):
		return _weapons[id] as WeaponData
	return null

## Returns true if a weapon with the given id exists.
static func has_weapon(id: String) -> bool:
	_ensure_loaded()
	return _weapons.has(id)

## Returns all known weapon IDs, in no guaranteed order.
static func get_all_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _weapons.keys():
		result.append(str(k))
	return result

## Returns all equipment IDs matching the given slot ("weapon", "armor", "ring", "trinket").
static func get_by_slot(slot: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _weapons.keys():
		var w: WeaponData = _weapons[k] as WeaponData
		if w != null and w.slot == slot:
			result.append(str(k))
	return result
