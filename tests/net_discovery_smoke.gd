## Headless loopback UDP smoke test for LAN discovery (GID-090 / TID-327).
##
## Not in the auto-discovered unit suite (needs real sockets + frame polling).
## Run on demand:
##   godot --headless --path . -s tests/net_discovery_smoke.gd
##
## Exit 0 = pass. Proves the discovery request/reply exchange + wire format work
## over real UDP sockets, using NetworkManager's static helpers. Uses unicast to
## 127.0.0.1 (broadcast routing can't be reliably exercised in a sandbox; the
## real client uses 255.255.255.255 — see docs/agent/multiplayer-coop.md).
extends SceneTree

const NM = preload("res://autoloads/NetworkManager.gd")

const _PORT: int = 24568


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_discovery_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	var host := PacketPeerUDP.new()
	var herr: Error = host.bind(_PORT)
	if herr != OK:
		print("  [FAIL] host bind returned %d (loopback sockets may be blocked)" % herr)
		return false

	var client := PacketPeerUDP.new()
	var cerr: Error = client.bind(0)
	if cerr != OK:
		print("  [FAIL] client bind returned %d" % cerr)
		return false
	client.set_dest_address("127.0.0.1", _PORT)
	client.put_packet(NM.build_discovery_query())

	# Host receives the query and replies unicast to the sender.
	var got_query := false
	for _i in range(200):
		while host.get_available_packet_count() > 0:
			var pkt: PackedByteArray = host.get_packet()
			if NM.is_discovery_query(pkt):
				got_query = true
				host.set_dest_address(host.get_packet_ip(), host.get_packet_port())
				host.put_packet(NM.build_discovery_reply("Smoke Host", 24565, "madrian", 1))
		if got_query:
			break
		OS.delay_msec(10)
	if not got_query:
		print("  [FAIL] host did not receive the discovery query")
		return false
	print("  [PASS] host received discovery query")

	# Client receives and parses the reply.
	var d: Dictionary = {}
	for _j in range(200):
		while client.get_available_packet_count() > 0:
			var pkt: PackedByteArray = client.get_packet()
			d = NM.parse_discovery_reply(pkt, client.get_packet_ip())
		if not d.is_empty():
			break
		OS.delay_msec(10)
	if d.is_empty():
		print("  [FAIL] client did not receive a valid reply")
		return false

	if str(d["name"]) == "Smoke Host" and int(d["game_port"]) == 24565:
		print("  [PASS] client received host reply: %s" % str(d))
		return true
	print("  [FAIL] reply mismatch: %s" % str(d))
	return false
