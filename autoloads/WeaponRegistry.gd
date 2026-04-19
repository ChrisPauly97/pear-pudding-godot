const WeaponData = preload("res://data/WeaponData.gd")
const WEAPON_DIR := "res://data/weapons"

static var _weapons: Dictionary = {}  # id -> WeaponData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(WEAPON_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := ResourceLoader.load(WEAPON_DIR + "/" + fname)
			if res is WeaponData:
				var weapon := res as WeaponData
				_weapons[weapon.id] = weapon
		fname = dir.get_next()

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
