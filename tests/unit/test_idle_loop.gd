## NPC idle life (GID-152 / TID-650): blink / glance schedule and coverage.
extends "res://tests/framework/test_case.gd"

const IL = preload("res://game_logic/IdleLoopMath.gd")
const SR = preload("res://game_logic/SpriteRegistry.gd")
const IdleLoop = preload("res://scenes/world/entities/IdleLoop.gd")


func test_schedule_alternates_idle_and_a_beat() -> void:
	var blink: Array = IL.next(IL.IDLE, 0.5, 0.9)
	assert_eq(int(blink[0]), IL.BLINK, "idle is followed by a blink")
	assert_almost_eq(float(blink[1]), IL.BLINK_TIME, 0.0001)
	assert_eq(int(IL.next(IL.IDLE, 0.5, 0.1)[0]), IL.GLANCE, "sometimes a glance instead")
	var back: Array = IL.next(IL.BLINK, 0.0, 0.0)
	assert_eq(int(back[0]), IL.IDLE, "then back to idle")
	assert_true(float(back[1]) >= IL.HOLD_MIN and float(IL.next(IL.GLANCE, 1.0, 0.0)[1]) <= IL.HOLD_MAX)


func test_every_npc_sprite_has_idle_life() -> void:
	var texs: Array[Texture2D] = [SR.townsperson_texture(0), SR.townsperson_texture(1), SR.townsperson_texture(2),
			SR.merchant_texture(false), SR.merchant_texture(true), SR.named_npc_texture("hilda_baker")]
	for tex: Texture2D in texs:
		var spr := Sprite3D.new()
		spr.texture = tex
		var loop: Node = IdleLoop.for_sprite(spr, 1)
		assert_true(loop != null, "%s blinks" % tex.resource_path)
		if loop != null:
			loop.free()
		spr.free()


func test_loop_swaps_and_returns_to_idle() -> void:
	var spr := Sprite3D.new()
	var idle: Texture2D = SR.townsperson_texture(0)
	spr.texture = idle
	var loop: IdleLoop = IdleLoop.for_sprite(spr, 7) as IdleLoop
	loop._process(IL.HOLD_MAX + 0.1)
	assert_ne(spr.texture, idle, "blinks or glances after the hold")
	loop._process(IL.GLANCE_TIME + 0.1)
	assert_eq(spr.texture, idle, "and opens its eyes again")
	loop.free()
	spr.free()
