## Device-local multiplayer profile — stable identity token + display name + color.
##
## Stored at user://mp_profile.json, deliberately SEPARATE from the game save
## (save_slot_*.json): co-op can launch cold from the menu without loading a game
## (see SaveManager.ensure_coop_deck), so identity must not depend on save state.
##
## - token: an opaque id generated once on first run; NEVER shown to players; the
##   key GID-095 uses to match a reconnecting player to their saved session character.
## - display_name / color: user-editable in the lobby, shown above remote avatars
##   and in the session roster, and remembered between launches.
extends Node

const _PATH: String = "user://mp_profile.json"
const DEFAULT_NAME: String = "Player"

## Friendly default tints, one picked at random on first run.
const _PALETTE: Array[Color] = [
	Color(0.95, 0.45, 0.45),
	Color(0.45, 0.75, 0.95),
	Color(0.55, 0.85, 0.55),
	Color(0.92, 0.82, 0.45),
	Color(0.80, 0.55, 0.92),
	Color(0.97, 0.67, 0.40),
]

var _token: String = ""
var _name: String = DEFAULT_NAME
var _color: Color = Color.WHITE
var _loaded: bool = false


func _ready() -> void:
	_ensure_loaded()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stable opaque identity token (generated once). Used purely as a persistence key.
func get_token() -> String:
	_ensure_loaded()
	return _token


func get_display_name() -> String:
	_ensure_loaded()
	return _name


## Set + persist the display name. Empty input falls back to the default.
func set_display_name(value: String) -> void:
	_ensure_loaded()
	var trimmed: String = value.strip_edges()
	_name = trimmed if trimmed != "" else DEFAULT_NAME
	_save()


func get_color() -> Color:
	_ensure_loaded()
	return _color


## 6-char RGB hex (no alpha) — convenience for display and serialisation.
func color_hex() -> String:
	_ensure_loaded()
	return _color.to_html(false)


## Set + persist the avatar color.
func set_color(value: Color) -> void:
	_ensure_loaded()
	_color = value
	_save()


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var d: Dictionary = {}
	if FileAccess.file_exists(_PATH):
		var f := FileAccess.open(_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				d = parsed
	_token = str(d.get("token", ""))
	_name = str(d.get("name", DEFAULT_NAME))
	if _name.strip_edges() == "":
		_name = DEFAULT_NAME
	var had_color: bool = d.has("color")
	var color_hex_in: String = str(d.get("color", "ffffff"))
	_color = Color.html(color_hex_in) if Color.html_is_valid(color_hex_in) else Color.WHITE

	# First-run seeding: a stable token and a random default tint, persisted once.
	var dirty: bool = false
	if _token == "":
		_token = _generate_token()
		dirty = true
	if not had_color:
		_color = _PALETTE[randi() % _PALETTE.size()]
		dirty = true
	if dirty:
		_save()


func _save() -> void:
	var f := FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("MpProfile: could not write %s" % _PATH)
		return
	f.store_string(JSON.stringify({
		"token": _token,
		"name": _name,
		"color": _color.to_html(false),
	}, "\t"))


## 16 lowercase-hex characters of randomness — opaque, never parsed for meaning.
func _generate_token() -> String:
	var hex: String = "0123456789abcdef"
	var out: String = ""
	for i in range(16):
		out += hex[randi() % 16]
	return out
