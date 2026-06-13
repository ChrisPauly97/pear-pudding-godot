## WorldEvents.gd — registers all living-world events with WorldEventManager.
##
## Call register_all(world_scene) from WorldScene._ready() when entering the
## infinite world. Closures capture world_scene so spawn/cleanup have access to
## player position, entity root, and NPC registry.
##
## WorldEventManager and GameBus are accessed via get_node_or_null() to avoid
## compile-time identifier resolution failures during GDScript's reload phase.

const _WorldEventManager = preload("res://autoloads/WorldEventManager.gd")
const _EnemyScene    = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _MerchantScene = preload("res://scenes/world/entities/MerchantNPC.tscn")
const _WorldItemScene = preload("res://scenes/world/entities/WorldItem.tscn")
const _CardRegistry   = preload("res://autoloads/CardRegistry.gd")
const _CardDropUtil   = preload("res://game_logic/CardDropUtil.gd")

# ── Roaming boss ──────────────────────────────────────────────────────────────
const _BOSS_ID: String = "roaming_boss"
const _BOSS_ENEMY_TYPE: String = "roaming_terror"
const _BOSS_MIN_INTERVAL: float = 900.0    # 15 min of overworld play
const _BOSS_MAX_INTERVAL: float = 1500.0   # 25 min

# ── Traveling merchant ────────────────────────────────────────────────────────
const _MERCHANT_ID: String = "traveling_merchant"
const _MERCHANT_MIN_INTERVAL: float = 600.0   # 10 min
const _MERCHANT_MAX_INTERVAL: float = 1200.0  # 20 min
const _MERCHANT_PRICE: int = 30               # premium above town shop (15)

# ── Card shower ───────────────────────────────────────────────────────────────
const _SHOWER_ID: String = "card_shower"
const _SHOWER_MIN_INTERVAL: float = 480.0   # 8 min
const _SHOWER_MAX_INTERVAL: float = 900.0   # 15 min
const _SHOWER_MIN_ITEMS: int = 5
const _SHOWER_MAX_ITEMS: int = 10
const _SHOWER_ITEM_LIFETIME: float = 60.0
# Common-tier cards available in the shower (no legendaries).
const _SHOWER_CARD_POOL: Array[String] = [
	"ghost", "skeleton", "zombie", "ghoul", "mend", "wither", "drain",
	"spark", "ember", "scorch", "char", "flicker", "alight",
	"shadow_bolt", "siphon", "insight", "rally", "restore", "radiance",
	"brittle", "bulwark", "dagger_throw", "blitz_ghoul", "ash",
	"ember_imp", "dusk_wraith", "dusk_seer", "dawn_acolyte", "dawn_healer",
	"void_creeper",
]

# Premium card pool — curated from rarer / more impactful cards in the registry.
const _MERCHANT_CARD_POOL: Array[String] = [
	"void_wyrm", "iron_revenant", "phoenix_rise", "ancient_guardian",
	"dusk_vampire", "soul_harvest", "time_warp", "dark_pact",
	"soul_rend", "shrouded_wraith", "veiled_paladin", "ash_warden",
	"duel_crown", "surge_spirit", "dawn_guardian", "dawn_paladin",
	"blitz_ghoul", "void_creeper",
]


static func register_all(world_scene: Node) -> void:
	var wem: Node = Engine.get_main_loop().get_root().get_node_or_null("WorldEventManager")
	if wem == null:
		return
	wem.call("register_event", _BOSS_ID, _BOSS_MIN_INTERVAL, _BOSS_MAX_INTERVAL,
		func() -> void: _spawn_roaming_boss(world_scene, wem),
		func() -> void: _cleanup_roaming_boss(world_scene, wem))
	wem.call("register_event", _MERCHANT_ID, _MERCHANT_MIN_INTERVAL, _MERCHANT_MAX_INTERVAL,
		func() -> void: _spawn_traveling_merchant(world_scene, wem),
		func() -> void: _cleanup_traveling_merchant(world_scene))
	wem.call("register_event", _SHOWER_ID, _SHOWER_MIN_INTERVAL, _SHOWER_MAX_INTERVAL,
		func() -> void: _spawn_card_shower(world_scene, wem),
		func() -> void: _cleanup_card_shower(world_scene, wem))


# ── Roaming boss ──────────────────────────────────────────────────────────────

static func _spawn_roaming_boss(world_scene: Node, wem: Node) -> void:
	if not is_instance_valid(world_scene):
		wem.call("end_event", _BOSS_ID)
		return
	var player: Node3D = world_scene.call("get_player") as Node3D
	if player == null:
		wem.call("end_event", _BOSS_ID)
		return

	var sm_node: Node = Engine.get_main_loop().get_root().get_node_or_null("SceneManager")
	var world_seed: int = 42
	if sm_node != null:
		var save_mgr: Variant = sm_node.get("save_manager")
		if save_mgr is Node:
			world_seed = int((save_mgr as Node).get("world_seed"))

	var spawn_pos: Vector3 = _WorldEventManager.find_spawn_tile(
		player.position, 20.0, 40.0, world_seed)

	var boss: Node3D = _EnemyScene.instantiate() as Node3D
	boss.call("init_from_data", {
		"id": _BOSS_ID,
		"enemy_type": _BOSS_ENEMY_TYPE,
		"is_roaming_boss": true,
		"alive": true,
	})
	boss.position = spawn_pos

	var entity_root: Node = world_scene.get_node_or_null("Entities")
	if entity_root == null:
		boss.queue_free()
		wem.call("end_event", _BOSS_ID)
		return

	entity_root.add_child(boss)
	world_scene.call("register_enemy", _BOSS_ID, boss)
	wem.call("set_event_position", _BOSS_ID, spawn_pos)
	world_scene.set("_roaming_boss_timer", 0.0)

	var game_bus: Node = Engine.get_main_loop().get_root().get_node_or_null("GameBus")
	if game_bus != null:
		game_bus.emit_signal("hud_message_requested", "A powerful presence approaches...")


static func _cleanup_roaming_boss(world_scene: Node, _wem: Node) -> void:
	if not is_instance_valid(world_scene):
		return
	var enemy_nodes: Variant = world_scene.get("_enemy_nodes")
	if enemy_nodes is Dictionary:
		var nodes: Dictionary = enemy_nodes as Dictionary
		if nodes.has(_BOSS_ID):
			var node: Variant = nodes[_BOSS_ID]
			if node is Node3D and is_instance_valid(node as Node3D):
				(node as Node3D).queue_free()
			nodes.erase(_BOSS_ID)
	world_scene.set("_roaming_boss_timer", 0.0)


# ── Traveling merchant ────────────────────────────────────────────────────────

static func _spawn_traveling_merchant(world_scene: Node, wem: Node) -> void:
	if not is_instance_valid(world_scene):
		wem.call("end_event", _MERCHANT_ID)
		return
	var player: Node3D = world_scene.call("get_player") as Node3D
	if player == null:
		wem.call("end_event", _MERCHANT_ID)
		return

	var sm_node: Node = Engine.get_main_loop().get_root().get_node_or_null("SceneManager")
	var world_seed: int = 42
	if sm_node != null:
		var save_mgr: Variant = sm_node.get("save_manager")
		if save_mgr is Node:
			world_seed = int((save_mgr as Node).get("world_seed"))

	var spawn_pos: Vector3 = _WorldEventManager.find_spawn_tile(
		player.position, 15.0, 30.0, world_seed)

	# Pick 3 cards from the premium pool, seeded by spawn time for stable stock.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Time.get_unix_time_from_system())
	var pool: Array[String] = _MERCHANT_CARD_POOL.duplicate()
	var stock: Array[String] = []
	for _i: int in range(mini(3, pool.size())):
		var idx: int = rng.randi_range(0, pool.size() - 1)
		stock.append(pool[idx])
		pool.remove_at(idx)

	var npc_data: Dictionary = {
		"id": _MERCHANT_ID,
		"npc_type": "traveling_merchant",
		"is_traveling": true,
		"merchant_stock": stock,
		"x": spawn_pos.x,
		"z": spawn_pos.z,
	}

	var merchant: Node3D = _MerchantScene.instantiate() as Node3D
	merchant.call("init_from_data", npc_data)
	merchant.position = spawn_pos

	var entity_root: Node = world_scene.get_node_or_null("Entities")
	if entity_root == null:
		merchant.queue_free()
		wem.call("end_event", _MERCHANT_ID)
		return

	entity_root.add_child(merchant)
	world_scene.call("register_npc", _MERCHANT_ID, merchant, npc_data)
	world_scene.set("_traveling_merchant_timer", 0.0)

	var game_bus: Node = Engine.get_main_loop().get_root().get_node_or_null("GameBus")
	if game_bus != null:
		game_bus.emit_signal("hud_message_requested", "You hear distant wagon wheels...")


static func _cleanup_traveling_merchant(world_scene: Node) -> void:
	if not is_instance_valid(world_scene):
		return
	var npc_nodes: Variant = world_scene.get("_npc_nodes")
	if npc_nodes is Dictionary:
		var nodes: Dictionary = npc_nodes as Dictionary
		if nodes.has(_MERCHANT_ID):
			var node: Variant = nodes[_MERCHANT_ID]
			if node is Node3D and is_instance_valid(node as Node3D):
				(node as Node3D).queue_free()
			nodes.erase(_MERCHANT_ID)
	var npc_data_map: Variant = world_scene.get("_active_npc_data")
	if npc_data_map is Dictionary:
		(npc_data_map as Dictionary).erase(_MERCHANT_ID)
	world_scene.set("_traveling_merchant_timer", 0.0)


# ── Card shower ────────────────────────────────────────────────────────────────

static func _spawn_card_shower(world_scene: Node, wem: Node) -> void:
	if not is_instance_valid(world_scene):
		wem.call("end_event", _SHOWER_ID)
		return
	var player: Node3D = world_scene.call("get_player") as Node3D
	if player == null:
		wem.call("end_event", _SHOWER_ID)
		return

	var entity_root: Node = world_scene.get_node_or_null("Entities")
	if entity_root == null:
		wem.call("end_event", _SHOWER_ID)
		return

	var sm_node: Node = Engine.get_main_loop().get_root().get_node_or_null("SceneManager")
	var world_seed: int = 42
	if sm_node != null:
		var save_mgr: Variant = sm_node.get("save_manager")
		if save_mgr is Node:
			world_seed = int((save_mgr as Node).get("world_seed"))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Time.get_unix_time_from_system())
	var count: int = rng.randi_range(_SHOWER_MIN_ITEMS, _SHOWER_MAX_ITEMS)

	var pool: Array[String] = _SHOWER_CARD_POOL.duplicate()
	var spawned_items: Array[Node3D] = []

	for i: int in range(count):
		var spawn_pos: Vector3 = _WorldEventManager.find_spawn_tile(
			player.position, 2.0, 10.0, world_seed + i * 7)
		# Pick a random card from the pool (with replacement — repetition is fine for scatter)
		var card_id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var stats: Dictionary = _CardDropUtil.roll_stats(card_id, "common")
		var item: Node3D = _WorldItemScene.instantiate() as Node3D
		entity_root.add_child(item)
		item.call("setup", card_id, player.position + Vector3(0, 1.5, 0), spawn_pos,
			"common",
			int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
		# Auto-despawn after _SHOWER_ITEM_LIFETIME seconds if not yet collected
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			var timer := tree.create_timer(_SHOWER_ITEM_LIFETIME)
			timer.timeout.connect(func() -> void:
				if is_instance_valid(item):
					item.queue_free()
			)
		spawned_items.append(item)

	world_scene.set("_card_shower_items", spawned_items)

	_spawn_sparkle_burst(player.position, entity_root)

	var audio_mgr: Node = Engine.get_main_loop().get_root().get_node_or_null("AudioManager")
	if audio_mgr != null:
		audio_mgr.call("play_sfx", "chest_open")

	var game_bus: Node = Engine.get_main_loop().get_root().get_node_or_null("GameBus")
	if game_bus != null:
		game_bus.emit_signal("hud_message_requested", "Cards are falling from the sky!")


static func _cleanup_card_shower(world_scene: Node, _wem: Node) -> void:
	if not is_instance_valid(world_scene):
		return
	var items: Variant = world_scene.get("_card_shower_items")
	if items is Array:
		for item: Variant in (items as Array):
			if item is Node3D and is_instance_valid(item as Node3D):
				(item as Node3D).queue_free()
	world_scene.set("_card_shower_items", [] as Array[Node3D])


static func _spawn_sparkle_burst(origin: Vector3, entity_root: Node) -> void:
	var particles := GPUParticles3D.new()
	particles.position = origin + Vector3(0, 1.0, 0)
	particles.amount = 40
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.22
	pm.color = Color(1.0, 0.95, 0.4, 1.0)
	particles.process_material = pm

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.95, 0.4)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.9, 0.2)
	spark_mat.emission_energy_multiplier = 3.0
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.15, 0.15)
	var mi := MeshInstance3D.new()
	mi.mesh = spark_mesh
	mi.material_override = spark_mat
	particles.draw_pass_1 = spark_mesh

	entity_root.add_child(particles)

	# Auto-free the particles node after they finish playing
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var cleanup_timer := tree.create_timer(2.0)
		cleanup_timer.timeout.connect(func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
		)
