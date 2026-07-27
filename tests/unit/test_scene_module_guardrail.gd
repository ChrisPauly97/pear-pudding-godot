## Guardrail for the WorldScene / BattleScene module split.
##
## The co-op and battle-net modules are child Nodes holding a back-reference to
## the scene that owns them (`_world` / `_battle`). Code moved into them keeps
## working unchanged *except* for two things the move cannot rewrite:
##
##   `add_child(x)`  — used to parent `x` under the scene; now parents it under
##                     the module, which changes an RPC node path or the rect a
##                     Control's anchors resolve against.
##   `self`          — used to mean "the scene"; now means "the module", which is
##                     a plain Node where a Node3D or the RPC target is expected.
##
## Both fail silently — no parse error, no test failure, wrong behaviour only in
## a live session. Three real instances shipped before this guard existed (NetSync
## reparented and dropped out of its own dispatch chain, RemotePlayer handed a
## Node where Node3D was declared, four overlays reparented). So: modules must
## qualify every reparent, and may only pass `self` where the receiver genuinely
## wants the module.
extends "res://tests/framework/test_case.gd"

const _MODULE_DIRS: Array[String] = [
	"res://scenes/world/coop",
	"res://scenes/battle/net",
]

## `self` handed to something that genuinely wants the module, not the scene.
## Each is a reviewed exception; adding one means confirming the receiver really
## does call back into the module rather than into the scene.
const _ALLOWED_SELF_ARGS: Array[String] = [
	"register_handler",   # NetSync/BattleNetSync RPC handler registration
	"world_scene = self", # stash + auction overlays call request_* on CoopSocial
]


func _module_files() -> Array[String]:
	var out: Array[String] = []
	for d: String in _MODULE_DIRS:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".gd"):
				out.append(d + "/" + f)
			f = dir.get_next()
		dir.list_dir_end()
	out.sort()
	return out


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t


func test_module_dirs_are_present() -> void:
	assert_gt(_module_files().size(), 0, "expected to find scene module scripts to scan")


## An unqualified add_child() in a module reparents onto the module itself.
func test_modules_never_reparent_onto_themselves() -> void:
	var offenders: Array[String] = []
	for path: String in _module_files():
		var n: int = 0
		for line: String in _read(path).split("\n"):
			n += 1
			var code: String = line.split("#")[0]
			var stripped: String = code.strip_edges()
			if stripped.begins_with("add_child(") or stripped.begins_with("add_child ("):
				offenders.append("%s:%d %s" % [path, n, stripped])
	assert_true(offenders.is_empty(),
		"Unqualified add_child() in a scene module reparents the node under the module "
		+ "instead of the scene — qualify it as _world.add_child(...) / _battle.add_child(...): %s" % [offenders])


## `self` in a module is the module, not the scene it was extracted from.
func test_modules_only_pass_self_to_reviewed_receivers() -> void:
	var offenders: Array[String] = []
	for path: String in _module_files():
		var n: int = 0
		for line: String in _read(path).split("\n"):
			n += 1
			var code: String = line.split("#")[0]
			if not code.contains("self"):
				continue
			var uses_self: bool = code.contains(", self)") or code.contains("(self)") \
				or code.contains("= self")
			if not uses_self:
				continue
			var allowed: bool = false
			for ok: String in _ALLOWED_SELF_ARGS:
				if code.contains(ok):
					allowed = true
			if not allowed:
				offenders.append("%s:%d %s" % [path, n, code.strip_edges()])
	assert_true(offenders.is_empty(),
		"`self` in a scene module is the module, not the scene — pass _world / _battle "
		+ "unless the receiver really wants the module (then allow-list it here): %s" % [offenders])
