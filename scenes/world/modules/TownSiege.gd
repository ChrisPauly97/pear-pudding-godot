## Single-player town siege (GID-054): when a siege is active for the map being
## entered, three raiders spawn at the town gate and a banner goes up. Also the
## Chapter 2 beat 4 story trigger (GID-108 / TID-407) that starts the same siege
## at marsax_hold. The synced co-op variant lives in CoopActivities (CoopSiege).
## `_siege_banner` stays on WorldScene because the co-op modules clear it.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _EnemyScene = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _EnemyNPC = preload("res://scenes/world/entities/EnemyNPC.gd")
const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Raider placement around the gate, in tiles (x, z).
const RAIDER_OFFSETS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(2.0, 1.0), Vector2(-2.0, 1.0)]
const _BANNER_TINT := Color(1.0, 0.3, 0.1)

var _world: _WorldScene = null

## Runs on named-map entry: fire the story trigger, then spawn any active siege.
func on_map_entered(p_map_name: String) -> void:
	_check_story_trigger(p_map_name)
	_spawn_if_active(p_map_name)

## Chapter 2 beat 4: the first entry to marsax_hold after the scout ambush
## starts the siege gauntlet. The victory flag (chapter2_siege_won) is set in
## SceneManager._on_battle_won's siege-victory branch.
func _check_story_trigger(p_map_name: String) -> void:
	if p_map_name != "marsax_hold":
		return
	# Co-op (GID-108 / TID-408, rule 6): CoopSiege only syncs madrian, so this
	# story siege is host-resolved — peers walking in don't each start a private
	# one. The victory flag still reaches everyone via shared-flag arbitration.
	if _world._coop_active and not _world.coop_session._coop_world_authority():
		return
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter2_ambush_survived") or sm.get_story_flag("chapter2_siege_won"):
		return
	if sm.town_siege.get_active_siege().is_empty():
		sm.town_siege.start_siege("marsax_hold")

func _spawn_if_active(p_map_name: String) -> void:
	if not _SiegeDefs.is_siege_town(p_map_name):
		return
	var active_siege: Dictionary = SceneManager.save_manager.town_siege.get_active_siege()
	if active_siege.is_empty() or str(active_siege.get("town", "")) != p_map_name:
		return
	_spawn_raiders(p_map_name, int(active_siege.get("stage", 0)))
	_setup_banner(p_map_name)

func _spawn_raiders(p_map_name: String, stage: int) -> void:
	if not _SiegeDefs.TOWN_GATES.has(p_map_name):
		return
	var gate: Vector3 = _SiegeDefs.TOWN_GATES[p_map_name]
	var enemy_type: String = "martarquas_raider_%d" % (stage + 1)
	for i: int in range(RAIDER_OFFSETS.size()):
		var wx: float = gate.x + RAIDER_OFFSETS[i].x
		var wz: float = gate.z + RAIDER_OFFSETS[i].y
		var raider_id: String = "siege_raider_%d_%d" % [stage, i]
		var node: _EnemyNPC = _EnemyScene.instantiate() as _EnemyNPC
		node.position = Vector3(wx, _world.get_terrain_height(wx, wz) + 0.5, wz)
		# BID-041: the enemy type must go through init_from_data — EnemyNPC has
		# no `enemy_type` property, so setting one silently spawned undead_basic.
		node.init_from_data({
			"id": raider_id,
			"x": wx,
			"z": wz,
			"alive": true,
			"tracking": false,
			"enemy_type": enemy_type,
			"enemy_deck": EnemyRegistry.get_deck(enemy_type),
		})
		_world._entity_root.add_child(node)
		_world._enemy_nodes[raider_id] = node

## "<Town> Under Attack!" across the top of the HUD while the siege runs.
func _setup_banner(p_map_name: String) -> void:
	if _world._hud == null:
		return
	var vp: Vector2 = _world.get_viewport().get_visible_rect().size
	var banner := _UiUtil.make_label("%s Under Attack!" % p_map_name.capitalize().replace("_", " "),
		int(vp.y * 0.03), _BANNER_TINT, HORIZONTAL_ALIGNMENT_CENTER, _world._hud)
	banner.position = Vector2((vp.x - vp.y * 0.6) * 0.5, vp.y * 0.005)
	banner.custom_minimum_size = Vector2(vp.y * 0.6, int(vp.y * 0.04))
	_world._siege_banner = banner
