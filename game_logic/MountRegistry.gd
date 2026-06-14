## Static registry of available mounts.
## v1 ships with a single mount (stable_horse).
## Future mounts: add entries to _MOUNTS and a new MountData.tres + preload if .tres is adopted.
extends RefCounted

const _MOUNTS: Dictionary = {
	"stable_horse": {
		"id": "stable_horse",
		"display_name": "Stable Horse",
		"speed_multiplier": 2.0,
		"price": 750,
	},
}

static func get_mount(id: String) -> Dictionary:
	return _MOUNTS.get(id, {})

static func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m: Dictionary in _MOUNTS.values():
		result.append(m)
	return result
