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
## Stable id for the session this device hosts (GID-095). Generated once so
## re-hosting reuses the same `user://sessions/<id>.json` file. Distinct from the
## per-player `token`: the token identifies the *player*, this identifies the *world*.
var _host_session_id: String = ""
## Recent servers this device has joined (GID-095 / TID-347), most-recent first.
## Each entry: {address, port, label, last_session_id, last_joined}.
var _recent_servers: Array = []
var _loaded: bool = false

const _MAX_RECENT_SERVERS: int = 6


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


## Stable id of the session this device hosts (GID-095). Generated + persisted on
## first use so re-hosting reuses the same session file. Never shown to players.
func get_host_session_id() -> String:
	_ensure_loaded()
	if _host_session_id == "":
		_host_session_id = _generate_token()
		_save()
	return _host_session_id


# ---------------------------------------------------------------------------
# Recent servers (GID-095 / TID-347) — one-tap rejoin of a server you were in.
# ---------------------------------------------------------------------------

## Remember a server this device just joined. Dedupes by address:port (an existing
## entry is moved to the front with refreshed metadata), keeps the most recent
## _MAX_RECENT_SERVERS, and persists. `last_session_id` is optional metadata.
func add_recent_server(address: String, port: int, label: String, session_id: String = "") -> void:
	_ensure_loaded()
	if address.strip_edges() == "":
		return
	var key: String = "%s:%d" % [address, port]
	var kept: Array = []
	for e: Variant in _recent_servers:
		if not e is Dictionary:
			continue
		var ed: Dictionary = e
		if "%s:%d" % [str(ed.get("address", "")), int(ed.get("port", 0))] != key:
			kept.append(ed)
	kept.push_front({
		"address": address,
		"port": port,
		"label": label if label.strip_edges() != "" else address,
		"last_session_id": session_id,
		"last_joined": Time.get_datetime_string_from_system(false, true),
	})
	if kept.size() > _MAX_RECENT_SERVERS:
		kept.resize(_MAX_RECENT_SERVERS)
	_recent_servers = kept
	_save()


## The recent-servers list, most-recent first (a copy — mutate via add_recent_server).
func get_recent_servers() -> Array:
	_ensure_loaded()
	return _recent_servers.duplicate(true)


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
	_host_session_id = str(d.get("host_session_id", ""))
	var rs: Variant = d.get("recent_servers", [])
	_recent_servers = rs if rs is Array else []
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
		"host_session_id": _host_session_id,
		"recent_servers": _recent_servers,
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
