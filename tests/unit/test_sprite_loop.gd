## Landmark loops (GID-152 / TID-648): frames line up with the still, loop, stop.
extends "res://tests/framework/test_case.gd"

const SR = preload("res://game_logic/SpriteRegistry.gd")
const LF = preload("res://game_logic/LandmarkFrames.gd")
const SpriteLoop = preload("res://scenes/world/entities/SpriteLoop.gd")


func test_animated_landmarks_have_aligned_frames() -> void:
	var stills: Array[Texture2D] = [SR.waystone_texture(true), SR.mana_well_texture(),
			SR.puzzle_shrine_texture(), SR.blight_heart_texture()]
	for still: Texture2D in stills:
		var frames: Array[Texture2D] = LF.for_still(still)
		assert_eq(frames.size(), 4, "%s loops" % still.resource_path)
		for f: Texture2D in frames:
			assert_eq(f.get_size(), still.get_size(), "frames line up with the still")
	assert_eq(LF.for_still(SR.waystone_texture(false)).size(), 0, "a dormant waystone stays still")


func test_loop_cycles_then_stops_on_the_still() -> void:
	var holder := Node3D.new()
	var spr := Sprite3D.new()
	spr.texture = SR.mana_well_texture()
	holder.add_child(spr)
	SpriteLoop.ensure(holder, spr)
	SpriteLoop.ensure(holder, spr)
	assert_eq(holder.get_child_count(), 2, "one loop per landmark")
	var loop: SpriteLoop = holder.get_node(SpriteLoop.NODE_NAME) as SpriteLoop
	var seen: Dictionary = {}
	for _i in 12:
		loop._process(1.0 / SpriteLoop.FPS)
		seen[spr.texture] = true
	assert_eq(seen.size(), 4, "all four frames show")
	SpriteLoop.stop(holder)
	assert_eq(spr.texture, LF.for_still(SR.mana_well_texture())[0], "settles on the still frame")
	holder.free()


## TID-649: rest sites burn, the story's wilderness camp only smoulders.
func test_campfire_builds_a_looping_billboard() -> void:
	const CV = preload("res://scenes/world/entities/CampfireVisual.gd")
	for lit: bool in [true, false]:
		var frames: Array[Texture2D] = LF.campfire(lit)
		assert_eq(frames.size(), 6 if lit else 4)
		for f: Texture2D in frames:
			assert_eq(f.get_size(), frames[0].get_size(), "campfire frames share one canvas")
		var holder := Node3D.new()
		var spr: Sprite3D = CV.build(holder, lit)
		assert_eq(spr.texture, frames[0])
		assert_true(holder.has_node(SpriteLoop.NODE_NAME), "the fire animates")
		holder.free()
