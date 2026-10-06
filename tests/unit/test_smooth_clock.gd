## Walkers sample the clock every frame; the lighting clock only steps at 2 Hz,
## so the smooth reading must keep moving between steps (NPC stutter fix).
extends "res://tests/framework/test_case.gd"

const _DayNightCycle = preload("res://scenes/world/DayNightCycle.gd")

func test_smooth_time_moves_between_lighting_steps() -> void:
	var dnc := _DayNightCycle.new()
	dnc.set("_day_duration", 100.0)
	dnc.set_time_of_day(0.25)
	dnc.set("_timer", 0.2)
	assert_eq(dnc.get_time_of_day(), 0.25, "stepped reading unchanged")
	assert_almost_eq(dnc.get_smooth_time_of_day(), 0.252, 0.0001)
	dnc.free()
