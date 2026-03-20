class_name ProceduralGen
extends RefCounted

const WorldMap = preload("res://game_logic/world/WorldMap.gd")

static func generate(world_map: WorldMap, seed_val: int = 12345) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	world_map.enemies.clear()
	world_map.chests.clear()

	var card_ids := ["ghost", "skeleton", "zombie", "ghoul"]
	var max_depth := WorldMap.MAP_WIDTH + WorldMap.MAP_HEIGHT - 2
	var enemy_count := 0
	var step: int = max(1, (max_depth - 20) / 8)

	var depth := 10
	while depth < max_depth and enemy_count < 8:
		var tx := rng.randi_range(1, min(WorldMap.MAP_WIDTH - 2, depth))
		var tz := depth - tx
		if tz >= 1 and tz < WorldMap.MAP_HEIGHT - 1 and world_map.tiles[tz][tx] == WorldMap.TILE_GRASS:
			var wx := float(tx) * WorldMap.TILE_SIZE + WorldMap.TILE_SIZE * 0.5
			var wz := float(tz) * WorldMap.TILE_SIZE + WorldMap.TILE_SIZE * 0.5
			world_map.enemies.append({
				"id": "enemy_%d" % enemy_count,
				"x": wx, "z": wz,
				"alive": true, "tracking": true
			})
			enemy_count += 1
		depth += step

	var chest_depths: Array[int] = [max_depth/4, max_depth/2, (max_depth*3)/4, max_depth - 10]
	for i in range(chest_depths.size()):
		var d: int = chest_depths[i] + rng.randi_range(-5, 5)
		d = clamp(d, 5, max_depth - 5)
		var tx := rng.randi_range(1, min(WorldMap.MAP_WIDTH - 2, d))
		var tz: int = d - tx
		if tz >= 1 and tz < WorldMap.MAP_HEIGHT - 1 and world_map.tiles[tz][tx] == WorldMap.TILE_GRASS:
			var wx := float(tx) * WorldMap.TILE_SIZE + WorldMap.TILE_SIZE * 0.5
			var wz := float(tz) * WorldMap.TILE_SIZE + WorldMap.TILE_SIZE * 0.5
			var cid: String = card_ids[i % card_ids.size()]
			world_map.chests.append({
				"id": "chest_%d" % i,
				"x": wx, "z": wz,
				"card_ids": [cid],
				"opened": false
			})
