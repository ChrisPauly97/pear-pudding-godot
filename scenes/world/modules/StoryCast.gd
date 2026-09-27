## Story-driven cast placement (GID-108): Maiteln's travelling presence, the
## Chapter 1 wilderness camp, the Chapter 2 scout ambush and war-camp boss, and
## the three rival (Isfig) encounters. Each spawn is gated on story flags and
## is idempotent, so it is safe on every map load.
##
## The spawned nodes stay on WorldScene (`_maiteln_node`, `_wilderness_camp_node`,
## `_scout_ambush_node`, `_enemy_nodes`): the interaction chains and CoopSession's
## Maiteln sync read them there.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const RivalSystem = preload("res://game_logic/RivalSystem.gd")
const _EnemyScene = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _EnemyNPC = preload("res://scenes/world/entities/EnemyNPC.gd")
const WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _MaitelnFollowerScene = preload("res://scenes/world/entities/MaitelnFollower.tscn")
const _ScoutAmbushScene = preload("res://scenes/world/entities/ScoutAmbush.tscn")
const _WildernessCampScene = preload("res://scenes/world/entities/WildernessCamp.tscn")

## Named story maps where Maiteln always travels with the player. The open world
## only qualifies during the TID-402 camp-beat window (not general sandbox).
const MAITELN_NAMED_MAPS: Array[String] = [
	"madrian", "maykalene", "farsyth_mansion", "blancogov", "blancogov_temple",
]

var _world: _WorldScene = null

# ── Maiteln (GID-108 / TID-403) ──────────────────────────────────────────────

func maiteln_should_be_present() -> bool:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("story_intro_complete") or sm.get_story_flag("chapter1_complete"):
		return false
	if MAITELN_NAMED_MAPS.has(_world.story_place()):
		return true
	# The overworld is where Chapter 1 travels now (GID-138): the stitched towns
	# and the roads between them. Maiteln walks it with you.
	return _world._is_infinite

## Spawns/frees the Maiteln follower to match maiteln_should_be_present().
## Call on map load and whenever a relevant story flag changes mid-session.
func refresh_maiteln_presence() -> void:
	var should_be_present: bool = maiteln_should_be_present()
	if is_instance_valid(_world._maiteln_node):
		if not should_be_present:
			_world._maiteln_node.queue_free()
			_world._maiteln_node = null
		return
	_world._maiteln_node = null
	if not should_be_present or _world._player == null:
		return
	var node := _MaitelnFollowerScene.instantiate() as Node3D
	_world._entity_root.add_child(node)
	if node.has_method("setup"):
		node.call("setup", _world._player, _world)
	# Co-op (GID-108 / TID-408, design rule 4): exactly one Maiteln, position
	# owned by the authority. A non-authority client's copy is a networked
	# puppet — hidden until the first same-map packet arrives (mirrors the
	# RemotePlayer cross-map-ghost fix, TID-352) instead of independently
	# following its own local player.
	if _world._coop_active and not _world.coop_session._coop_world_authority() \
			and node.has_method("set_networked"):
		node.call("set_networked", true)
		node.visible = false
	_world._maiteln_node = node

# ── Open-world story encounters ──────────────────────────────────────────────
# Each stands at a fixed spot on the road the story sends you along
# (RealmLayout.STORY_SITES, GID-138) — so the objective can point at it — from
# the moment its opening flag is set until its completion flag is.

## Places whichever road beats the current flags call for. Idempotent: runs on
## every overworld load and on every story flag change.
func spawn_open_world_beats() -> void:
	if not _world._is_infinite or _world._player == null:
		return
	spawn_open_world_rival()
	spawn_wilderness_camp()
	spawn_scout_ambush()

## First-night wilderness camp (GID-108 / TID-402). Gone for good once
## chapter1_learned_fire is set (the entity frees itself on that transition).
func spawn_wilderness_camp() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_left_madrian") or sm.get_story_flag("chapter1_learned_fire"):
		return
	if is_instance_valid(_world._wilderness_camp_node):
		return
	_world._wilderness_camp_node = _spawn_at_site(_WildernessCampScene, "wilderness_camp")

## Chapter 2 beat 3 scripted ambush (GID-108 / TID-407). One-shot: interacting
## starts the battle, and victory sets chapter2_ambush_survived.
func spawn_scout_ambush() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter2_found_letter") or sm.get_story_flag("chapter2_ambush_survived"):
		return
	if is_instance_valid(_world._scout_ambush_node):
		return
	_world._scout_ambush_node = _spawn_at_site(_ScoutAmbushScene, "scout_ambush")

## Instantiates `scene` on the terrain at RealmLayout story site `site`.
func _spawn_at_site(scene: PackedScene, site: String) -> Node3D:
	var p: Vector3 = RealmLayout.site_pos(site)
	var wx: float = p.x
	var wz: float = p.z
	var node := scene.instantiate() as Node3D
	_world._entity_root.add_child(node)
	node.position = Vector3(wx, _world.get_terrain_height(wx, wz), wz)
	return node

## Chapter 2 beat 6 (GID-108 / TID-407) — DungeonGen has no boss-room concept,
## so the war-camp's boss is injected into the freshly loaded WorldMap's enemy
## list before chunk distribution. Safe on every visit: the spawn pipeline
## (ChunkRenderer.is_enemy_defeated) skips him by id once he's dead, and that
## state lives in SaveManager.defeated_enemies, never in the dungeon's .tres.
##
## Placement heuristic: DungeonGen (DW=80, DH=60) lays rooms left-to-right with
## z centred on DH/2 ± jitter (DungeonGen._gen_sequential_rooms), so tile
## (70, 30) sits in the rightmost, deepest room. Not guaranteed carved floor for
## every seed, but this dungeon's seed is fixed (731906).
func inject_warcamp_boss(wm: WorldMap) -> void:
	if wm == null:
		return
	wm.enemies.append({
		"id": "martarquas_warleader_boss",
		"x": 70.0 * IsoConst.TILE_SIZE,
		"z": 30.0 * IsoConst.TILE_SIZE,
		"alive": true,
		"tracking": false,
		"enemy_type": "martarquas_warleader",
		"enemy_deck": EnemyRegistry.get_deck("martarquas_warleader"),
	})

# ── Rival (Isfig) encounters ─────────────────────────────────────────────────

## Encounters 1 and 3 live on fixed tiles in named maps.
func spawn_named_map_rivals() -> void:
	if _world.world_map == null and _world.current_town == "":
		return
	var sm := SceneManager.save_manager
	var map_name: String = _world.story_place()
	if map_name == "maykalene" and sm.get_story_flag("chapter1_left_madrian") and sm.rival_encounters_won == 0:
		_spawn_rival_on_tile("rival_enc1", Vector2i(50, 40), "rival_isfig_1",
			"You again? Let's see if you're worth the effort, wee warrior.")
	elif map_name == "blancogov_temple" and sm.get_story_flag("chapter1_temple_council") \
			and sm.rival_encounters_won >= 2 and not sm.rival_defeated:
		_spawn_rival_on_tile("rival_enc3", Vector2i(50, 80), "rival_isfig_3",
			"Maiteln warned me you'd come far. Perhaps it's time I stood beside him, not against.")

## Encounter 2 meets the player on the road, between Farsyth's warning and the letter.
func spawn_open_world_rival() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_warned_farsyth") or sm.get_story_flag("chapter1_received_letter"):
		return
	if sm.rival_encounters_won >= 2:
		return
	var rival_type: String = RivalSystem.get_rival_type(sm.rival_encounters_won, sm.level)
	var p: Vector3 = RealmLayout.site_pos("isfig_road")
	_spawn_rival_at("rival_enc2", p.x, p.z, rival_type,
		"Maiteln's sent word of the Martarquas. I aim to warn him you're no mere apprentice.")

## `tile` is local to the story place; a stitched town's is moved into the overworld.
func _spawn_rival_on_tile(rival_id: String, tile: Vector2i, enemy_type: String, dialogue: String) -> void:
	var t: Vector2i = tile
	if _world.current_town != "":
		t = RealmLayout.to_world_tile(_world.current_town, tile)
	_spawn_rival_at(rival_id, float(t.x) * IsoConst.TILE_SIZE, float(t.y) * IsoConst.TILE_SIZE,
		enemy_type, dialogue)

func _spawn_rival_at(rival_id: String, wx: float, wz: float, enemy_type: String, dialogue: String) -> void:
	if _world._enemy_nodes.has(rival_id):
		return
	var node := _EnemyScene.instantiate() as _EnemyNPC
	_world._entity_root.add_child(node)
	node.position = Vector3(wx, _world.get_terrain_height(wx, wz) + 0.5, wz)
	node.init_from_data({
		"id": rival_id,
		"x": wx,
		"z": wz,
		"alive": true,
		"tracking": false,
		"enemy_type": enemy_type,
		"enemy_deck": EnemyRegistry.get_deck(enemy_type),
		"pre_battle_dialogue": dialogue,
	})
	_world._enemy_nodes[rival_id] = node
