extends Node

## Test/automation hook. Inert unless PPTCG_AUTOMATION=1 is set in the
## environment, so it never runs in a normal play session or export.
## Opens a localhost TCP JSON command channel for driving the game
## (key presses, mouse clicks, screenshots) from an external script.

const PORT := 8765

var _server: TCPServer
var _client: StreamPeerTCP
var _enabled: bool = false


func _ready() -> void:
	_enabled = OS.get_environment("PPTCG_AUTOMATION") == "1"
	if not _enabled:
		return
	_server = TCPServer.new()
	var err: int = _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error("AutomationBridge: failed to listen on port %d (err %d)" % [PORT, err])
		_enabled = false
		return
	print("AutomationBridge: listening on 127.0.0.1:%d" % PORT)


func _process(_delta: float) -> void:
	if not _enabled:
		return
	if _client == null or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if _server.is_connection_available():
			_client = _server.take_connection()
	if _client == null:
		return
	_client.poll()
	if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var avail: int = _client.get_available_bytes()
	if avail <= 0:
		return
	var result: Array = _client.get_data(avail)
	var raw: PackedByteArray = result[1]
	var text: String = raw.get_string_from_utf8()
	for line in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed != "":
			_handle_command(trimmed)


func _handle_command(line: String) -> void:
	var json := JSON.new()
	if json.parse(line) != OK:
		_reply({"ok": false, "error": "bad json"})
		return
	var data: Dictionary = json.data
	var cmd: String = data.get("cmd", "")
	match cmd:
		"ping":
			_reply({"ok": true, "pong": true})
		"screenshot":
			_cmd_screenshot(data)
		"key":
			_cmd_key(data)
		"click":
			_cmd_click(data)
		"mouse_move":
			_cmd_mouse_move(data)
		_:
			_reply({"ok": false, "error": "unknown cmd: %s" % cmd})


func _reply(payload: Dictionary) -> void:
	if _client != null and _client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_client.put_data((JSON.stringify(payload) + "\n").to_utf8_buffer())


func _cmd_screenshot(data: Dictionary) -> void:
	var path: String = data.get("path", "user://screenshot.png")
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(path)
	_reply({"ok": err == OK, "path": path, "error_code": err})


func _cmd_key(data: Dictionary) -> void:
	var keycode_name: String = data.get("keycode", "")
	var action: String = data.get("action", "press")
	var keycode: Key = OS.find_keycode_from_string(keycode_name)
	if keycode == KEY_NONE:
		_reply({"ok": false, "error": "unrecognized keycode: %s" % keycode_name})
		return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = action != "release"
	Input.parse_input_event(ev)
	_reply({"ok": true})


func _cmd_click(data: Dictionary) -> void:
	var pos := Vector2(data.get("x", 0.0), data.get("y", 0.0))
	var button_name: String = data.get("button", "left")
	var button_index: int = MOUSE_BUTTON_RIGHT if button_name == "right" else MOUSE_BUTTON_LEFT

	var move_ev := InputEventMouseMotion.new()
	move_ev.position = pos
	move_ev.global_position = pos
	Input.parse_input_event(move_ev)

	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = button_index
	down.pressed = true
	Input.parse_input_event(down)

	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = button_index
	up.pressed = false
	Input.parse_input_event(up)

	_reply({"ok": true})


func _cmd_mouse_move(data: Dictionary) -> void:
	var pos := Vector2(data.get("x", 0.0), data.get("y", 0.0))
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	_reply({"ok": true})
