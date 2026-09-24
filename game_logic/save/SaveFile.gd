## On-disk format for save slots: slot paths, the HMAC envelope, and the
## write-to-tmp → back up → rename sequence. Static and thread-safe (touches only
## its arguments and the filesystem), so SaveManager's background flush calls
## `write_slot` from a WorkerThreadPool task.
##
## Envelope: `{"hmac": <sha256 hex>, "payload": <tab-indented JSON string>}`.
## Pre-envelope saves are a bare JSON dict and still load unsigned.
extends RefCounted

const _HMAC_SECRET: String = "7e3f91c4b8d20a5e6f19c7b3d4e8f201"


static func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


static func slot_tmp_path(slot: int) -> String:
	return "user://save_slot_%d.json.tmp" % slot


static func slot_bak_path(slot: int) -> String:
	return "user://save_slot_%d.json.bak" % slot


static func hmac(payload: String) -> String:
	var crypto := Crypto.new()
	return crypto.hmac_digest(HashingContext.HASH_SHA256, _HMAC_SECRET.to_utf8_buffer(),
			payload.to_utf8_buffer()).hex_encode()


## Parsed save dict at `path`, or null when the file is missing, unparseable, or
## fails its HMAC check.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var outer: Variant = JSON.parse_string(file.get_as_text())
	if not outer is Dictionary:
		return null
	if not (outer as Dictionary).has("payload"):
		return outer
	var stored_hmac: String = str(outer.get("hmac", ""))
	var payload: String = str(outer.get("payload", ""))
	if stored_hmac != hmac(payload):
		push_warning("SaveManager: integrity check failed for %s" % path)
		return null
	var inner: Variant = JSON.parse_string(payload)
	return inner if inner is Dictionary else null


## Serialises, signs and atomically writes `data` to the slot, keeping the
## previous file as the `.bak` that load falls back to. False if the tmp file
## can't be opened.
static func write_slot(data: Dictionary, slot: int) -> bool:
	var save_path: String = slot_path(slot)
	var tmp_path: String = slot_tmp_path(slot)
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp:
		return false
	var inner_json: String = JSON.stringify(data, "\t")
	tmp.store_string(JSON.stringify({"hmac": hmac(inner_json), "payload": inner_json}))
	tmp = null  # flush + close before rename
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, slot_bak_path(slot))
	DirAccess.rename_absolute(tmp_path, save_path)
	return true
