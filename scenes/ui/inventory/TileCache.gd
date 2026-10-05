## Reusable bag tiles for the deck builder (GID-164 / TID-684). A refresh used
## to free and rebuild every tile on each keystroke, add or remove; now a tile
## whose inputs (its signature) are unchanged is detached from the old grid and
## dropped into the new one as-is.
extends RefCounted

var _tiles: Dictionary = {}  # uid → [sig: String, node (untyped: may be freed)]
var _used: Dictionary = {}   # uids handed out this refresh


## Pulls every cached tile out of its grid so freeing the grid spares it.
func detach_all() -> void:
	_used.clear()
	for uid: Variant in _tiles:
		var node: Variant = (_tiles[uid] as Array)[1]
		if is_instance_valid(node):
			var c := node as Control
			if c.get_parent() != null:
				c.get_parent().remove_child(c)


## The cached tile for `uid` if built with `sig`, else null (a stale one is freed).
func take(uid: String, sig: String) -> Control:
	var entry: Array = _tiles.get(uid, [])
	if entry.is_empty():
		return null
	var node: Variant = entry[1]
	if not is_instance_valid(node):
		_tiles.erase(uid)
		return null
	if str(entry[0]) != sig:
		(node as Node).queue_free()
		_tiles.erase(uid)
		return null
	_used[uid] = true
	return node as Control


func put(uid: String, sig: String, node: Control) -> void:
	_tiles[uid] = [sig, node]
	_used[uid] = true


## Frees tiles not shown this refresh (sold, moved to the deck, filtered out).
func sweep() -> void:
	for uid: Variant in _tiles.keys():
		if _used.has(uid):
			continue
		var node: Variant = (_tiles[uid] as Array)[1]
		if is_instance_valid(node):
			(node as Node).queue_free()
		_tiles.erase(uid)
