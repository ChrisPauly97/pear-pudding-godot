## GID-164 / TID-684: deck-builder tiles survive a refresh when unchanged.
extends "res://tests/framework/test_case.gd"

const _TileCache = preload("res://scenes/ui/inventory/TileCache.gd")


func test_reuse_rebuild_and_sweep() -> void:
	var cache := _TileCache.new()
	var grid_a := HFlowContainer.new()
	var t1 := Button.new()
	var t2 := Button.new()
	cache.put("u1", "s1", t1)
	cache.put("u2", "s2", t2)
	grid_a.add_child(t1)
	grid_a.add_child(t2)
	# Refresh: tiles leave the old grid before it is freed.
	cache.detach_all()
	assert_null(t1.get_parent(), "detached from the dying grid")
	grid_a.free()
	assert_true(is_instance_valid(t1), "the grid's free spared the cached tile")
	assert_eq(cache.take("u1", "s1"), t1, "unchanged signature → same node")
	assert_null(cache.take("u2", "changed"), "changed signature → rebuild")
	assert_true(t2.is_queued_for_deletion(), "the stale tile is freed")
	var t3 := Button.new()
	cache.put("u3", "s3", t3)
	cache.sweep()
	assert_false(t1.is_queued_for_deletion(), "shown this round → kept")
	cache.detach_all()
	cache.sweep()
	assert_true(t1.is_queued_for_deletion(), "not shown next round → freed")
	assert_true(t3.is_queued_for_deletion())
	t2.free()
	t1.free()
	t3.free()
