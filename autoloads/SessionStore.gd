## Authority-side persistent-session store (GID-095 / TID-345).
##
## The **authority** (the host in the listen-server model; a dedicated server in
## GID-097) owns exactly one open `SessionState` and batches dirty writes to
## `user://sessions/<session_id>.json` — one file per session, so a device can host
## several distinct worlds.
##
## This is a COMPLETELY SEPARATE code path from `SaveManager`: it NEVER reads or
## writes `save_slot_*.json` / `save.json`. Single-player persistence is untouched,
## exactly like `SaveManager.ensure_coop_deck`'s no-op-when-cold contract. Clients
## never call `open()`/`_write()` — only the authority persists (single source of
## truth, reusing the GID-091 host-authoritative pattern).
##
## Registered as an autoload so the same interface serves the listen-server host now
## and a non-player dedicated server later (GID-097) without being scene-specific.
extends Node

const _SessionState = preload("res://game_logic/net/SessionState.gd")

const _DIR: String = "user://sessions"
const SAVE_INTERVAL: float = 2.0  # batch disk writes at most every 2 seconds

var _state: _SessionState = null   # null when no session is open
var _active: bool = false
var _dirty: bool = false


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = SAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_flush_if_dirty)
	add_child(timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_EXIT_TREE \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_flush_if_dirty()


# ---------------------------------------------------------------------------
# Public API (authority only)
# ---------------------------------------------------------------------------

func is_open() -> bool:
	return _active and _state != null


## The currently open SessionState, or null. Callers must null-check.
func get_state() -> _SessionState:
	return _state


## Open the session for `session_id`: load its file if present, else create a fresh
## SessionState. Authority only. Safe to call repeatedly (re-hosting reuses the file).
func open(session_id: String, display_name: String = "Session") -> void:
	_ensure_dir()
	_state = null
	var path: String = _path(session_id)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_state = _SessionState.from_dict(parsed)
	if _state == null:
		_state = _SessionState.new()
		_state.session_id = session_id
		_state.display_name = display_name
	# Keep the id authoritative even if a hand-edited file disagrees.
	_state.session_id = session_id
	_active = true
	_dirty = false


## Close the session, flushing pending changes first by default. Call on the
## authority when the session ends (host left / server shutdown).
func close(flush: bool = true) -> void:
	if flush and is_open():
		_write()
	_state = null
	_active = false
	_dirty = false


## Mark the session dirty; the batched timer flushes it within SAVE_INTERVAL.
func mark_dirty() -> void:
	if is_open():
		_dirty = true


## Force an immediate write (used by tests and the close path). No-op when closed.
func flush_now() -> void:
	if is_open():
		_dirty = false
		_write()


# ---------------------------------------------------------------------------
# Member convenience (delegate to the open SessionState + mark dirty)
# ---------------------------------------------------------------------------

## Resume or create the character record for `token`. Returns {} when no session
## is open. Marks dirty (a newly created starter must be persisted).
func ensure_member(token: String, member_name: String = "Player") -> Dictionary:
	if not is_open():
		return {}
	var rec: Dictionary = _state.ensure_member(token, member_name)
	mark_dirty()
	return rec


## Persist-back: replace a member's record and mark dirty. Authority only.
func update_member(token: String, record: Dictionary) -> void:
	if not is_open():
		return
	_state.update_member(token, record)
	mark_dirty()


# ---------------------------------------------------------------------------
# Loot mode convenience (GID-102 / TID-381) — host-only session setting.
# ---------------------------------------------------------------------------

## Current loot distribution mode, or the default when no session is open.
func get_loot_mode() -> String:
	if not is_open():
		return _SessionState.LOOT_MODE_FIRST_OPENER
	return _state.loot_mode


## Host-only toggle. No-op when no session is open.
func set_loot_mode(mode: String) -> void:
	if not is_open():
		return
	_state.loot_mode = mode if mode == _SessionState.LOOT_MODE_NEED_GREED else _SessionState.LOOT_MODE_FIRST_OPENER
	mark_dirty()


# ---------------------------------------------------------------------------
# Persistence internals
# ---------------------------------------------------------------------------

func _flush_if_dirty() -> void:
	if _dirty and is_open():
		_dirty = false
		_write()


func _write() -> void:
	_ensure_dir()
	var path: String = _path(_state.session_id)
	var tmp_path: String = path + ".tmp"
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp == null:
		push_warning("SessionStore: could not write %s" % tmp_path)
		return
	tmp.store_string(JSON.stringify(_state.to_dict(), "\t"))
	tmp = null  # flush + close before rename
	DirAccess.rename_absolute(tmp_path, path)


func _path(session_id: String) -> String:
	return "%s/%s.json" % [_DIR, session_id]


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(_DIR):
		DirAccess.make_dir_recursive_absolute(_DIR)
