## Headless smoke test for Host-button reliability (GID-092 / TID-337).
##
## Before the fix, leave() only nulled the multiplayer peer without closing it, so
## the ENet server socket kept the OS port bound and the next host() failed with
## "address in use". This test hosts, leaves, and re-hosts several times on the same
## port and asserts every host() returns OK — and that a host() with a still-active
## prior session (no explicit leave) also succeeds because host() self-resets.
##
## Run on demand:  godot --headless --path . -s tests/net_rehost_smoke.gd
## Exit code 0 = pass, 1 = fail.
extends SceneTree

const _PORT: int = 24571


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_rehost_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	var nm: Node = root.get_node_or_null("/root/NetworkManager")
	if nm == null:
		print("  [FAIL] NetworkManager autoload not found")
		return false

	# host -> leave -> host, repeated. Every host must return OK on the same port.
	for i in range(3):
		var err1: int = nm.host(_PORT)
		if err1 != OK:
			print("  [FAIL] host() attempt %d (after leave) returned %d" % [i + 1, err1])
			nm.leave()
			return false
		nm.leave()
	print("  [PASS] host -> leave -> host repeated 3x, all OK")

	# Re-host WITHOUT an explicit leave: host() must self-reset the stale session.
	var err_a: int = nm.host(_PORT)
	if err_a != OK:
		print("  [FAIL] first host() returned %d" % err_a)
		nm.leave()
		return false
	var err_b: int = nm.host(_PORT)
	nm.leave()
	if err_b != OK:
		print("  [FAIL] re-host without leave returned %d (port still bound)" % err_b)
		return false
	print("  [PASS] re-host without an explicit leave() succeeds (self-reset)")
	return true
