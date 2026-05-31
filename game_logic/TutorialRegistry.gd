extends RefCounted

const _DATA: Dictionary = {}

static func get_entry(popup_id: String) -> Dictionary:
	if _DATA.has(popup_id):
		return _DATA[popup_id] as Dictionary
	return {}
