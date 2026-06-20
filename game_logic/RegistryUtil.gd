## Shared helpers for static registries that load a fixed list of preloaded .tres
## resources and key them by an "id" field into a Dictionary.
##
## Usage:
##   static var _items: Dictionary = {}
##   static var _loaded: bool = false
##
##   static func _ensure_loaded() -> void:
##       if _loaded: return
##       _loaded = true
##       _items = RegistryUtil.build_id_dict([_RES_A, _RES_B, ...], "RegistryName")
##
## CardRegistry, EnemyRegistry, and CraftingRegistry have special loading behaviour
## and do not use this utility.

static func build_id_dict(all: Array, registry_name: String) -> Dictionary:
	var out: Dictionary = {}
	for res in all:
		if res == null:
			continue
		var id_val = res.get("id") if res.has_method("get") else null
		var id_str: String = str(id_val) if id_val != null else ""
		if id_str.is_empty():
			push_error("%s: resource has empty 'id', skipped" % registry_name)
			continue
		out[id_str] = res
	if out.is_empty():
		push_error("%s: no resources loaded" % registry_name)
	return out

static func get_all_ids(dict: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for k in dict.keys():
		result.append(str(k))
	return result
