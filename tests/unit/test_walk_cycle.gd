## Enemy walk cycles (GID-152 / TID-645): frame picking and registry coverage.
extends "res://tests/framework/test_case.gd"

const WC = preload("res://game_logic/WalkCycleMath.gd")
const SR = preload("res://game_logic/SpriteRegistry.gd")
const WalkCycle = preload("res://scenes/world/entities/WalkCycle.gd")


func test_idle_while_still_walk_while_moving() -> void:
	var st: Dictionary = {}
	assert_eq(WC.step(st, 0.2, 0.0, 4), -1, "standing still shows idle")
	assert_eq(WC.step(st, 0.01, 2.0, 4), 0, "starts on the first walk frame")
	var seen: Dictionary = {}
	for _i in 20:
		seen[WC.step(st, 1.0 / 30.0, 2.0, 4)] = true
	assert_eq(seen.size(), 4, "cycles through all four frames")


func test_short_pause_keeps_striding() -> void:
	var st: Dictionary = {}
	WC.step(st, 0.1, 2.0, 4)
	assert_ne(WC.step(st, WC.STOP_GRACE * 0.5, 0.0, 4), -1, "one slow frame is not a stop")
	assert_eq(WC.step(st, WC.STOP_GRACE, 0.0, 4), -1, "a real stop returns to idle")


func test_no_frames_means_idle() -> void:
	assert_eq(WC.step({}, 0.1, 5.0, 0), -1)


func test_every_enemy_sprite_has_walk_frames() -> void:
	var walkers: Array[String] = ["undead_basic", "undead_horde", "martarquas_raider_1", "wolf_pack", "bog_hag",
			"imbued_stag", "spectre_wisp"]
	for etype: String in walkers:
		var tex: Texture2D = SR.enemy_texture(etype)
		var frames: Array[Texture2D] = SR.walk_frames(tex)
		assert_eq(frames.size(), 4, "%s walks" % etype)
		for f: Texture2D in frames:
			assert_eq(f.get_height(), tex.get_height(), "%s frames keep the idle height" % etype)
	assert_eq(SR.walk_frames(SR.enemy_texture("mimic")).size(), 0, "the mimic lies in wait")


func test_walk_cycle_swaps_and_restores_texture() -> void:
	var holder := Node3D.new()
	var spr := Sprite3D.new()
	var idle: Texture2D = SR.enemy_texture("wolf_pack")
	spr.texture = idle
	holder.add_child(spr)
	var wc: WalkCycle = WalkCycle.new()
	wc.add_sprite(spr, SR.walk_frames(idle))
	holder.add_child(wc)
	wc._process(0.1)  # first frame only records the position
	holder.position = Vector3(1.0, 0.0, 0.0)
	wc._process(0.1)
	assert_ne(spr.texture, idle, "moving swaps in a walk frame")
	wc._process(0.5)
	assert_eq(spr.texture, idle, "stopping restores the idle frame")
	holder.free()


## TID-651: the horse trots on the idle's canvas, so the saddle never moves.
func test_horse_trots_in_place() -> void:
	var idle: Texture2D = SR.mount_texture()
	var frames: Array[Texture2D] = SR.walk_frames(idle)
	assert_eq(frames.size(), 4, "the horse trots")
	for f: Texture2D in frames:
		assert_eq(f.get_size(), idle.get_size(), "trot frames share the idle canvas")


## GID-164 / TID-676: a cycle with nothing to animate costs no per-frame callback.
func test_trackless_cycle_does_not_process() -> void:
	var empty: Node = WalkCycle.new()
	empty.set_process(true)  # what entering the tree does for a script with _process
	empty.call("_ready")
	assert_false(empty.is_processing(), "no tracks → no _process")
	var spr := Sprite3D.new()
	var frames: Array[Texture2D] = [ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))]
	empty.call("add_sprite", spr, frames)
	assert_true(empty.is_processing(), "adding a track turns it on")
	spr.free()
	empty.free()
