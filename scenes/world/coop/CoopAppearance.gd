## Co-op avatar appearance (GID-137 / TID-561): each peer's equipped gear, so
## remote avatars are drawn by PaperDoll in the gear that peer actually wears.
##
## Wire format: `PaperDoll.encode_gear()` — one item id per visible slot —
## followed by `encode_look()` (skin/hair preset indices, TID-562), sent
## reliably over `NetSync.recv_gear`. Peers without the tail decode as default. A peer sends its gear
##   - alongside every identity packet (CoopSession._send_local_identity), so
##     joiners and late joiners learn it in the existing handshake, and
##   - on every `GameBus.equipment_changed`, which also fires when a session
##     character is adopted (its equipped items replace the solo ones).
## Receivers keep the last gear per peer and apply it when the avatar spawns,
## since gear can arrive before the avatar exists (same lazy order as identity).
##
## A child node of WorldScene registered with NetSync; inert outside a session.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")
const _RemotePlayer = preload("res://scenes/world/entities/RemotePlayer.gd")

var _world: _WorldScene = null
var _remote_gear: Dictionary = {}  # peer id → gear Dictionary (slot → item id)
var _remote_look: Dictionary = {}  # peer id → PaperDoll appearance colours


func _ready() -> void:
	GameBus.equipment_changed.connect(_on_local_equipment_changed)
	NetworkManager.peer_disconnected.connect(forget_peer)
	NetworkManager.session_ended.connect(func() -> void:
		_remote_gear.clear()
		_remote_look.clear())


## Sends our gear to one peer (`target_peer` > 0) or everyone (0).
func send_local_gear(target_peer: int) -> void:
	if _world == null or not _world._coop_active or _world._net_sync == null:
		return
	if not NetworkManager.is_active() or NetworkManager.is_dedicated_server():
		return
	var sm := SceneManager.save_manager
	var payload: Array = _PaperDoll.encode_gear(_PaperDoll.gear_of(sm)) + _PaperDoll.encode_look(sm.hero_appearance)
	if target_peer == 0:
		_world._net_sync.rpc("recv_gear", payload)
	else:
		_world._net_sync.rpc_id(target_peer, "recv_gear", payload)


func _on_local_equipment_changed(_slot: String, _item_id: String) -> void:
	send_local_gear(0)


## Called by NetSync when a peer's gear packet arrives.
func _on_gear_received(sender: int, payload: Array) -> void:
	_remote_gear[sender] = _PaperDoll.decode_gear(payload)
	_remote_look[sender] = _PaperDoll.appearance_from(_PaperDoll.decode_look(payload))
	apply_to_avatar(sender)


## Dresses the peer's RemotePlayer, if it has spawned and its gear is known.
func apply_to_avatar(pid: int) -> void:
	if not _remote_gear.has(pid):
		return
	var rp := _world._valid_node(_world._remote_player_nodes.get(pid)) as _RemotePlayer
	if rp != null:
		var gear: Dictionary = _remote_gear[pid]
		var look: Dictionary = _remote_look.get(pid, {})
		rp.set_gear(gear, look)


func forget_peer(pid: int) -> void:
	_remote_gear.erase(pid)
	_remote_look.erase(pid)

