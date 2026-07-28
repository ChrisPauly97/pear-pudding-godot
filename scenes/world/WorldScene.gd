extends Node3D
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

const WorldEvents     = preload("res://game_logic/WorldEvents.gd")
const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const DungeonGen      = preload("res://game_logic/world/DungeonGen.gd")
const SpireFloorGen   = preload("res://game_logic/spire/SpireFloorGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystickScript = preload("res://scenes/ui/VirtualJoystick.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const ChunkStreamingManager = preload("res://scenes/world/ChunkStreamingManager.gd")
const DungeonSessionUI  = preload("res://scenes/world/DungeonSessionUI.gd")
const WorldHUD          = preload("res://scenes/world/WorldHUD.gd")
const DayNightCycle     = preload("res://scenes/world/DayNightCycle.gd")
const BlightField      = preload("res://game_logic/world/BlightField.gd")
const ChunkRenderer   = preload("res://scenes/world/ChunkRenderer.gd")
const BiomeDef        = preload("res://game_logic/world/BiomeDef.gd")
const TerrainMath     = preload("res://game_logic/TerrainMath.gd")
const Minimap         = preload("res://scenes/world/Minimap.gd")
const MapViewOverlay  = preload("res://scenes/ui/MapViewOverlay.gd")
const WeaponRegistry  = preload("res://autoloads/WeaponRegistry.gd")
const EnemyRegistry   = preload("res://autoloads/EnemyRegistry.gd")
const WeaponData      = preload("res://data/WeaponData.gd")
const MountRegistry      = preload("res://game_logic/MountRegistry.gd")
const TrophyRegistry     = preload("res://game_logic/TrophyRegistry.gd")
const WeatherParticles   = preload("res://scenes/world/WeatherParticles.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")
const Pathfinder  = preload("res://game_logic/Pathfinder.gd")
const RivalSystem = preload("res://game_logic/RivalSystem.gd")
const CantripManager = preload("res://game_logic/world/CantripManager.gd")
const LandmarkNames  = preload("res://game_logic/world/LandmarkNames.gd")

const _TexGrass:     Texture2D = preload("res://assets/textures/pixel_art/grass_pixel.png")
const _TexHillSide:  Texture2D = preload("res://assets/textures/pixel_art/hill_side_pixel.png")
const _TexHillTop:   Texture2D = preload("res://assets/textures/pixel_art/hill_top_pixel.png")
const _TexWallSide:  Texture2D = preload("res://assets/textures/pixel_art/wall_side_pixel.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/pixel_art/wall_top_pixel.png")
const _TexPath:      Texture2D = preload("res://assets/textures/pixel_art/path_pixel.png")

# Preload entity scenes — avoids filesystem hits during spawning
const _OverworldPauseOverlay = preload("res://scenes/ui/OverworldPauseOverlay.gd")
const _PlayerScene       = preload("res://scenes/world/entities/Player.tscn")
const _EnemyScene        = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _WorldItemScene    = preload("res://scenes/world/entities/WorldItem.tscn")
const _StoryScrollScene  = preload("res://scenes/world/entities/StoryScroll.tscn")
const _WildernessCampScene = preload("res://scenes/world/entities/WildernessCamp.tscn")
const _ScoutAmbushScene = preload("res://scenes/world/entities/ScoutAmbush.tscn")
const _MaitelnFollowerScene = preload("res://scenes/world/entities/MaitelnFollower.tscn")
const _PuzzleShrineScene = preload("res://scenes/world/entities/PuzzleShrine.tscn")
const _WaystoneScene     = preload("res://scenes/world/entities/Waystone.tscn")
const _MailboxScene      = preload("res://scenes/world/entities/MailboxNPC.tscn")
const _GardenPlotScript  = preload("res://scenes/world/entities/GardenPlot.gd")
const GardenDefs         = preload("res://game_logic/GardenDefs.gd")
# Party panel (GID-107 / TID-395): consolidated entry point for the always-on
# co-op HUD affordances (Roster, Loot Mode, Stash, Leaderboard, Ghost Duels,
# Team Duel, Dungeon Crawl) that used to each be an individually-positioned button.

# Co-op multiplayer (GID-090)
const _CoopSocial = preload("res://scenes/world/coop/CoopSocial.gd")
const _CoopPvP = preload("res://scenes/world/coop/CoopPvP.gd")
const _CoopActivities = preload("res://scenes/world/coop/CoopActivities.gd")
const _CoopSession = preload("res://scenes/world/coop/CoopSession.gd")
const _NET_BROADCAST_INTERVAL: float = 1.0 / 15.0  # 15 Hz avatar broadcast
# Co-op world-object sync (GID-096)
const _WorldObjectSync   = preload("res://game_logic/net/WorldObjectSync.gd")
const _ENEMY_POS_INTERVAL: float = 1.0 / 5.0  # 5 Hz enemy position broadcast (host)
# Ghost duels (GID-102 / TID-377): async solo battle vs. an AI-piloted snapshot of
# another session member's deck. Zero live networking (no NetSync RPC involved).
# Party loot rolls (GID-102 / TID-381)
# Co-op Endless Spire alternating draft (GID-106 / TID-390)
# Session tournaments (GID-104 / TID-386)
# Downed & rescue in shared dungeons (GID-105 / TID-389)
const _DownedSync        = preload("res://game_logic/net/DownedSync.gd")
# Shared world life (GID-103): synced clock/weather, party night hunts, co-op siege
const _ENV_BROADCAST_INTERVAL: float = 3.0  # host: low-Hz clock/weather broadcast
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

@export var map_name: String = "main"
@export var target_door_id: String = ""

# Computed in _ready from map_name; true for "main" and "infinite", false for named dungeon maps
var _is_infinite: bool = false

# Named-map path
var world_map: WorldMap

# Common
var _player: CharacterBody3D
var _grass: Node3D
var _enemy_nodes: Dictionary = {}   # id -> Node3D
var _chest_nodes: Dictionary = {}   # id -> Node3D
# Co-op multiplayer (GID-090) — guarded by _coop_active; inert in single-player
var _remote_player_nodes: Dictionary = {}  # peer_id -> RemotePlayer Node3D
var _remote_identities: Dictionary = {}    # peer_id -> {token, name, color} (TID-342)
var _net_sync: Node = null
var _coop_active: bool = false
# Maiteln follower position broadcast (GID-108 / TID-408) — authority only, same
# cadence as the local avatar stream.
# Persistent session (GID-095 / TID-346) — character adopted from the authority's
# SessionState; persist-back snapshots batched at _SESSION_SNAPSHOT_INTERVAL.
var _session_token_by_peer: Dictionary = {}  # host: peer_id -> identity token
const _SESSION_SNAPSHOT_INTERVAL: float = 5.0
# Co-op world-object sync (GID-096) — guarded by _coop_active; inert single-player.
var _coop_removed_enemies: Dictionary = {}  # enemy id -> true (engaged/defeated this session)
# Shared story scrolls (GID-108 / TID-408) — mirrors _coop_opened_objects exactly.
var _coop_collected_scrolls: Dictionary = {}  # scroll id -> true (collected by anyone this session)
var _coop_scroll_syncing: bool = false        # reentry guard, mirrors _coop_story_flag_syncing
# Party loot rolls (GID-102 / TID-381) — opt-in need/greed alternative to first-opener-takes.
# Authority only: roll_id -> {chest_id, item, tier, participants: Array[String],
# choices: {token: "need"|"greed"|"pass"}, timer: float}. Empty on clients and when unused.
var _loot_rolls_active: Dictionary = {}
const _LOOT_ROLL_TIMEOUT: float = 15.0
# Client (or host's own local UI): the currently-shown roll prompt, or {} when none.
var _pending_loot_roll: Dictionary = {}
var _loot_roll_panel: Node = null   # transient Need/Greed/Pass panel (CanvasLayer), nil when closed
# Co-op Endless Spire alternating draft (GID-106 / TID-390). Authority only:
# non-empty while a draft round is in flight (a single floor's one-pick round —
# this task's scope; a full floor-by-floor loop is TID-391's job). Shape:
# {floor, options: Array[String], active_picker_token, active_picker_name, timer}.
var _coop_spire_draft_active: Dictionary = {}
const _COOP_SPIRE_DRAFT_TIMEOUT: float = 30.0
var _coop_spire_draft_overlay: Node = null  # transient SpireDraftScene instance, nil when closed
# Any peer (including the authority's own local UI): the currently-shown draft
# prompt's decoded payload, or {} when none. Needed separately from
# _coop_spire_draft_active because that dict only exists on the authority — a
# client picker must resolve card_id -> card_idx from what it was actually shown.
var _pending_coop_spire_draft: Dictionary = {}
# TID-391: the co-op Spire run-ended summary overlay (RunSummaryScene instance in
# coop mode), nil when closed. Instantiated as a child overlay — never
# change_scene_to_node, which would kick the whole co-op session to the main menu.
var _coop_spire_summary_overlay: Node = null
# TID-391: set by _on_coop_spire_battle_ended/_on_coop_spire_run_ended_received,
# which run while this WorldScene is still detached from the tree (the joint
# battle removed it, same as PvP). get_tree() is unsafe to call off-tree, so the
# actual tree-touching work (opening the next floor's draft, or the run summary
# overlay) is deferred to _enter_tree(), once we're reattached and it's safe.
# Co-op story mode (GID-098): true once a map transition is in flight on this
# WorldScene instance so duplicate recv_map_transition packets are ignored.
var _coop_map_transitioning: bool = false
# Rally waystones (GID-105 / TID-388) — guarded by NetworkManager.is_active().
const _RALLY_COOLDOWN: float = 3.0
# Downed & rescue in shared dungeons (GID-105 / TID-389) — guarded by _coop_active
# and current_map.begins_with("dungeon_"); inert everywhere else.
var _coop_downed: bool = false                # true while the LOCAL player is downed
var _dungeon_spawn_pos: Vector3 = Vector3.ZERO  # cached on entry to a "dungeon_*" map
var _downed_banner: Label = null
var _downed_started_at: float = 0.0
# Co-op story mode (GID-098): guard against re-entering the network broadcast
# while processing our own GameBus.story_flag_set echo.
var _initial_ready_done: bool = false  # so _enter_tree re-setup only runs on re-entry
# PvP challenges (GID-091)
# Shared dungeon crawl (GID-102 / TID-380) — host-only trigger, now a Party-panel action.
var _pending_challenge_from: int = -1    # incoming challenge awaiting our response
const _CHALLENGE_RANGE: float = 3.0      # tiles; proximity to show the prompt
# Dedicated-server PvP routing (GID-097 / TID-353) — server tracks pending challenge
var _session_dedicated: bool = false      # client: true when connected to a dedicated server
# Team PvP duels (GID-102 / TID-371): host-only trigger, visible at 4 players (host
# + 3 clients), now a Party-panel action. No accept/decline — keeps team-formation
# UI minimal (see task notes).
# Host-only: remembers the formation of the duel it started so _on_team_battle_ended_coop
# can resolve all 4 participants' tokens for the rating update. Empty when no team
# duel is in flight (the host itself never started one, or it already finished).
# Session tournaments (GID-104 / TID-386): host-run round-robin bracket. Guarded
# end-to-end by _tournament_active so it never touches normal PvP/team-duel state.
# Triggered from the Party panel (GID-115 / TID-433), not a standalone HUD button.
var _tournament_active: bool = false          # true while a bracket is in progress (both host+clients)
var _tournament_bracket: Dictionary = {}      # TournamentSync bracket dict; kept after finish for the panel
var _tournament_peer_ids: Array[int] = []     # host-only: participant idx -> peer id
const TOURNAMENT_ANTE_COINS: int = 25  # flat per-player entry fee; pot = ante * players
# GID-101 — Social & Rewards ──────────────────────────────────────────────────
# TID-365: Emotes & pings
var _ping_mode_active: bool = false      # true while player has ping mode toggled on
# TID-366: Card trading
# TID-367: Spectating
var _pvp_active_peers: Array[int] = []  # host: peer_ids currently in a PvP duel
# TID-368: Wagered duels & champion record
var _pvp_ante_peer0: int = -1           # host peer in the active wager
var _pvp_ante_peer1: int = -1           # client peer in the active wager
# TID-369: Shared party bounties
# TID-374: Party chat
var _chat_input: LineEdit = null           # free-text input (desktop always-visible; mobile behind toggle)
# GID-102 / TID-376: Shared party stash
# GID-102 / TID-378: Async card auction house
const _ChapterEndingOverlay = preload("res://scenes/ui/ChapterEndingOverlay.gd")
var _pvp_ended_pending_broadcast: bool = false  # set in pvp_battle_ended; cleared on _enter_tree
# GID-102 (TID-373): Ranked UI & leaderboard
var _leaderboard_rows: Array = []        # cached SessionState.get_leaderboard() rows
var _leaderboard_overlay: Node = null    # LeaderboardOverlay instance, nil when closed
# GID-102 (TID-379): PvE leaderboards (Endless Spire + co-op boss clears). Distinct
# cache/RPC names from the TID-373 ranked-rating board above — never touches rating.
var _pve_leaderboards: Dictionary = {"spire": [], "coop_clears": [], "night_hunts": []}  # cached snapshot
# GID-103 (TID-382): Synced world clock & weather — host-only rolling/broadcast state.
# Clients mirror the authority's days_elapsed/weather here since they have no
# SessionStore of their own to read from.
# GID-103 (TID-383): Party Night Hunts — deterministic spectral spawns on synced night.
var _coop_night_hunt_kills: int = 0          # resets at dawn
# GID-103 (TID-384): Co-op Town Siege — host-only trigger; escalating waves + joint boss.
# Triggered from the Party panel (GID-115 / TID-433), not a standalone HUD button.
var _coop_siege_active: bool = false
var _coop_siege_wave: int = -1               # -1 = not started; >= WAVE_COUNT = boss phase
var _coop_siege_wave_nodes: Dictionary = {}  # id -> Node3D (current wave only)
# TID-377: Ghost duels — host-only Party-panel action + overlay (SessionStore is
# only ever open on the authority; a client has no local SessionState to list
# opponents from).
# GID-104 (TID-385): Draft duels — sealed-deck PvP. Both peers derive identical
# 1-of-3 pick rounds from one shared seed (DraftDuelGen); only the two finished
# TRANSIENT decks cross the wire. Drafted cards never touch owned_cards /
# SaveManager / SessionState. All state below is inert in single-player.
# Co-op feature modules (child nodes, created in _setup_coop). Each holds a
# `_world` back-reference to this scene and is registered with NetSync as an RPC
# handler target, so the `_on_*` entry points resolve exactly as they did when
# they lived here. See CLAUDE.md "WorldScene co-op modules".
var coop_social: Node = null
var coop_pvp: Node = null
var coop_activities: Node = null
var coop_session: Node = null
var _door_nodes: Dictionary = {}    # id -> Node3D
var _npc_nodes: Dictionary = {}     # id -> Node3D
var _scroll_nodes: Array[Node3D] = []
var _wilderness_camp_node: Node3D = null
var _scout_ambush_node: Node3D = null
var _maiteln_node: Node3D = null
var _shrine_nodes: Array[Node3D] = []
var _siege_raider_nodes: Array[Node3D] = []
var _siege_banner: Label = null
var _waystone_nodes: Dictionary = {}    # id -> Node3D
var _active_waystone_data: Dictionary = {}  # id -> Dictionary
var _mailbox_nodes: Dictionary = {}    # id -> Node3D
var _active_mailbox_data: Dictionary = {}  # id -> Dictionary
var _garden_plot_nodes: Array[Node3D] = []  # ordered by plot_idx
# Guildhall garden (GID-106 / TID-393): SessionStore is authority-only, so this
# cache mirrors _pve_leaderboards' pattern — kept current via request/broadcast
# RPCs, then pushed into each spawned GardenPlot (session_mode = true) node.
var _guildhall_garden_cache: Dictionary = {"plots": [{}, {}, {}], "plants": {}}
var _guildhall_stash_chest_node: Node3D = null
var _tile_meshes: Node3D
var _wall_meshes: Node3D
var _entity_root: Node3D

# Chunk streaming delegated to ChunkStreamingManager (_csm)
var _csm: ChunkStreamingManager = null

var _active_chest_data: Dictionary = {}  # chest_id -> Dictionary
var _active_door_data: Dictionary = {}   # door_id -> Dictionary
var _active_npc_data: Dictionary = {}    # npc_id -> Dictionary
var _digspot_node: Node3D = null         # the one active DigSpot entity (nil if none loaded)
var _burial_mound_nodes: Dictionary = {} # mound_id -> Node3D
var _blight_heart_nodes: Dictionary = {} # heart_id -> Node3D
var _active_landmark_data: Dictionary = {} # landmark_id -> Dictionary
var _mana_well_nodes: Dictionary = {}    # well_id -> Node3D
var _ghost_phase_active: bool = false    # true while ghost-phase tween runs
var _ghost_tween: Tween = null
var _current_biome: int = -1

const _BIOME_MUSIC: Array = [
	"res://assets/audio/music/grasslands.ogg",
	"res://assets/audio/music/forest.ogg",
	"res://assets/audio/music/desert.ogg",
	"res://assets/audio/music/scorched.ogg",
	"res://assets/audio/music/mountains.ogg",
]

# BID-048: dungeon.ogg used to play for every non-infinite named map, including
# peaceful towns (madrian, maykalene, ...). Procedurally generated dungeons/
# spire floors never set MapData.music_track, so they still fall through to
# _DUNGEON_MUSIC below; every hand-authored town/story map instead falls back
# to _TOWN_MUSIC_DEFAULT unless it sets its own `music_track` override.
const _DUNGEON_MUSIC: String = "res://assets/audio/music/dungeon.ogg"
const _TOWN_MUSIC_DEFAULT: String = "res://assets/audio/music/grasslands.ogg"
var _terrain_mat: ShaderMaterial
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0
var _roaming_boss_timer: float = 0.0
var _traveling_merchant_timer: float = 0.0
var _card_shower_items: Array[Node3D] = []

# Nocturnal spawn system (GID-055 Night Hunts)
var _nocturnal_enemies: Dictionary = {}        # spawn_id -> {"node": Node3D, "chunk": Vector2i}
var _nocturnal_spawn_timer: float = 0.0
var _night_cue_played: bool = false
var _night_hunt_tutorial_shown_session: bool = false
var _nocturnal_id_counter: int = 0

# Day/night cycle — delegated to DayNightCycle component
var _world_env: WorldEnvironment
@export var day_duration: float = 600.0   # seconds per full day
var _dnc: DayNightCycle = null

# Weather visuals
var _active_weather_particles: Node3D = null
var _weather_tint: Color = Color(1.0, 1.0, 1.0)
var _weather_tint_target: Color = Color(1.0, 1.0, 1.0)
var _weather_tint_lerp_t: float = 1.0
const _WEATHER_TINT_SPEED: float = 2.0  # tint blends in 0.5s

# Camera smoothing: lerped toward player each _process frame to eliminate
# micro-stutter on high-refresh displays (camera runs at render rate, physics at ~60 Hz).
var _smooth_camera_target: Vector3 = Vector3.ZERO

var WORLD_SEED: int = 42  # overwritten in _ready() for infinite worlds
const INTERACT_INTERVAL: float = 0.15  # check interactions at ~7 Hz, not 60

## The single interaction priority order, highest first. Both the HUD prompt
## (_interact_prompt_label) and the button action (_handle_interact, plus the
## _try_simple_interaction table it delegates to) probe in exactly this order and
## stop at the first hit; test_interact_priority asserts both still do.
##
## Hostile entities sit at the bottom: with anything peaceful in reach the player
## gets that instead, so you can take a door, open a chest or read a scroll with
## an enemy standing next to you rather than being forced into the fight. A
## downed teammate outranks everything — the rescue window is short.
const INTERACT_PRIORITY: PackedStringArray = [
	"downed_peer",
	"door", "chest", "npc", "scroll", "wilderness_camp", "maiteln", "shrine",
	"digspot", "burial_mound", "mana_well", "waystone", "mailbox", "garden_plot",
	"blight_heart", "scout_ambush", "enemy",
]

## HUD prompt verb per NPC type; anything unlisted falls back to "TALK".
const _NPC_PROMPT_LABELS: Dictionary = {
	"merchant": "SHOP", "traveling_merchant": "SHOP",
	"blacksmith": "FORGE", "bounty_board": "BOARD", "stable": "STABLE",
	"duelist": "DUEL", "rest_site": "REST", "bed": "REST",
	"stash_chest": "STASH",
}

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel
@onready var _coin_label: Label = $HUD/CoinLabel
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _moon: DirectionalLight3D = $MoonLight
var _fill_light: DirectionalLight3D

var _pause_overlay: Node = null
var _world_hud: WorldHUD = null
var _dungeon_session_ui: DungeonSessionUI = null
var _minimap: Node
var _map_overlay: Node = null
var _fast_travel_layer: CanvasLayer = null

# Tap-to-move
var _dest_marker: Node3D = null
var _dest_tween: Tween = null
# Set when a tap resolves near an interactable (TID-461); consumed by
# _on_player_path_arrived() to auto-fire _handle_interact() on arrival.
var _pending_tap_interact: bool = false
var _joystick_ref: Node = null
var _tap_start_screen: Vector2 = Vector2.ZERO
var _tap_touch_index: int = -2  # -2 = no tracked tap; -1 reserved for mouse
const _TAP_DRAG_THRESHOLD: float = 30.0  # screen pixels; beyond this is a drag, not a tap
var _drag_last_tile: Vector2i = Vector2i(-9999, -9999)  # throttle drag-steer re-pathing

# Terrain height constants — named-map path uses a wider ramp than chunks

func _setup_environment() -> void:
	var env := Environment.new()
	# Procedural sky with depth gradient — updated each frame by DayNightCycle
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.04, 0.10, 0.32)
	sky_mat.sky_horizon_color    = Color(0.25, 0.50, 0.85)
	sky_mat.ground_horizon_color = Color(0.20, 0.42, 0.70)
	sky_mat.ground_bottom_color  = Color(0.08, 0.06, 0.04)
	sky_mat.sun_angle_max = 55.0
	sky_mat.sun_curve     = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Distance fog for horizon depth
	env.fog_enabled            = true
	env.fog_density            = 0.004
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect         = 0.45
	env.fog_light_color        = Color(0.80, 0.82, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.63, 0.60)
	env.ambient_light_energy = 0.7
	# Filmic tone mapping lifts shadow detail and prevents blown highlights
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Bloom so emissive materials (items, coins) visibly glow.
	# Threshold must stay above the lit-terrain luminance (~1.0 at midday) so
	# only true emissives bloom — 0.5 made the entire sunlit ground glow.
	# glow_bloom must stay 0: any positive value adds glow to pixels BELOW the
	# threshold too, hazing the whole screen regardless of glow_hdr_threshold.
	env.glow_enabled = true
	env.glow_bloom = 0.0
	env.glow_intensity = 1.0
	env.glow_strength = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_luminance_cap = 12.0
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)
	# Fill light: soft neutral bounce from above-opposite, no shadows, lifts black areas
	_fill_light = DirectionalLight3D.new()
	_fill_light.light_color = Color(0.78, 0.77, 0.80)
	_fill_light.light_energy = 0.35
	_fill_light.shadow_enabled = false
	_fill_light.rotation_degrees = Vector3(60.0, 45.0, 0.0)
	add_child(_fill_light)
	_setup_vignette()

func _setup_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 127
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vshader := Shader.new()
	vshader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.0, 1.2));\n\tfloat vig = smoothstep(0.35, 0.75, d) * 0.45;\n\tCOLOR = vec4(0.0, 0.0, 0.0, vig);\n}"
	var vmat := ShaderMaterial.new()
	vmat.shader = vshader
	cr.material = vmat
	cl.add_child(cr)
	add_child(cl)

func _ready() -> void:
	# Before anything else wires signals to them (the GameBus connections below
	# target module methods directly).
	_ensure_coop_modules()
	_setup_environment()
	_sun.shadow_opacity = 0.2
	# At 0.2 opacity the sun shadow is barely perceptible, but it still costs a
	# full extra scene render into the shadow map plus per-pixel shadow taps on
	# every shaded material — too expensive for phone GPUs.
	if OS.has_feature("mobile"):
		_sun.shadow_enabled = false
	_tile_meshes = Node3D.new()
	_tile_meshes.name = "TileGrid"
	add_child(_tile_meshes)
	_wall_meshes = Node3D.new()
	_wall_meshes.name = "WallGrid"
	add_child(_wall_meshes)
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)

	_is_infinite = (map_name == "infinite" or map_name == "main")
	if _is_infinite:
		WORLD_SEED = SceneManager.save_manager.world_seed
		InfiniteWorldGen.forced_start_biome = SceneManager.save_manager.starting_biome
	_terrain_mat = _make_terrain_material(WORLD_SEED)
	_build_grass_blades_node()

	if not _is_infinite:
		_load_named_map()

	# ChunkStreamingManager owns all chunk lifecycle state and thread work.
	# Created after world_map is ready so it receives the correct reference.
	_csm = ChunkStreamingManager.new()
	_csm.name = "ChunkStreamingManager"
	add_child(_csm)
	_csm.setup(WORLD_SEED, _is_infinite, world_map, _terrain_mat, self)
	_csm.player_chunk_changed.connect(_on_player_chunk_changed)
	_csm.chunk_committed.connect(_on_chunk_committed)
	_csm.chunk_unloading.connect(_on_chunk_unloading)

	# Dedicated server: no local player, camera, or HUD. Compute a reference position
	# for the chunk-streaming manager from the map's spawn marker instead.
	var _server_ref_pos: Vector3 = Vector3.ZERO
	if NetworkManager.is_dedicated_server():
		if not _is_infinite and world_map != null and world_map.has_player_spawn():
			_server_ref_pos = Vector3(
				(float(world_map.player_spawn_x) + 0.5) * IsoConst.TILE_SIZE,
				0.0,
				(float(world_map.player_spawn_z) + 0.5) * IsoConst.TILE_SIZE)
		print("[Server] World loaded: %s" % map_name)
	else:
		_spawn_player()

	_populate_world(_server_ref_pos)

	# Re-enter any battle that was interrupted (e.g. app quit mid-fight).
	# Dedicated server has no local player, so this is skipped.
	if not SceneManager.save_manager.pending_battle_enemy_data.is_empty() \
			and not NetworkManager.is_dedicated_server():
		GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)

	if not NetworkManager.is_dedicated_server():
		_build_player_hud()

	# DungeonSessionUI owns dungeon room overlay panels and hero HP tracking.
	if not NetworkManager.is_dedicated_server():
		_dungeon_session_ui = DungeonSessionUI.new()
		_dungeon_session_ui.name = "DungeonSessionUI"
		add_child(_dungeon_session_ui)
		_dungeon_session_ui.setup(_hud, func(text: String) -> void: _world_hud.show_dialogue(text))

	# DayNightCycle owns time-of-day advancement, sun/moon lighting, and sky color.
	_dnc = DayNightCycle.new()
	_dnc.name = "DayNightCycle"
	add_child(_dnc)
	_dnc.setup(_sun, _moon, _world_env, _is_infinite, day_duration,
		SceneManager.save_manager.time_of_day)
	_dnc.day_passed.connect(func() -> void:
		SceneManager.save_manager.increment_day()
		GameBus.blight_changed.emit()
		# GID-103 (TID-382): advance the shared co-op day counter (BID-039) — only the
		# authority owns SessionState.days_elapsed; clients learn the new value from
		# the next env broadcast.
		if _coop_active and NetworkManager.is_host() and SessionStore.is_open():
			var st_day = SessionStore.get_state()
			if st_day != null:
				st_day.days_elapsed += 1
				SessionStore.mark_dirty()
	)
	if _is_infinite:
		_dnc.night_started.connect(func() -> void:
			if not _night_cue_played:
				_night_cue_played = true
				AudioManager.play_sfx("nightfall_ambient")
		)
		_dnc.dawn_arrived.connect(func() -> void:
			_despawn_nocturnal_enemies(true)
			_night_cue_played = false
		)

	if _is_infinite:
		WorldEvents.register_all(self)
		WeatherManager.on_world_entered()
		GameBus.weather_changed.connect(_on_weather_changed)

	if not _is_infinite:
		AudioManager.play_music(_named_map_music_track())
		AudioManager.set_ambience(-1)  # -1 = named map / no biome ambience
		GameBus.entered_named_map.emit(map_name)
		if map_name.begins_with("dungeon_"):
			_dungeon_session_ui.reset_hero_hp()
	else:
		# Counterpart to entered_named_map above (BID-056). Declared since the
		# ambient-audio signals landed but never emitted, so any subscriber saw
		# the player enter named maps and never come back out.
		GameBus.exited_to_world.emit()
	_wire_gamebus_signals()

	if not NetworkManager.is_dedicated_server():
		_refresh_maiteln_presence()

	coop_session._setup_coop()
	# Guildhall furnishings (GID-106 / TID-393): must run after _setup_coop() so
	# _net_sync exists — a client's garden snapshot request needs it. The map
	# itself is only ever entered from an active co-op session (TID-392), so
	# NetworkManager.is_active() here is a defensive guard, not a live gate.
	if map_name == "guildhall" and NetworkManager.is_active():
		_spawn_guildhall_trophies()
		_spawn_guildhall_garden()
		_spawn_guildhall_stash_chest()
	_initial_ready_done = true

# Re-establish co-op when the world is re-attached after a PvP battle detached it
# (SceneManager keeps the WorldScene alive but removes it from the tree, which runs
# _exit_tree → _teardown_coop). On first load _ready handles setup, so this only
# fires on re-entry.

## Every GameBus connection this scene keeps for its whole lifetime.
## Deliberately not in _setup_coop: WorldScene is detached (but still alive)
## during a PvP or joint-PvE battle, so a connection made only while a session
## is active would miss the battle-ended signal that arrives while it is out of
## the tree. The is_connected() guards make re-entry idempotent.

## Resolves `world_map` for a non-infinite map. Procedural dungeon and spire
## floors are generated on first visit and re-read from their saved .tres on
## every later one; everything else is a hand-authored map resource.

## Fills the world once terrain streaming is up: the infinite world gets its
## boundary floor and the first ring of chunks; a named map loads every chunk
## covering its fixed grid and spawns its authored entities. `server_ref_pos`
## stands in for the player position on a dedicated server, which has none.
func _populate_world(server_ref_pos: Vector3) -> void:
	if _is_infinite:
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 2
		floor_body.collision_mask = 0
		var floor_col := CollisionShape3D.new()
		floor_col.shape = WorldBoundaryShape3D.new()
		floor_body.add_child(floor_col)
		add_child(floor_body)
		var _inf_ref: Vector3 = _player.position if _player != null else server_ref_pos
		_csm.build_initial_infinite(_inf_ref)
		if not NetworkManager.is_dedicated_server():
			_spawn_open_world_rival_enc2()
			_spawn_wilderness_camp()
			_spawn_scout_ambush()
			if map_name == "main":
				_spawn_return_portal()
	else:
		# Named map: load all chunks covering the 100×100 tile map synchronously
		var max_cx: int = (WorldMap.MAP_WIDTH + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
		var max_cz: int = (WorldMap.MAP_HEIGHT + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
		var _named_ref: Vector3 = _player.position if _player != null else server_ref_pos
		_csm.build_all_named_map(max_cx, max_cz, _named_ref)
		_spawn_named_map_scrolls()
		_spawn_named_map_shrines()
		_spawn_named_map_waystones()
		_spawn_named_map_mailboxes()
		_spawn_named_map_rivals()
		if map_name == "player_home":
			_spawn_player_home_trophies()
			_spawn_player_home_garden()
		_check_story_siege_trigger(map_name)
		_check_siege_spawn(map_name)
		# Set chapter1_reached_blancogov when the player enters blancogov
		if map_name == "blancogov" or map_name == "blancogov_temple":
			SceneManager.save_manager.set_story_flag("chapter1_reached_blancogov")
		# Chapter 2 beat 2 (GID-108 / TID-407): set on first entry to larik.
		if map_name == "larik":
			SceneManager.save_manager.set_story_flag("chapter2_reached_larik")

## Builds everything the local player sees: joystick, HUD labels, WorldHUD,
## minimap, and the HUD-facing GameBus connections. Never runs on a dedicated
## server, which has no player and no HUD.
func _build_player_hud() -> void:
	_interact_label.hide()
	_interact_label.text = "[Tap] Interact" if OS.has_feature("android") else "[E] Interact"

	var joystick := VirtualJoystickScript.new()
	_hud.add_child(joystick)
	_joystick_ref = joystick

	var vh: float = get_viewport().get_visible_rect().size.y
	_map_label.add_theme_font_size_override("font_size", int(vh * 0.032))
	_coin_label.add_theme_font_size_override("font_size", int(vh * 0.03))
	_interact_label.add_theme_font_size_override("font_size", int(vh * 0.03))

	# WorldHUD owns all dynamically-created buttons, labels, and display state.
	_world_hud = WorldHUD.new()
	_world_hud.name = "WorldHUD"
	add_child(_world_hud)
	_world_hud.setup(_hud, _is_infinite, map_name, _interact_label, self)
	_world_hud.build_bounty_tracker()

	# Must run after _world_hud exists — _update_hud refreshes the XP bar via it.
	_update_hud()

	if not SceneManager.save_manager.get_story_flag("tutorial_inventory_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_inventory_tip")
		var inv_tip: String = "Tap the Inventory button to manage your deck." \
			if OS.has_feature("android") else "Press B or tap Bag to manage your deck."
		_world_hud.show_tip.call_deferred(inv_tip)

	_minimap = Minimap.new()
	add_child(_minimap)
	_minimap.setup(self, _hud, _player, _enemy_nodes, _chest_nodes, _door_nodes, _npc_nodes)
	if _is_infinite:
		_minimap.tapped.connect(_open_fast_travel_panel)
	else:
		_minimap.tapped.connect(_open_map_view)

	GameBus.hud_message_requested.connect(func(text: String) -> void: _world_hud.show_dialogue(text))
	GameBus.story_scroll_collected.connect(_on_scroll_collected)
	GameBus.waystone_activated.connect(_on_waystone_activated)
	GameBus.narration_overlay_requested.connect(_on_narration_overlay_requested)

func _load_named_map() -> void:
	if map_name.begins_with("dungeon_"):
		var dseed: int = int(map_name.substr(8))
		# Use the saved .tres if this dungeon was already generated, otherwise
		# generate fresh and save it (DungeonGen.generate calls save_to_file).
		if MapRegistry.get_map(map_name) != null:
			world_map = WorldMap.new(map_name)
		else:
			world_map = DungeonGen.generate(map_name, dseed)
		# Chapter 2 beat 6 (GID-108 / TID-407): the war-camp dungeon door
		# (assets/maps/marsax_hold.tres) always targets this fixed seed.
		if map_name == "dungeon_731906":
			_inject_warcamp_boss(world_map)
	elif map_name.begins_with("spire_floor_"):
		var parts: PackedStringArray = map_name.split("_")
		var sp_floor: int = int(parts[2]) if parts.size() > 2 else 1
		var sp_seed: int  = int(parts[3]) if parts.size() > 3 else 0
		# An uncleared floor must have its enemy — see prepare_spire_floor. Runs
		# before the map is distributed into chunks, since ChunkRenderer consults
		# defeated_enemies as it spawns.
		SceneManager.save_manager.prepare_spire_floor(sp_floor, sp_seed)
		if MapRegistry.get_map(map_name) != null:
			world_map = WorldMap.new(map_name)
		else:
			world_map = SpireFloorGen.generate(sp_floor, sp_seed)
	else:
		world_map = WorldMap.new(map_name)
		if world_map.is_fallback:
			# Deferred so the dialogue label exists and the world is visible
			_show_dialogue.call_deferred(
				"Map '%s' could not be loaded — using a generated map instead." % map_name)

func _wire_gamebus_signals() -> void:
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.enemy_engaged.connect(_on_enemy_engaged_for_mount)
	GameBus.blight_changed.connect(_refresh_blight_tints)
	# Story-driven cast changes (Maiteln joining/leaving, NPCs who leave their
	# post) have to land while this same map instance stays loaded. Wired here,
	# not in CoopSession._setup_coop — that returns early outside a session, so
	# single-player used to see the change only after a map reload.
	if not NetworkManager.is_dedicated_server():
		GameBus.story_flag_set.connect(_on_story_flag_set_for_cast)

	# Auto-remount when returning to the overworld from a named map
	if map_name == "main":
		var sm_ready := SceneManager.save_manager
		if sm_ready.active_mount != "" and not sm_ready.is_mounted:
			sm_ready.summon_mount(sm_ready.active_mount)

	# Co-op (GID-096): when the local player engages a shared enemy, tell the
	# authority so it is removed for everyone (engage-locks). Inert single-player.
	GameBus.enemy_engaged.connect(coop_session._on_enemy_engaged_coop)

	# Cancel tap-to-move path when battle or menu interrupts movement.
	GameBus.enemy_engaged.connect(func(_enemy_data: Dictionary) -> void: _clear_dest_marker())
	GameBus.inventory_requested.connect(_clear_dest_marker)
	GameBus.journal_requested.connect(_clear_dest_marker)

	# GID-101 (TID-368): champion record + wager payout when PvP ends. Connected
	# permanently (not in _setup_coop) because WorldScene is detached during battle.
	if not GameBus.pvp_battle_ended.is_connected(coop_pvp._on_pvp_battle_ended_coop):
		GameBus.pvp_battle_ended.connect(coop_pvp._on_pvp_battle_ended_coop)

	# GID-104 (TID-386): session tournaments — a referee'd match's real winner
	# (the host isn't a combatant) arrives via this dedicated signal instead of
	# pvp_battle_ended's plain bool. Same "connected permanently" reasoning.
	if not GameBus.pvp_referee_match_ended.is_connected(coop_pvp._on_pvp_referee_match_ended):
		GameBus.pvp_referee_match_ended.connect(coop_pvp._on_pvp_referee_match_ended)

	# GID-102 (TID-371): ranked rating for team duels. Same "connected permanently" reasoning.
	if not GameBus.team_battle_ended.is_connected(coop_pvp._on_team_battle_ended_coop):
		GameBus.team_battle_ended.connect(coop_pvp._on_team_battle_ended_coop)

	# GID-102 (TID-379): PvE leaderboard submission. Connected permanently (same
	# "WorldScene detaches during battle" reasoning as pvp_battle_ended above) so a
	# co-op boss clear is recorded regardless of which map/battle state re-attaches us.
	if not GameBus.coop_pve_battle_ended.is_connected(coop_activities._on_coop_pve_battle_ended_leaderboard):
		GameBus.coop_pve_battle_ended.connect(coop_activities._on_coop_pve_battle_ended_leaderboard)
	# GID-103 (TID-384): co-op Town Siege finale is the first caller of the joint PvE
	# engine — reset siege UI/state and grant party rewards on the outcome. Same
	# "connected permanently" reasoning (WorldScene detaches during the battle).
	if not GameBus.coop_pve_battle_ended.is_connected(coop_activities._on_coop_siege_battle_ended):
		GameBus.coop_pve_battle_ended.connect(coop_activities._on_coop_siege_battle_ended)
	# GID-106 (TID-391): co-op Endless Spire joint floor battles — same joint-PvE
	# signal, same "connected permanently" reasoning.
	if not GameBus.coop_pve_battle_ended.is_connected(coop_activities._on_coop_spire_battle_ended):
		GameBus.coop_pve_battle_ended.connect(coop_activities._on_coop_spire_battle_ended)
	# Spire runs happen while WorldScene is loaded (no battle-detach involved), but the
	# connection is still made once here (not in _setup_coop) so a Spire run that starts
	# before any co-op session is active still reaches this handler once co-op does start.
	if not GameBus.spire_run_ended.is_connected(coop_activities._on_spire_run_ended_leaderboard):
		GameBus.spire_run_ended.connect(coop_activities._on_spire_run_ended_leaderboard)

func _enter_tree() -> void:
	if _initial_ready_done and not _coop_active and NetworkManager.is_active():
		coop_session._setup_coop()
	# GID-101 (TID-367/368): broadcast pvp-clear to spectators now that the world is
	# back in the tree and _net_sync is valid again.
	if _pvp_ended_pending_broadcast and _net_sync != null and _coop_active:
		_pvp_ended_pending_broadcast = false
		_pvp_active_peers.clear()
		for pid in multiplayer.get_peers():
			_net_sync.rpc_id(int(pid), "recv_pvp_active", false,
				_pvp_ante_peer0, _pvp_ante_peer1)
		_pvp_ante_peer0 = -1
		_pvp_ante_peer1 = -1
	# GID-106 (TID-391): same "pending flag flushed on _enter_tree" pattern as
	# _pvp_ended_pending_broadcast above — the co-op Spire battle-end handlers run
	# while this WorldScene is still detached (removed from the tree during the
	# joint battle), so any get_tree()-touching work (showing the draft overlay or
	# the run summary) is deferred until we're reattached and get_tree() is safe.
	# Null on the very first _enter_tree — that runs before _ready, which is where
	# the modules are created. There is nothing pending to flush on a first entry
	# anyway; this only matters on the re-entry after a detached co-op battle.
	if coop_activities != null:
		coop_activities._flush_pending_coop_spire_post_battle()

func _exit_tree() -> void:
	coop_session._teardown_coop()
	if _csm != null:
		_csm.exit_cleanup()
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

# ── Co-op multiplayer (GID-090) ───────────────────────────────────────────────
# All of this is inert unless a NetworkManager session is active when the world
# loads. Single-player behaviour is unchanged.

## Public entry points other scripts call on the WorldScene *node* itself, kept
## here as one-line forwarders after the co-op split. SceneManager reaches these
## through `has_method()` on the detached world scene, so they must resolve on
## WorldScene — a module-only definition fails the has_method() guard and is
## silently skipped rather than erroring.
func enter_downed_state() -> void:
	if coop_session != null:
		coop_session.enter_downed_state()

## Creates the co-op feature modules and, once NetSync exists, registers them as
## its RPC handler targets. Called from _ready (so _ready's own GameBus wiring
## has something to connect to) and again from _setup_coop. Idempotent: a PvP
## battle detaches and re-adds WorldScene without tearing the modules down.
## The modules are inert outside a session, so creating them always is free.
func _ensure_coop_modules() -> void:
	coop_social = _ensure_coop_module(coop_social, _CoopSocial, "CoopSocial")
	coop_pvp = _ensure_coop_module(coop_pvp, _CoopPvP, "CoopPvP")
	coop_activities = _ensure_coop_module(coop_activities, _CoopActivities, "CoopActivities")
	coop_session = _ensure_coop_module(coop_session, _CoopSession, "CoopSession")

func _ensure_coop_module(existing: Node, script: GDScript, node_name: String) -> Node:
	var mod: Node = existing
	if mod == null or not is_instance_valid(mod):
		mod = script.new()
		mod.name = node_name
		mod.set("_world", self)
		add_child(mod)
	if _net_sync != null:
		_net_sync.call("register_handler", mod)
	return mod


func get_session_token_for_peer(peer_id: int) -> String:
	var token: String = str(_session_token_by_peer.get(peer_id, ""))
	# Local-peer convenience branch: only touch `multiplayer` while inside the tree —
	# this accessor is typically called while WorldScene is DETACHED (mid-battle),
	# where the node has no SceneTree and therefore no MultiplayerAPI. Remote lookups
	# (the only ones the wager path actually needs) never require it.
	if token == "" and is_inside_tree() and peer_id == multiplayer.get_unique_id():
		return MpProfile.get_token()
	return token


## Resolve a session token to a display name for the loot-roll toast: the local
## player's own name, or the matching remote identity's name, or a fallback.
func _display_name_for_token(token: String) -> String:
	if token == MpProfile.get_token():
		return MpProfile.get_display_name()
	for pid in _remote_identities.keys():
		var ident: Dictionary = _remote_identities[pid]
		if str(ident.get("token", "")) == token:
			return str(ident.get("name", "Player"))
	return "A party member"


## Build the transient Need/Greed/Pass prompt panel. Viewport-relative, mobile/desktop
## parity (all three choices are tappable buttons — no keyboard-only path).


func _local_deck_for_net() -> Array:
	var out: Array = []
	for inst in SceneManager.save_manager.get_deck_instances():
		out.append(inst)
	return out

## Send a challenge to the nearby peer.


func get_battlefield_context() -> Dictionary:
	var sm := SceneManager.save_manager
	var px: float = _player.position.x if _player != null else 0.0
	var pz: float = _player.position.z if _player != null else 0.0
	var cx: int = int(floor(px / (float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE)))
	var cz: int = int(floor(pz / (float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE)))
	var blighted: bool = _is_infinite and BlightField.is_blighted(
		cx, cz, WORLD_SEED, sm.days_elapsed, sm.blight_cleansed_hearts)
	var attuned: bool = _is_infinite and TerrainMath.is_on_ley_line(px, pz, WORLD_SEED)
	return {
		"biome": _current_biome if _is_infinite else -1,
		"is_night": _dnc != null and _dnc.is_night_now(),
		"is_blighted": blighted,
		"is_player_attuned": attuned,
	}

func _update_hud() -> void:
	if _is_infinite:
		_map_label.text = "World: Infinite"
	elif map_name.begins_with("spire_floor_"):
		var _parts: PackedStringArray = map_name.split("_")
		var _sf: int = int(_parts[2]) if _parts.size() > 2 else 1
		_map_label.text = "Spire — Floor %d" % _sf
	else:
		_map_label.text = "Map: %s" % map_name
	_coin_label.text = "Coins: %d" % SceneManager.save_manager.coins
	SceneManager.save_manager.coins_changed.connect(_on_coins_changed)
	_world_hud.refresh_xp_bar()
	_world_hud.update_xp_label()


# ── Infinite world: chunk streaming ────────────────────────────────────────

func _build_grass_blades_node() -> void:
	_grass = GrassBlades.new()
	_grass.name = "GrassBlades"
	add_child(_grass)

func _spawn_player() -> void:
	var px: float = 3.0 * IsoConst.TILE_SIZE
	var pz: float = 3.0 * IsoConst.TILE_SIZE

	if _is_infinite:
		if SceneManager.save_manager.current_map == map_name and \
				(SceneManager.save_manager.player_x != 0.0 or SceneManager.save_manager.player_z != 0.0):
			px = SceneManager.save_manager.player_x
			pz = SceneManager.save_manager.player_z
	else:
		var default_px: float = (float(world_map.player_spawn_x) + 0.5) * IsoConst.TILE_SIZE \
				if world_map.has_player_spawn() else 3.0 * IsoConst.TILE_SIZE
		var default_pz: float = (float(world_map.player_spawn_z) + 0.5) * IsoConst.TILE_SIZE \
				if world_map.has_player_spawn() else 3.0 * IsoConst.TILE_SIZE
		if not target_door_id.is_empty():
			var door := world_map.find_door_by_id(target_door_id)
			px = door.get("x", default_px) if not door.is_empty() else default_px
			pz = door.get("z", default_pz) if not door.is_empty() else default_pz
		elif SceneManager.save_manager.current_map == map_name and \
				(SceneManager.save_manager.player_x != 0.0 or SceneManager.save_manager.player_z != 0.0):
			# Restore saved position when the save file records this map as the player's
			# last location. The current_map == map_name guard is sufficient — it is only
			# true when loading a save where the player was already in this map. Fresh
			# entries (new game, door travel, waystone) always leave save_manager.current_map
			# pointing to the previous map, so they fall through to the spawn default.
			px = SceneManager.save_manager.player_x
			pz = SceneManager.save_manager.player_z
		else:
			px = default_px
			pz = default_pz

	# Co-op: nudge the joining client +2 tiles so the two avatars don't perfectly
	# overlap at the shared spawn marker (cosmetic; they walk apart immediately).
	if NetworkManager.is_active() and not multiplayer.is_server():
		px += 2.0 * IsoConst.TILE_SIZE

	_player = _create_player_node()
	_player.position = Vector3(px, get_terrain_height(px, pz), pz)
	# Dynamic connect (TID-461): _player is statically typed CharacterBody3D,
	# matching the existing has_method()/call() pattern this file uses for
	# the rest of the Player-specific API.
	if _player.has_signal("path_arrived") and not _player.is_connected("path_arrived", _on_player_path_arrived):
		_player.connect("path_arrived", _on_player_path_arrived)
	_entity_root.add_child(_player)
	_smooth_camera_target = _player.position + Vector3(20, 20, 20)
	_camera.position = _smooth_camera_target

	# Downed & rescue (GID-105 / TID-389): cache the entrance position so a downed
	# player's auto-respawn timeout has somewhere to return to.
	if map_name.begins_with("dungeon_"):
		_dungeon_spawn_pos = _player.position

# Returns the tile type at global tile coordinates (wtx, wtz).
# Used by ChunkRenderer during terrain height computation so hills blend
# seamlessly across chunk borders.
func get_tile_global(wtx: int, wtz: int) -> int:
	return _csm.get_tile_global(wtx, wtz)

# Compute terrain height at a world position using the shared smoothstep algorithm.
# Delegates to the ChunkStreamingManager's cached packed grid (GID-121 / TID-460) —
# steady-state per-frame callers (software floor, followers, remote avatars) resolve
# via direct array indexing instead of ~49 Callable → Dictionary lookups per query.
func get_terrain_height(wx: float, wz: float) -> float:
	if _csm != null:
		return _csm.get_height_world(wx, wz)
	# Pre-setup fallback: only named-map callers can land here (the infinite path
	# has always required _csm — get_tile_global delegates to it).
	return TerrainMath.get_height_at(wx, wz, world_map.get_tile, world_map.get_height,
			IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)

# ── ChunkStreamingManager signal handlers ─────────────────────────────────────

func _on_player_chunk_changed(_chunk: Vector2i, biome_id: int) -> void:
	_current_biome = biome_id
	AudioManager.play_music(_BIOME_MUSIC[biome_id])
	AudioManager.set_ambience(biome_id)
	SceneManager.save_manager.visit_biome(biome_id)
	WeatherManager.set_biome(biome_id)
	GameBus.biome_changed.emit(biome_id)
	_apply_biome_color_grade(biome_id)

func _apply_biome_color_grade(biome_id: int) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	if biome_id < 0 or biome_id >= BiomeDef.ADJ_PARAMS.size():
		return
	var adj: Dictionary = BiomeDef.ADJ_PARAMS[biome_id] as Dictionary
	var env: Environment = _world_env.environment
	env.adjustment_enabled    = true
	env.adjustment_brightness = float(adj.get("brightness", 1.0))
	env.adjustment_contrast   = float(adj.get("contrast",   1.0))
	env.adjustment_saturation = float(adj.get("saturation", 1.0))

func _on_chunk_committed(_key: Vector2i, chunk_data: RefCounted) -> void:
	for l_data: Dictionary in chunk_data.landmarks:
		var lid: String = str(l_data.get("id", ""))
		_active_landmark_data[lid] = l_data

func _on_chunk_unloading(chunk_key: Vector2i, chunk_data: RefCounted) -> void:
	for e_data in chunk_data.enemies:
		var eid: String = str(e_data.get("id", ""))
		var enode: Node3D = _valid_node3d(_enemy_nodes.get(eid))
		if is_instance_valid(enode):
			enode.queue_free()
		_enemy_nodes.erase(eid)
	for c_data in chunk_data.chests:
		var cid: String = str(c_data.get("id", ""))
		_active_chest_data.erase(cid)
		var cnode: Node3D = _valid_node3d(_chest_nodes.get(cid))
		if is_instance_valid(cnode):
			cnode.queue_free()
		_chest_nodes.erase(cid)
	for d_data in chunk_data.doors:
		var did: String = str(d_data.get("id", ""))
		_active_door_data.erase(did)
		var dnode: Node3D = _valid_node3d(_door_nodes.get(did))
		if is_instance_valid(dnode):
			dnode.queue_free()
		_door_nodes.erase(did)
	for n_data in chunk_data.npcs:
		var nid: String = str(n_data.get("id", ""))
		_active_npc_data.erase(nid)
		var nnode: Node3D = _valid_node3d(_npc_nodes.get(nid))
		if is_instance_valid(nnode):
			nnode.queue_free()
		_npc_nodes.erase(nid)
	for w_data in chunk_data.waystones:
		var wid: String = str(w_data.get("id", ""))
		_active_waystone_data.erase(wid)
		var wnode: Node3D = _valid_node3d(_waystone_nodes.get(wid))
		if is_instance_valid(wnode):
			wnode.queue_free()
		_waystone_nodes.erase(wid)
	for m_data in chunk_data.burial_mounds:
		var mid: String = str(m_data.get("id", ""))
		var mnode: Node3D = _valid_node3d(_burial_mound_nodes.get(mid))
		if is_instance_valid(mnode):
			mnode.queue_free()
		_burial_mound_nodes.erase(mid)
	for l_data: Dictionary in chunk_data.landmarks:
		var lid: String = str(l_data.get("id", ""))
		_active_landmark_data.erase(lid)
	for w_data in chunk_data.mana_wells:
		var wid: String = str(w_data.get("id", ""))
		var wnode: Node3D = _valid_node3d(_mana_well_nodes.get(wid))
		if is_instance_valid(wnode):
			wnode.queue_free()
		_mana_well_nodes.erase(wid)
	_evict_nocturnal_enemies_in_chunk(chunk_key)

# ── ChunkRenderer registration callbacks (called via duck typing) ──────────────

# Called by ChunkRenderer after spawning an enemy
func register_enemy(eid: String, node: Node3D) -> void:
	_enemy_nodes[eid] = node

func get_entity_root() -> Node3D:
	return _entity_root

func _tick_traveling_merchant(delta: float) -> void:
	if not _active_npc_data.has("traveling_merchant"):
		return
	_traveling_merchant_timer += delta
	if _traveling_merchant_timer >= 300.0:
		var wem: Node = get_node_or_null("/root/WorldEventManager")
		if wem != null:
			wem.end_event("traveling_merchant")

func _tick_roaming_boss(delta: float) -> void:
	if not _enemy_nodes.has("roaming_boss"):
		return
	_roaming_boss_timer += delta
	var boss: Node3D = _valid_node3d(_enemy_nodes.get("roaming_boss"))
	var expired: bool = _roaming_boss_timer >= 300.0
	var fled: bool = boss == null or not is_instance_valid(boss) or \
		(_player != null and _player.position.distance_to(boss.position) > 160.0)
	if expired or fled:
		var wem: Node = get_node_or_null("/root/WorldEventManager")
		if wem != null:
			wem.end_event("roaming_boss")

func _tick_card_shower() -> void:
	if _card_shower_items.is_empty():
		return
	for item: Node3D in _card_shower_items:
		if is_instance_valid(item):
			return
	# All items gone — end the event
	var wem: Node = get_node_or_null("/root/WorldEventManager")
	if wem != null:
		wem.call("end_event", "card_shower")
	_card_shower_items.clear()

# ── Nocturnal spawn system (GID-055 Night Hunts) ──────────────────────────────

func _update_nocturnal_spawns(delta: float) -> void:
	if not _is_infinite or _player == null:
		return
	var currently_night: bool = _dnc != null and _dnc.is_night_now()
	if not currently_night:
		_nocturnal_spawn_timer = 0.0
		return

	_nocturnal_spawn_timer -= delta
	if _nocturnal_spawn_timer > 0.0:
		return
	_nocturnal_spawn_timer = randf_range(30.0, 60.0)

	# Cap total nocturnal enemies globally to 12
	var alive_count: int = 0
	for sid: String in _nocturnal_enemies.keys():
		var entry: Dictionary = _nocturnal_enemies[sid]
		var n: Node3D = _valid_node3d(entry.get("node"))
		if not is_instance_valid(n):
			_nocturnal_enemies.erase(sid)
		else:
			alive_count += 1
	if alive_count >= 12:
		return

	# Find a walkable grass tile 6–12 world units from the player
	var spawn_pos: Vector3 = _find_nocturnal_spawn_pos()
	if spawn_pos == Vector3.ZERO:
		return

	# Pick spectre tier based on world distance from origin
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var dist: int = int(Vector2(_player.position.x, _player.position.z).length() / chunk_world)
	var enemy_type: String = "spectre_wisp"
	if dist >= 8:
		enemy_type = "spectre_dread"
	elif dist >= 3:
		enemy_type = "spectre_haunt"

	var node: Node3D = _EnemyScene.instantiate() as Node3D
	if node == null:
		return
	_nocturnal_id_counter += 1
	var spawn_id: String = "nocturnal_%d" % _nocturnal_id_counter
	var data: Dictionary = {
		"id": spawn_id,
		"enemy_type": enemy_type,
		"tracking": true,
		"nocturnal": true,
	}
	node.set_meta("is_nocturnal", true)
	node.call("init_from_data", data)
	node.position = spawn_pos
	_entity_root.add_child(node)
	# Tint the Sprite3D child (Node3D has no modulate; Sprite3D does)
	var sprite: Sprite3D = node.get_node_or_null("Sprite3D") as Sprite3D
	if sprite == null:
		for ch in node.get_children():
			if ch is Sprite3D:
				sprite = ch
				break
	if sprite != null:
		sprite.modulate = Color(0.7, 0.85, 1.0, 0.85)

	var pcx: int = int(floor(spawn_pos.x / chunk_world))
	var pcz: int = int(floor(spawn_pos.z / chunk_world))
	_nocturnal_enemies[spawn_id] = {"node": node, "chunk": Vector2i(pcx, pcz)}
	_enemy_nodes[spawn_id] = node

	# Tutorial popup — once per session on first night spawn
	if not _night_hunt_tutorial_shown_session:
		_night_hunt_tutorial_shown_session = true
		if not SceneManager.save_manager.get_story_flag("seen_tutorial_night_hunts"):
			SceneManager.save_manager.set_story_flag("seen_tutorial_night_hunts")
			GameBus.tutorial_popup_requested.emit("night_hunts")

func _find_nocturnal_spawn_pos() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var min_dist: float = 6.0
	var max_dist: float = 14.0
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _try: int in range(20):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(min_dist, max_dist)
		var tx: float = _player.position.x + cos(angle) * dist
		var tz: float = _player.position.z + sin(angle) * dist
		var cx: int = int(floor(tx / chunk_world))
		var cz: int = int(floor(tz / chunk_world))
		var key := Vector2i(cx, cz)
		if not _csm.has_chunk_data(key):
			continue
		var chunk: RefCounted = _csm.get_chunk_data(key)
		var tile_x: int = int(tx / IsoConst.TILE_SIZE) - cx * IsoConst.CHUNK_SIZE
		var tile_z: int = int(tz / IsoConst.TILE_SIZE) - cz * IsoConst.CHUNK_SIZE
		tile_x = clampi(tile_x, 0, IsoConst.CHUNK_SIZE - 1)
		tile_z = clampi(tile_z, 0, IsoConst.CHUNK_SIZE - 1)
		var li: int = tile_z * IsoConst.CHUNK_SIZE + tile_x
		if li < 0 or li >= chunk.tiles.size():
			continue
		var tile_type: int = chunk.tiles[li]
		if tile_type != IsoConst.TILE_GRASS:
			continue
		var world_y: float = get_terrain_height(tx, tz) + 0.5
		return Vector3(tx, world_y, tz)
	return Vector3.ZERO

func _despawn_nocturnal_enemies(fade: bool) -> void:
	for sid: String in _nocturnal_enemies.keys():
		var entry: Dictionary = _nocturnal_enemies[sid]
		var n: Node3D = _valid_node3d(entry.get("node"))
		if not is_instance_valid(n):
			_enemy_nodes.erase(sid)
			continue
		_enemy_nodes.erase(sid)
		if fade:
			# Node3D has no modulate; fade the Sprite3D child instead.
			var sprite: Sprite3D = n.get_node_or_null("Sprite3D") as Sprite3D
			if sprite == null:
				for ch in n.get_children():
					if ch is Sprite3D:
						sprite = ch
						break
			if sprite != null:
				var tw: Tween = create_tween()
				tw.tween_property(sprite, "modulate:a", 0.0, 1.0)
				tw.tween_callback(n.queue_free)
			else:
				n.queue_free()
		else:
			n.queue_free()
	_nocturnal_enemies.clear()

func _evict_nocturnal_enemies_in_chunk(chunk_key: Vector2i) -> void:
	var to_erase: Array[String] = []
	for sid: String in _nocturnal_enemies.keys():
		var entry: Dictionary = _nocturnal_enemies[sid]
		if entry.get("chunk") == chunk_key:
			var n: Node3D = _valid_node3d(entry.get("node"))
			if is_instance_valid(n):
				n.queue_free()
			_enemy_nodes.erase(sid)
			to_erase.append(sid)
	for sid: String in to_erase:
		_nocturnal_enemies.erase(sid)

# Called by ChunkRenderer after spawning a chest
func register_chest(cid: String, node: Node3D, c_data: Dictionary) -> void:
	_chest_nodes[cid] = node
	_active_chest_data[cid] = c_data

# Called by ChunkRenderer after spawning a door
func register_door(did: String, node: Node3D, d_data: Dictionary) -> void:
	_door_nodes[did] = node
	_active_door_data[did] = d_data

# Called by ChunkRenderer after spawning an NPC
func register_npc(nid: String, node: Node3D, n_data: Dictionary) -> void:
	_npc_nodes[nid] = node
	_active_npc_data[nid] = n_data

func get_player() -> Node3D:
	return _player

func register_digspot(node: Node3D) -> void:
	_digspot_node = node

func register_scroll(node: Node3D) -> void:
	_scroll_nodes.append(node)

func _spawn_named_map_scrolls() -> void:
	if world_map == null:
		return
	for entry in world_map.scrolls:
		var wx: float = float(entry["x"])
		var wz: float = float(entry["z"])
		var wy: float = get_terrain_height(wx, wz) + 0.1
		var node := _StoryScrollScene.instantiate() as Node3D
		_entity_root.add_child(node)
		node.position = Vector3(wx, wy, wz)
		if node.has_method("setup"):
			node.setup(str(entry["scroll_id"]), _player)
		if is_instance_valid(node):
			_scroll_nodes.append(node)

## `v` when it is a live Node3D within `range_dist` of (px, pz), else null.
## The proximity family below all measure on the XZ plane — vertical distance
## never gates an interaction.
func _node_in_range(v, px: float, pz: float, range_dist: float) -> Node3D:
	var n: Node3D = _valid_node3d(v)
	if n == null:
		return null
	var ddx: float = n.position.x - px
	var ddz: float = n.position.z - pz
	return n if ddx * ddx + ddz * ddz <= range_dist * range_dist else null

## The first live node within `range_dist` of (px, pz), scanning either an Array
## of nodes or an id -> node Dictionary. `require_visible` additionally skips
## hidden nodes (buried mounds are spawned hidden until revealed).
func _first_node_in_range(nodes, px: float, pz: float, range_dist: float,
		require_visible: bool = false) -> Node3D:
	var range_sq: float = range_dist * range_dist
	var values: Array = (nodes as Dictionary).values() if nodes is Dictionary else nodes
	for raw in values:
		var n: Node3D = _valid_node3d(raw)
		if n == null or (require_visible and not n.visible):
			continue
		var ddx: float = n.position.x - px
		var ddz: float = n.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return n
	return null

## The first entry of an id -> {"x", "z", ...} table within `range_dist` of
## (px, pz), or {} when nothing is close enough.
func _first_data_in_range(table: Dictionary, px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for key in table:
		var d: Dictionary = table[key]
		var ddx: float = float(d.get("x", 0.0)) - px
		var ddz: float = float(d.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return d
	return {}

func _find_nearby_scroll(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_scroll_nodes, px, pz, range_dist)

## First-night wilderness camp (GID-108 / TID-402) — spawns near the player once
## per open-world load, exactly the same "no fixed position, respawn each fresh
## load" pattern as _spawn_open_world_rival_enc2(). Gone for good once
## chapter1_learned_fire is set (the entity frees itself on that transition).
func _spawn_wilderness_camp() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_left_madrian"):
		return
	if sm.get_story_flag("chapter1_learned_fire"):
		return
	if _wilderness_camp_node != null and is_instance_valid(_wilderness_camp_node):
		return
	var wx: float = _player.position.x + 3.0 * IsoConst.TILE_SIZE
	var wz: float = _player.position.z - 4.0 * IsoConst.TILE_SIZE
	var wy: float = get_terrain_height(wx, wz)
	var node := _WildernessCampScene.instantiate() as Node3D
	_entity_root.add_child(node)
	node.position = Vector3(wx, wy, wz)
	_wilderness_camp_node = node

func _find_nearby_wilderness_camp(px: float, pz: float, range_dist: float) -> Node3D:
	return _node_in_range(_wilderness_camp_node, px, pz, range_dist)

## Chapter 2 beat 3 scripted ambush (GID-108 / TID-407) — spawns near the player
## once per open-world load, same "no fixed position" pattern as
## _spawn_wilderness_camp(). Gone for good once chapter2_ambush_survived is set
## (the entity is one-shot: interacting with it immediately starts the battle,
## and ScriptedBattleRegistry/SceneManager set the completion flag on victory).
func _spawn_scout_ambush() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter2_found_letter"):
		return
	if sm.get_story_flag("chapter2_ambush_survived"):
		return
	if _scout_ambush_node != null and is_instance_valid(_scout_ambush_node):
		return
	var wx: float = _player.position.x - 3.0 * IsoConst.TILE_SIZE
	var wz: float = _player.position.z + 4.0 * IsoConst.TILE_SIZE
	var wy: float = get_terrain_height(wx, wz)
	var node := _ScoutAmbushScene.instantiate() as Node3D
	_entity_root.add_child(node)
	node.position = Vector3(wx, wy, wz)
	_scout_ambush_node = node

func _find_nearby_scout_ambush(px: float, pz: float, range_dist: float) -> Node3D:
	return _node_in_range(_scout_ambush_node, px, pz, range_dist)

## Chapter 2 beat 6 (GID-108 / TID-407) — DungeonGen has no boss-room concept
## at all (grepped, confirmed), so the war-camp's boss is injected directly
## into the freshly loaded WorldMap's enemies list before chunk distribution.
## Safe to call on every visit (fresh-gen or loaded-from-save): the enemy-spawn
## pipeline (ChunkRenderer.is_enemy_defeated) already skips already-defeated
## enemies by id, so re-injecting the same dict each time is harmless once
## he's dead — his defeated state lives in SaveManager.defeated_enemies, never
## written back into the dungeon's saved .tres.
## Placement heuristic (not a hard guarantee): DungeonGen (DW=80, DH=60) lays
## rooms left-to-right in ROOM_COUNT columns with z centred on DH/2 ± jitter
## (see DungeonGen._gen_sequential_rooms) — tile (70, 30) sits in the rightmost
## column (the "final room", deepest from the start-room spawn) at the
## statistical z-centre every room jitters around. It is not guaranteed to
## land on carved floor for every seed, but it's a far better bet than a blind
## coordinate, and this dungeon's seed is fixed (731906) so it's the same
## outcome every time — verify visually once Godot is available.
func _inject_warcamp_boss(wm: WorldMap) -> void:
	if wm == null:
		return
	var bx: float = 70.0 * IsoConst.TILE_SIZE
	var bz: float = 30.0 * IsoConst.TILE_SIZE
	wm.enemies.append({
		"id": "martarquas_warleader_boss",
		"x": bx,
		"z": bz,
		"alive": true,
		"tracking": false,
		"enemy_type": "martarquas_warleader",
		"enemy_deck": EnemyRegistry.get_deck("martarquas_warleader"),
	})

## Maiteln's travelling presence (GID-108 / TID-403). Named story maps always
## qualify; the open world only qualifies during the TID-402 camp-beat window
## (not general sandbox presence).
const _MAITELN_NAMED_MAPS: Array[String] = [
	"madrian", "maykalene", "farsyth_mansion", "blancogov", "blancogov_temple",
]

func _maiteln_should_be_present() -> bool:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("story_intro_complete"):
		return false
	if sm.get_story_flag("chapter1_complete"):
		return false
	if _MAITELN_NAMED_MAPS.has(map_name):
		return true
	if map_name == "main":
		return sm.get_story_flag("chapter1_left_madrian") and not sm.get_story_flag("chapter1_learned_fire")
	return false

## Spawns/frees the Maiteln follower to match _maiteln_should_be_present().
## Call on map load and whenever a relevant story flag changes mid-session.
func _refresh_maiteln_presence() -> void:
	var should_be_present: bool = _maiteln_should_be_present()
	if is_instance_valid(_maiteln_node):
		if not should_be_present:
			_maiteln_node.queue_free()
			_maiteln_node = null
		return
	_maiteln_node = null
	if should_be_present and _player != null:
		var node := _MaitelnFollowerScene.instantiate() as Node3D
		_entity_root.add_child(node)
		if node.has_method("setup"):
			node.setup(_player, self)
		# Co-op (GID-108 / TID-408, design rule 4): exactly one Maiteln, position
		# owned by the authority. A non-authority client's copy is a networked
		# puppet — hidden until the first same-map packet arrives (mirrors the
		# RemotePlayer cross-map-ghost fix, TID-352) instead of independently
		# following its own local player.
		if _coop_active and not coop_session._coop_world_authority() and node.has_method("set_networked"):
			node.set_networked(true)
			node.visible = false
		_maiteln_node = node

func _find_nearby_maiteln(px: float, pz: float, range_dist: float) -> Node3D:
	return _node_in_range(_maiteln_node, px, pz, range_dist)

## Any story flag change can move the cast around: Maiteln's follower is gated on
## several Chapter 1 flags, and NPCs carrying MapNpc.hide_flag_key leave their
## post when theirs is set. Both have to react on the flag, not just on the next
## map load — the player is standing right there when it flips.
func _on_story_flag_set_for_cast(_key: String) -> void:
	_refresh_maiteln_presence()
	_despawn_flag_hidden_npcs()

## Removes already-spawned NPCs whose MapNpc.hide_flag_key is now set. The spawn
## side of the same rule lives in ChunkRenderer, which skips them outright.
func _despawn_flag_hidden_npcs() -> void:
	for nid in _active_npc_data.keys():
		var d: Dictionary = _active_npc_data[nid]
		var hide_flag: String = str(d.get("hide_flag_key", ""))
		if hide_flag == "" or not SceneManager.save_manager.get_story_flag(hide_flag):
			continue
		var node: Node3D = _valid_node3d(_npc_nodes.get(nid))
		if node != null:
			node.queue_free()
		_npc_nodes.erase(nid)
		_active_npc_data.erase(nid)

func _spawn_named_map_shrines() -> void:
	if world_map == null:
		return
	for entry in world_map.shrines:
		var wx: float = float(entry["x"])
		var wz: float = float(entry["z"])
		var wy: float = get_terrain_height(wx, wz) + 0.1
		var node := _PuzzleShrineScene.instantiate() as Node3D
		_entity_root.add_child(node)
		node.position = Vector3(wx, wy, wz)
		if node.has_method("setup"):
			node.setup(str(entry["puzzle_id"]), _player)
		if is_instance_valid(node):
			_shrine_nodes.append(node)

func _find_nearby_shrine(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_shrine_nodes, px, pz, range_dist)

# Named-map waystone positions (near spawn, one per town map).
# Used when the map's .tres data has no waystones array populated.
const _NAMED_MAP_WAYSTONE_LABELS: Dictionary = {
	"main": "Main Outpost",
	"madrian": "Madrian",
	"maykalene": "Maykalene",
	"blancogov": "Blancogov",
	"farsyth_mansion": "Farsyth Mansion",
	"blancogov_temple": "Temple of Blancogov",
}

func _spawn_named_map_waystones() -> void:
	if world_map == null:
		return
	var source_list: Array[Dictionary] = []
	if not world_map.waystones.is_empty():
		source_list = world_map.waystones
	elif _NAMED_MAP_WAYSTONE_LABELS.has(map_name):
		# Inject a waystone near the map spawn when none defined in .tres
		var tx: int = world_map.player_spawn_x + 3 if world_map.has_player_spawn() else 8
		var tz: int = world_map.player_spawn_z if world_map.has_player_spawn() else 8
		tx = clamp(tx, 1, WorldMap.MAP_WIDTH - 2)
		tz = clamp(tz, 1, WorldMap.MAP_HEIGHT - 2)
		var w_id: String = "map:%s" % map_name
		var label: String = str(_NAMED_MAP_WAYSTONE_LABELS[map_name])
		source_list = [{
			"id": w_id,
			"x": float(tx) * WorldMap.TILE_SIZE,
			"z": float(tz) * WorldMap.TILE_SIZE,
			"label": label,
			"active": SceneManager.save_manager.is_waystone_activated(w_id),
		}]
	for entry in source_list:
		var wx: float = float(entry["x"])
		var wz: float = float(entry["z"])
		var wy: float = get_terrain_height(wx, wz) + 0.75
		var wid: String = str(entry.get("id", "map:%s" % map_name))
		var is_active: bool = SceneManager.save_manager.is_waystone_activated(wid)
		var w_dict: Dictionary = entry.duplicate()
		w_dict["active"] = is_active
		var node := _WaystoneScene.instantiate() as Node3D
		_entity_root.add_child(node)
		node.position = Vector3(wx, wy, wz)
		if node.has_method("init_from_data"):
			node.init_from_data(w_dict)
		_waystone_nodes[wid] = node
		_active_waystone_data[wid] = w_dict

# Named-map mailbox locations (near spawn, one per town/home map). Injected — there
# is no MailboxData resource type on the .tres maps, unlike waystones.
const _NAMED_MAP_MAILBOX_LOCATIONS: Array[String] = ["madrian", "maykalene", "blancogov", "player_home"]

## Tile offsets from the map spawn, tried in order, when placing the injected
## mailbox. The first walkable one clear of everything the map already placed
## wins. A fixed spawn+(5, 0) used to be the only candidate, which stood the
## Madrian mailbox on Maiteln's exact NPC tile (45, 36).
const _MAILBOX_TILE_OFFSETS: Array[Vector2i] = [
	Vector2i(5, 0), Vector2i(5, -3), Vector2i(5, 3), Vector2i(2, -4),
	Vector2i(2, 4), Vector2i(-3, -3), Vector2i(-3, 3), Vector2i(-5, 0),
]
## How far the injected mailbox stays clear of an authored entity, in tiles.
const _MAILBOX_CLEARANCE_TILES: float = 2.0

func _spawn_named_map_mailboxes() -> void:
	if world_map == null:
		return
	if not _NAMED_MAP_MAILBOX_LOCATIONS.has(map_name):
		return
	if map_name == "player_home" and not SceneManager.save_manager.home_owned:
		return
	# Waystones come from _active_waystone_data rather than world_map.waystones:
	# town maps get theirs injected too, and _spawn_named_map_waystones() has
	# already run by here, so the table is the complete picture.
	var tile: Vector2i = world_map.pick_free_tile_near_spawn(
		_MAILBOX_TILE_OFFSETS, _MAILBOX_CLEARANCE_TILES, _active_waystone_data.values())
	var tx: int = tile.x
	var tz: int = tile.y
	var mid: String = "map:%s" % map_name
	var mx: float = float(tx) * WorldMap.TILE_SIZE
	var mz: float = float(tz) * WorldMap.TILE_SIZE
	var my: float = get_terrain_height(mx, mz) + 0.55
	var m_dict: Dictionary = {"id": mid, "x": mx, "z": mz}
	var node := _MailboxScene.instantiate() as Node3D
	_entity_root.add_child(node)
	node.position = Vector3(mx, my, mz)
	if node.has_method("init_from_data"):
		node.init_from_data(m_dict)
	_mailbox_nodes[mid] = node
	_active_mailbox_data[mid] = m_dict

func _find_nearby_mailbox(px: float, pz: float, range_dist: float) -> Dictionary:
	return _first_data_in_range(_active_mailbox_data, px, pz, range_dist)

## Checks if a siege is active for this named map and spawns raiders + siege banner if so.
## Chapter 2 beat 4 (GID-108 / TID-407) — deterministically starts the same
## GID-054 siege gauntlet the random daily-chance mechanic uses, the first time
## the player enters marsax_hold with the story flags in the right state.
## Reuses 100% of the existing raider/wave/victory machinery; the only new
## pieces are this trigger and the chapter2_siege_won hook in
## SceneManager._on_battle_won's siege-victory branch.
func _check_story_siege_trigger(p_map_name: String) -> void:
	if p_map_name != "marsax_hold":
		return
	# Co-op (GID-108 / TID-408, design rule 6): the synced siege engine (GID-103's
	# CoopSiege) only wired up madrian. Until a marsax_hold variant exists, this
	# story siege is host-resolved — only the authority starts it, so 4 peers
	# walking in don't each spawn their own private local siege. The victory flag
	# still reaches everyone via the existing shared-flag arbitration (rule 1).
	if _coop_active and not coop_session._coop_world_authority():
		return
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter2_ambush_survived"):
		return
	if sm.get_story_flag("chapter2_siege_won"):
		return
	if not sm.get_active_siege().is_empty():
		return
	sm.start_siege("marsax_hold")

func _check_siege_spawn(p_map_name: String) -> void:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	if not _SiegeDefs.is_siege_town(p_map_name):
		return
	var active_siege: Dictionary = SceneManager.save_manager.get_active_siege()
	if active_siege.is_empty() or str(active_siege.get("town", "")) != p_map_name:
		return
	var siege_stage: int = int(active_siege.get("stage", 0))
	_spawn_siege_raiders(p_map_name, siege_stage)
	_setup_siege_banner(p_map_name)

## Instantiates 3 raider EnemyNPC nodes near the town gate.
func _spawn_siege_raiders(p_map_name: String, stage: int) -> void:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	if not _SiegeDefs.TOWN_GATES.has(p_map_name):
		return
	var gate_pos: Vector3 = _SiegeDefs.TOWN_GATES[p_map_name]
	var enemy_type: String = "martarquas_raider_%d" % (stage + 1)
	var offsets: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(2.0, 1.0), Vector2(-2.0, 1.0)]
	for i: int in range(offsets.size()):
		var off: Vector2 = offsets[i]
		var node: Node3D = _EnemyScene.instantiate() as Node3D
		if node == null:
			continue
		var world_y: float = get_terrain_height(gate_pos.x + off.x, gate_pos.z + off.y) + 0.5
		var raider_id: String = "siege_raider_%d_%d" % [stage, i]
		# BID-041 fix: node.set("enemy_type", enemy_type) was a silent no-op —
		# EnemyNPC has no such property, only enemy_data (set via init_from_data),
		# so every raider always fell back to "undead_basic" regardless of stage
		# or town. init_from_data with a proper edata dict (mirrors
		# _spawn_rival_at's exact pattern) is what actually wires the enemy type.
		var edata: Dictionary = {
			"id": raider_id,
			"x": gate_pos.x + off.x,
			"z": gate_pos.z + off.y,
			"alive": true,
			"tracking": false,
			"enemy_type": enemy_type,
			"enemy_deck": EnemyRegistry.get_deck(enemy_type),
		}
		node.position = Vector3(gate_pos.x + off.x, world_y, gate_pos.z + off.y)
		if node.has_method("init_from_data"):
			node.init_from_data(edata)
		_entity_root.add_child(node)
		_enemy_nodes[raider_id] = node
		_siege_raider_nodes.append(node)

## Creates the siege banner label in the HUD (visible while siege is active).
func _setup_siege_banner(p_map_name: String) -> void:
	if _hud == null:
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	_siege_banner = _UiUtil.make_label("%s Under Attack!" % p_map_name.capitalize().replace("_", " "), int(vh * 0.03), Color(1.0, 0.3, 0.1), HORIZONTAL_ALIGNMENT_CENTER, _hud)
	_siege_banner.position = Vector2((vw - vh * 0.6) * 0.5, vh * 0.005)
	_siege_banner.custom_minimum_size = Vector2(vh * 0.6, int(vh * 0.04))

func register_waystone(wid: String, node: Node3D, w_data: Dictionary) -> void:
	_waystone_nodes[wid] = node
	_active_waystone_data[wid] = w_data

func register_burial_mound(mid: String, node: Node3D) -> void:
	_burial_mound_nodes[mid] = node

func register_blight_heart(heart_id: String, node: Node3D) -> void:
	_blight_heart_nodes[heart_id] = node

func register_landmark(landmark_id: String, l_data: Dictionary) -> void:
	_active_landmark_data[landmark_id] = l_data

func register_mana_well(wid: String, node: Node3D) -> void:
	_mana_well_nodes[wid] = node

func _find_nearby_mana_well(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_mana_well_nodes, px, pz, range_dist)

func _find_nearby_blight_heart(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_blight_heart_nodes, px, pz, range_dist)

const LANDMARK_DISCOVERY_RANGE: float = 9.0

func _check_nearby_landmark(px: float, pz: float) -> void:
	if not _is_infinite:
		return
	var range_sq: float = LANDMARK_DISCOVERY_RANGE * LANDMARK_DISCOVERY_RANGE
	var sm := SceneManager.save_manager
	for lid: String in _active_landmark_data:
		if sm.is_landmark_discovered(lid):
			continue
		var l: Dictionary = _active_landmark_data[lid]
		var ddx: float = float(l.get("x", 0.0)) - px
		var ddz: float = float(l.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			_discover_landmark(lid, l)

func _discover_landmark(lid: String, l_data: Dictionary) -> void:
	var sm := SceneManager.save_manager
	sm.mark_landmark_discovered(lid)
	var cx: int = int(l_data.get("cx", 0))
	var cz: int = int(l_data.get("cz", 0))
	var display_name: String = LandmarkNames.get_name(cx, cz, WORLD_SEED)
	GameBus.landmark_discovered.emit(lid, display_name)
	SceneManager.show_toast("Discovery!", display_name)
	# One-time reward: coins + random card
	sm.add_coins(50)
	var card_ids: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var rng := RandomNumberGenerator.new()
	rng.seed = (cx * 73856093) ^ (cz * 19349663) ^ WORLD_SEED
	rng.seed = rng.seed & 0x7FFFFFFF
	var card_id: String = card_ids[rng.randi_range(0, card_ids.size() - 1)]
	sm.grant_card_reward(card_id, "rare")
	GameBus.hud_message_requested.emit("You discovered %s! +50 coins, +1 card." % display_name)

func _refresh_blight_tints() -> void:
	var sm := SceneManager.save_manager
	_csm.for_each_renderer(func(key: Vector2i, cr: ChunkRenderer) -> void:
		var intensity: float = BlightField.blight_intensity(
			key.x, key.y, WORLD_SEED, sm.days_elapsed, sm.blight_cleansed_hearts)
		cr.set_blight_amount(intensity)
	)

func _find_nearby_burial_mound(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_burial_mound_nodes, px, pz, range_dist, true)

func _find_nearby_waystone(px: float, pz: float, range_dist: float) -> Dictionary:
	return _first_data_in_range(_active_waystone_data, px, pz, range_dist)

func _on_waystone_activated(waystone_id: String) -> void:
	var w_data: Dictionary = _active_waystone_data.get(waystone_id, {})
	var label: String = str(w_data.get("label", "Unknown"))
	SceneManager.show_toast("Waystone Activated", label)

func _waystone_friendly_label(wid: String) -> String:
	if wid.begins_with("map:"):
		return wid.substr(4).capitalize().replace("_", " ")
	elif wid.begins_with("world:"):
		var parts: PackedStringArray = wid.split(":")
		if parts.size() >= 3:
			return "Waystone (%s, %s)" % [parts[1], parts[2]]
	return wid

func _open_fast_travel_panel() -> void:
	if _fast_travel_layer != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	var panel_h: float = vh * 0.62
	var modal: Dictionary = _build_modal(0.55, 0.62, Color(0.05, 0.05, 0.10, 0.96), 0.018)
	var layer: CanvasLayer = modal["layer"]
	var backdrop: ColorRect = modal["backdrop"]
	var vbox: VBoxContainer = modal["vbox"]
	_fast_travel_layer = layer

	var title := _UiUtil.make_label("Fast Travel", int(vh * 0.035), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Color(0.40, 0.90, 1.00))
	vbox.add_child(title)

	var is_blocked: bool = SceneManager.current_map.begins_with("dungeon_")
	var activated: Array[String] = SceneManager.save_manager.activated_waystones
	if activated.is_empty():
		var empty_lbl := _UiUtil.make_label("No waystones activated yet.\nFind and interact with a waystone pillar to unlock fast travel.", int(vh * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty_lbl)
	elif is_blocked:
		var block_lbl := _UiUtil.make_label("Fast travel is unavailable inside dungeons.", int(vh * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		block_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		block_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(block_lbl)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, panel_h * 0.62)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var btn_vbox := _UiUtil.make_vbox(int(vh * 0.010), scroll)
		btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn_h: float = vh * 0.060
		for wid: String in activated:
			var btn := _UiUtil.make_button(_waystone_friendly_label(wid), Vector2(0, btn_h), int(vh * 0.024))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_id: String = wid
			btn.pressed.connect(func() -> void:
				_fast_travel_layer = null
				layer.queue_free()
				SceneManager.teleport_to_waystone(captured_id)
			)
			btn_vbox.add_child(btn)

	var close_btn := _UiUtil.make_button("Close  [Esc]" if not OS.has_feature("android") else "Close", Vector2(vh * 0.20, vh * 0.06), int(vh * 0.024))
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void:
		_fast_travel_layer = null
		layer.queue_free()
	)
	vbox.add_child(close_btn)

	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and event.pressed:
			_fast_travel_layer = null
			layer.queue_free()
	)

# ── Rival Encounter Spawning ───────────────────────────────────────────────────

func _spawn_named_map_rivals() -> void:
	if world_map == null:
		return
	var sm := SceneManager.save_manager
	if map_name == "maykalene" and sm.get_story_flag("chapter1_left_madrian") and sm.rival_encounters_won == 0:
		_spawn_rival("rival_enc1", 50, 40, "rival_isfig_1",
			"You again? Let's see if you're worth the effort, wee warrior.")
	elif map_name == "blancogov_temple" and sm.get_story_flag("chapter1_temple_council") \
			and sm.rival_encounters_won >= 2 and not sm.rival_defeated:
		_spawn_rival("rival_enc3", 50, 80, "rival_isfig_3",
			"Maiteln warned me you'd come far. Perhaps it's time I stood beside him, not against.")

func _spawn_open_world_rival_enc2() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_warned_farsyth"):
		return
	if sm.get_story_flag("chapter1_received_letter"):
		return
	if sm.rival_encounters_won >= 2:
		return
	var rival_type: String = RivalSystem.get_rival_type(sm.rival_encounters_won, sm.level)
	var wx: float = _player.position.x + 3.0 * IsoConst.TILE_SIZE
	var wz: float = _player.position.z + 5.0 * IsoConst.TILE_SIZE
	_spawn_rival_at("rival_enc2", wx, wz, rival_type,
		"Maiteln's sent word of the Martarquas. I aim to warn him you're no mere apprentice.")

func _spawn_rival(rival_id: String, tile_x: int, tile_z: int, enemy_type: String, pre_battle_dialogue: String) -> void:
	var wx: float = float(tile_x) * IsoConst.TILE_SIZE
	var wz: float = float(tile_z) * IsoConst.TILE_SIZE
	_spawn_rival_at(rival_id, wx, wz, enemy_type, pre_battle_dialogue)

func _spawn_rival_at(rival_id: String, wx: float, wz: float, enemy_type: String, pre_battle_dialogue: String) -> void:
	if _enemy_nodes.has(rival_id):
		return
	var wy: float = get_terrain_height(wx, wz) + 0.5
	var edata: Dictionary = {
		"id": rival_id,
		"x": wx,
		"z": wz,
		"alive": true,
		"tracking": false,
		"enemy_type": enemy_type,
		"enemy_deck": EnemyRegistry.get_deck(enemy_type),
		"pre_battle_dialogue": pre_battle_dialogue,
	}
	var node := _EnemyScene.instantiate() as Node3D
	_entity_root.add_child(node)
	node.position = Vector3(wx, wy, wz)
	if node.has_method("init_from_data"):
		node.init_from_data(edata)
	_enemy_nodes[rival_id] = node


# Find nearest entities — checks the player's chunk + 8 neighbours for enemies/chests;
# scans active data dicts for doors and NPCs.
func _find_nearby_enemy(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(px / chunk_world))
	var pcz: int = int(floor(pz / chunk_world))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(pcx + dx, pcz + dz)
			if not _csm.has_chunk_data(key):
				continue
			var chunk: RefCounted = _csm.get_chunk_data(key)
			for e_data in chunk.enemies:
				var eid: String = str(e_data.get("id", ""))
				var node: Node3D = _valid_node3d(_enemy_nodes.get(eid))
				if not is_instance_valid(node):
					continue
				var ddx: float = node.global_position.x - px
				var ddz: float = node.global_position.z - pz
				if ddx * ddx + ddz * ddz <= range_sq:
					return node
	return null

func _find_nearby_chest(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(px / chunk_world))
	var pcz: int = int(floor(pz / chunk_world))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(pcx + dx, pcz + dz)
			if not _csm.has_chunk_data(key):
				continue
			var chunk: RefCounted = _csm.get_chunk_data(key)
			for c_data in chunk.chests:
				var cid: String = str(c_data.get("id", ""))
				var d: Dictionary = _active_chest_data.get(cid, {})
				if d.is_empty() or d.get("opened", false):
					continue
				var ddx: float = float(d.get("x", 0.0)) - px
				var ddz: float = float(d.get("z", 0.0)) - pz
				if ddx * ddx + ddz * ddz <= range_sq:
					return d
	return {}

func _find_nearby_door(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	var best: Dictionary = {}
	var best_dist_sq: float = range_sq + 1.0
	for did in _active_door_data:
		var d: Dictionary = _active_door_data[did]
		var fk: String = d.get("flag_key", "")
		if fk != "" and not SceneManager.save_manager.get_story_flag(fk):
			continue
		var ddx: float = float(d.get("x", 0.0)) - px
		var ddz: float = float(d.get("z", 0.0)) - pz
		var dist_sq: float = ddx * ddx + ddz * ddz
		if dist_sq <= range_sq and dist_sq < best_dist_sq:
			best = d
			best_dist_sq = dist_sq
	return best

func _find_nearby_digspot(px: float, pz: float, range_dist: float) -> Node3D:
	if not is_instance_valid(_digspot_node):
		_digspot_node = null
		return null
	return _node_in_range(_digspot_node, px, pz, range_dist)

func _break_cracked_wall(tx: int, tz: int) -> void:
	world_map.set_tile(tx, tz, IsoConst.TILE_GRASS)
	AudioManager.play_sfx("chest_open")
	SceneManager.show_toast("Secret passage!", "A hidden room is revealed.")
	_rebuild_terrain_around_tile(tx, tz)
	world_map.save_to_file(SceneManager.save_manager.current_map)

func _rebuild_terrain_around_tile(tx: int, tz: int) -> void:
	_csm.rebuild_terrain_around_tile(tx, tz)

func _find_nearby_npc(px: float, pz: float, range_dist: float) -> Dictionary:
	return _first_data_in_range(_active_npc_data, px, pz, range_dist)

func _make_terrain_material(_seed: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TerrainShader
	mat.set_shader_parameter("grass_texture",     _TexGrass)
	mat.set_shader_parameter("hill_side_texture", _TexHillSide)
	mat.set_shader_parameter("hill_texture",      _TexHillTop)
	mat.set_shader_parameter("wall_side_texture", _TexWallSide)
	mat.set_shader_parameter("wall_top_texture",  _TexWallTop)
	mat.set_shader_parameter("path_texture",      _TexPath)
	mat.set_shader_parameter("uv_scale", 0.5)
	return mat

func _create_player_node() -> CharacterBody3D:
	var p: CharacterBody3D = _PlayerScene.instantiate()
	p.add_to_group("player")
	return p

# ── Camera pixel-snapping ──────────────────────────────────────────────────
# Snaps a world-space position to the nearest screen pixel along the camera's
# screen-plane axes (right and up).  The depth axis is left unsnapped.
# This prevents sub-pixel camera drift from causing the procedural terrain and
# grass noise to shimmer — every world point stays on the same screen pixel
# between frames as long as the camera hasn't moved a full pixel.
func _snap_to_pixel(pos: Vector3) -> Vector3:
	var vp_h: float = float(get_viewport().get_visible_rect().size.y)
	var pixel: float = IsoConst.CAM_ORTHO_SIZE * 2.0 / vp_h
	var right: Vector3 = _camera.global_transform.basis.x
	var up: Vector3    = _camera.global_transform.basis.y
	var fwd: Vector3   = _camera.global_transform.basis.z
	var r: float = round(pos.dot(right) / pixel) * pixel
	var u: float = round(pos.dot(up)    / pixel) * pixel
	var d: float = pos.dot(fwd)
	return right * r + up * u + fwd * d

# ── Per-frame update ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Co-op and time ticks run before the player null-check so they work in
	# dedicated-server mode (no local player) as well as in normal sessions.
	if _coop_active:
		_tick_coop(delta)
	if _dnc:
		_dnc.tick(delta, _weather_tint)

	if _player == null:
		return
	# Software floor: rescue the player only when physics has genuinely lost
	# the terrain (chunk collider not built yet, or tunneled through). Never
	# fire while is_on_floor() — the analytic smoothstep height sits up to
	# ~0.4 units above the HeightMapShape3D facets on steep hills, and
	# snapping every frame there (plus cancel_fall) caused the jerky climb.
	var rx: float = _player.position.x
	var rz: float = _player.position.z
	var floor_y: float = get_terrain_height(rx, rz)
	if not _player.is_on_floor() and _player.position.y < floor_y - 0.05:
		_player.position = Vector3(rx, floor_y, rz)
		_player.cancel_fall()
		_smooth_camera_target = _player.position + Vector3(20, 20, 20)
	var cam_target := _player.position + Vector3(20, 20, 20)
	_smooth_camera_target = _smooth_camera_target.lerp(cam_target, clampf(20.0 * delta, 0.0, 1.0))
	_camera.position = _snap_to_pixel(_smooth_camera_target)
	if _minimap:
		_minimap.update()
	if _world_hud:
		var tx: int = int(_player.position.x / IsoConst.TILE_SIZE)
		var tz: int = int(_player.position.z / IsoConst.TILE_SIZE)
		_world_hud.update_coords(tx, tz)
	if _grass:
		_grass.update_player(_player.position, delta, _player.is_on_floor())

	# Lerp weather tint toward target and invalidate ambient cache to force GPU write
	if _weather_tint_lerp_t < 1.0:
		_weather_tint_lerp_t = minf(_weather_tint_lerp_t + delta * _WEATHER_TINT_SPEED, 1.0)
		_weather_tint = _weather_tint.lerp(_weather_tint_target, delta * _WEATHER_TINT_SPEED)
		if _dnc:
			_dnc.invalidate_ambient_cache()

	# Keep particle rig centred on the player
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.position = _player.position + Vector3(0.0, 12.0, 0.0)

	if _is_infinite:
		if _world_hud != null:
			_world_hud.set_ley_indicator_visible(TerrainMath.is_on_ley_line(
				_player.position.x, _player.position.z, WORLD_SEED))
		_tick_roaming_boss(delta)
		_tick_traveling_merchant(delta)
		_tick_card_shower()
		_update_nocturnal_spawns(delta)
		_csm.process_streaming(_player.position, _player.velocity, _camera.get_frustum())

	# Only update save position when player moves > 1 unit (not every frame)
	var cur_pos := Vector2(_player.position.x, _player.position.z)
	if cur_pos.distance_squared_to(_last_save_pos) > 1.0:
		_last_save_pos = cur_pos
		SceneManager.save_manager.update_position(map_name, _player.position.x, _player.position.z)
		if _dnc:
			SceneManager.save_manager.time_of_day = _dnc.get_time_of_day()

	# Throttle interaction checks — no need to scan every frame
	_interact_timer += delta
	if _interact_timer >= INTERACT_INTERVAL:
		_interact_timer = 0.0
		_check_interactions()

	# Hide dest marker once the player's path is complete.
	if _dest_marker != null and _dest_marker.visible:
		if _player != null and _player.has_method("cancel_path"):
			var active: bool = _player.get("_has_active_path")
			if not active:
				if _dest_tween != null and _dest_tween.is_valid():
					_dest_tween.kill()
				_dest_tween = null
				_dest_marker.hide()

	if Input.is_action_just_pressed("interact"):
		_handle_interact()

	if Input.is_action_just_pressed("mount"):
		_toggle_mount()

## The HUD prompt label for whatever the player can reach, or "" when nothing
## is in range. Probes run in _handle_interact's priority order and stop at the
## first hit, so a tick usually costs one proximity scan instead of seventeen.

## Per-frame co-op work, in the order it has always run. The modules are ticked
## interleaved rather than grouped by module because that is the order these
## have always executed in and none of them is provably order-independent.
## Every one is internally gated (host/authority, map scope, feature opt-in), so
## this is cheap when nothing is in flight.
func _tick_coop(delta: float) -> void:
	coop_session._broadcast_local_avatar(delta)
	coop_session._broadcast_maiteln_state(delta)
	coop_pvp._update_challenge_proximity()
	coop_pvp._update_draft_duel_proximity()
	coop_pvp._check_challenge_timeouts()
	coop_pvp._tick_tournament(delta)
	coop_session._tick_session_persist(delta)
	# World-object sync (GID-096): host streams enemy positions; clients smooth.
	coop_session._broadcast_enemy_positions(delta)
	coop_session._interp_synced_enemies(delta)
	# GID-101: social features tick
	coop_social._tick_emote_self(delta)
	coop_social._tick_ping_markers(delta)
	coop_social._update_social_proximity()
	# Party loot rolls (GID-102 / TID-381): authority-only timeout ticker; inert
	# unless a roll is actually in flight (need/greed mode opted in).
	coop_activities._tick_loot_rolls(delta)
	# Co-op Endless Spire draft (GID-106 / TID-390): authority-only timeout ticker;
	# inert unless a draft round is actually in flight.
	coop_activities._tick_coop_spire_draft(delta)
	# Downed & rescue (GID-105 / TID-389): live countdown on the local banner.
	if _coop_downed and _downed_banner != null and is_instance_valid(_downed_banner):
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _downed_started_at
		var remaining: float = _DownedSync.remaining_time(elapsed)
		_downed_banner.text = "Downed — waiting for rescue… (%ds)" % int(ceil(remaining))
	# Shared world life (GID-103): synced clock/weather, party night hunts, and
	# the co-op siege wave watcher. Map-scoped and host/authority gated
	# internally; single-player never reaches these.
	coop_session._tick_env_sync(delta)
	coop_activities._coop_update_night_hunts(delta)
	coop_activities._coop_tick_siege(delta)
func _interact_prompt_label(px: float, pz: float) -> String:
	var r: float = IsoConst.INTERACT_RANGE
	if coop_session._find_nearby_downed_peer(px, pz, r) != -1:
		return "REVIVE"
	if not _find_nearby_door(px, pz, r * 2.0).is_empty():
		return "ENTER"
	if not _find_nearby_chest(px, pz, r).is_empty():
		return "OPEN"
	var npc := _find_nearby_npc(px, pz, r)
	if not npc.is_empty():
		return str(_NPC_PROMPT_LABELS.get(str(npc.get("npc_type", "")), "TALK"))
	if _find_nearby_scroll(px, pz, r) != null:
		return "READ"
	if _find_nearby_wilderness_camp(px, pz, r) != null:
		return "CAMP"
	if _find_nearby_maiteln(px, pz, r) != null:
		return "TALK"
	if _find_nearby_shrine(px, pz, r) != null:
		return "PRAY"
	if _find_nearby_digspot(px, pz, r) != null:
		return "DIG"
	if _find_nearby_burial_mound(px, pz, r) != null:
		return "DIG"
	if _find_nearby_mana_well(px, pz, r) != null:
		return "FILL"
	if not _find_nearby_waystone(px, pz, r).is_empty():
		return "WARP"
	if not _find_nearby_mailbox(px, pz, r).is_empty():
		return "MAIL"
	if _find_nearby_garden_plot(px, pz, r) != null:
		return "TEND"
	# Hostile entities last — see INTERACT_PRIORITY.
	if _find_nearby_blight_heart(px, pz, r) != null:
		return "CLEANSE"
	if _find_nearby_scout_ambush(px, pz, r) != null:
		return "ATTACK"
	if _find_nearby_enemy(px, pz, r) != null:
		return "ATTACK"
	return ""

## One-time "press E to …" hints. Each probe runs only while its flag is still
## unset, so this costs nothing once the player has seen all three.
func _show_first_interact_tips(px: float, pz: float) -> void:
	var sm := SceneManager.save_manager
	var r: float = IsoConst.INTERACT_RANGE
	var tap: bool = OS.has_feature("android")
	if not sm.get_story_flag("tutorial_npc_tip") and not _find_nearby_npc(px, pz, r).is_empty():
		sm.set_story_flag("tutorial_npc_tip")
		_show_tip("Tap to talk" if tap else "Press E to talk to NPCs")
	elif not sm.get_story_flag("tutorial_chest_tip") and not _find_nearby_chest(px, pz, r).is_empty():
		sm.set_story_flag("tutorial_chest_tip")
		_show_tip("Tap to open chests" if tap else "Press E to open chests")
	elif not sm.get_story_flag("tutorial_enemy_tip") and _find_nearby_enemy(px, pz, r) != null:
		sm.set_story_flag("tutorial_enemy_tip")
		_show_tip("Some enemies attack on sight — others wait. %s to challenge any enemy."
			% ("Tap" if tap else "Press E"))

func _check_interactions() -> void:
	var px: float = _player.position.x
	var pz: float = _player.position.z
	# Downed & rescue (GID-105 / TID-389): frozen — cannot interact with anything
	# (chests/NPCs/doors/enemies are all unreachable anyway since the player can't
	# move, but this is a defensive guard for whatever was in range at defeat).
	if _coop_downed:
		_world_hud.show_interact_prompt(false, "USE")
		return
	# Landmarks auto-trigger on approach (no button press needed).
	_check_nearby_landmark(px, pz)
	var label: String = _interact_prompt_label(px, pz)
	_world_hud.show_interact_prompt(label != "" and not SceneManager.has_open_overlay(),
		label if label != "" else "USE")
	_show_first_interact_tips(px, pz)

func _open_map_view() -> void:
	if _is_infinite:
		return
	if _map_overlay != null:
		_map_overlay.queue_free()
		_map_overlay = null
		return
	_map_overlay = MapViewOverlay.new()
	add_child(_map_overlay)
	_map_overlay.setup(world_map, map_name, _player,
		_npc_nodes, _active_npc_data,
		_enemy_nodes, _chest_nodes, _door_nodes, _waystone_nodes,
		coop_session._build_rally_targets())
	_map_overlay.closed.connect(func() -> void: _map_overlay = null)
	_map_overlay.rally_requested.connect(coop_session._rally_to_peer)

func _open_pause() -> void:
	if _pause_overlay != null:
		return
	_pause_overlay = _OverworldPauseOverlay.new()
	_pause_overlay.resumed.connect(func() -> void: _pause_overlay = null)
	_pause_overlay.quit_to_menu.connect(func() -> void: _pause_overlay = null)
	add_child(_pause_overlay)

# ── Cantrip activation (GID-065) ───────────────────────────────────────────

func _activate_ghost_phase() -> void:
	if _player == null or _ghost_phase_active:
		return
	var sm := SceneManager.save_manager
	var template_ids: Array[String] = sm.get_deck_template_ids()
	if not CantripManager.is_available("ghost_phase", template_ids):
		GameBus.hud_message_requested.emit("Ghost Phase requires 4+ Ghost-family cards in your deck.")
		return
	var current_time: float = Time.get_unix_time_from_system()
	if CantripManager.is_on_cooldown("ghost_phase", sm.cantrip_cooldowns, current_time):
		var remaining: int = CantripManager.cooldown_remaining("ghost_phase", sm.cantrip_cooldowns, current_time)
		GameBus.hud_message_requested.emit("Ghost Phase on cooldown (%ds)." % remaining)
		return
	if not _do_ghost_phase():
		GameBus.hud_message_requested.emit("No wall to phase through in this direction.")
		return
	sm.cantrip_cooldowns["ghost_phase"] = current_time + CantripManager.get_cooldown("ghost_phase")
	sm.mark_dirty()
	GameBus.cantrip_used.emit("ghost_phase")

func _do_ghost_phase() -> bool:
	var px: float = _player.position.x
	var pz: float = _player.position.z
	var tile_size: float = IsoConst.TILE_SIZE
	var wtx: int = int(floor(px / tile_size))
	var wtz: int = int(floor(pz / tile_size))

	# Build ordered list of directions to try: facing first, then all 4 cardinals
	var dirs: Array[Vector2i] = []
	var _last_move_dir: Vector2 = _csm.get_last_move_dir() if _csm != null else Vector2.ZERO
	if _last_move_dir.length_squared() > 0.01:
		var primary: Vector2i
		if abs(_last_move_dir.x) >= abs(_last_move_dir.y):
			primary = Vector2i(1 if _last_move_dir.x > 0 else -1, 0)
		else:
			primary = Vector2i(0, 1 if _last_move_dir.y > 0 else -1)
		dirs.append(primary)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not dirs.has(d):
			dirs.append(d)

	for d: Vector2i in dirs:
		var wall_tx: int = wtx + d.x
		var wall_tz: int = wtz + d.y
		var beyond_tx: int = wtx + d.x * 2
		var beyond_tz: int = wtz + d.y * 2
		if get_tile_global(wall_tx, wall_tz) != IsoConst.TILE_WALL:
			continue
		if get_tile_global(beyond_tx, beyond_tz) == IsoConst.TILE_WALL:
			continue  # two walls — too thick to phase through
		var target_x: float = float(beyond_tx) * tile_size + tile_size * 0.5
		var target_z: float = float(beyond_tz) * tile_size + tile_size * 0.5
		var target_y: float = get_terrain_height(target_x, target_z) + 0.5
		_start_ghost_phase_tween(Vector3(target_x, target_y, target_z))
		return true
	return false

func _start_ghost_phase_tween(target: Vector3) -> void:
	_ghost_phase_active = true
	_player.collision_layer = 0
	_player.collision_mask = 0
	_set_player_alpha(0.5)
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.tween_property(_player, "position", target, 0.3)
	_ghost_tween.tween_callback(_on_ghost_phase_done)

func _on_ghost_phase_done() -> void:
	_player.collision_layer = 1
	_player.collision_mask = 2 | 4
	_set_player_alpha(1.0)
	_ghost_phase_active = false

func _set_player_alpha(alpha: float) -> void:
	if _player == null:
		return
	var sprites: Array[Node] = _player.find_children("*", "Sprite3D", true, false)
	for s: Node in sprites:
		var sp: Sprite3D = s as Sprite3D
		if sp != null:
			var c: Color = sp.modulate
			c.a = alpha
			sp.modulate = c

func _activate_skeleton_dig() -> void:
	if _player == null:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z
	var mound := _find_nearby_burial_mound(px, pz, IsoConst.INTERACT_RANGE)
	if mound == null:
		GameBus.hud_message_requested.emit("No burial mound nearby to dig.")
		return
	if mound.has_method("interact"):
		mound.interact()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _pause_overlay == null:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map_view"):
		_clear_dest_marker()
		_open_map_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_clear_dest_marker()
		GameBus.inventory_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		_clear_dest_marker()
		GameBus.journal_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character"):
		_clear_dest_marker()
		GameBus.character_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_tree"):
		_clear_dest_marker()
		GameBus.skill_tree_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		_activate_ghost_phase()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_activate_skeleton_dig()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) \
			and _coop_active and _chat_input != null and is_instance_valid(_chat_input) \
			and not _chat_input.has_focus():
		# Desktop chat-focus shortcut (TID-374). Mobile equivalent is the "Chat"
		# HUD button (_chat_toggle_btn), which also reveals/focuses the input.
		_chat_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _tap_touch_index:
			# Joystick guard: if the drag moves over the joystick, let joystick win.
			if _joystick_ref != null and _joystick_ref.has_method("is_touch_in_control_area"):
				if _joystick_ref.call("is_touch_in_control_area", drag.position):
					_tap_touch_index = -2
					return
			# Steer the move target continuously once the drag threshold is crossed.
			if drag.position.distance_to(_tap_start_screen) >= _TAP_DRAG_THRESHOLD:
				if _camera != null:
					var drag_tile: Vector2i = _screen_to_tile(drag.position)
					if drag_tile != _drag_last_tile:
						_drag_last_tile = drag_tile
						_handle_tap_to_move(drag.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag_last_tile = Vector2i(-9999, -9999)
			_handle_tap_to_move(mb.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _camera != null:
			var mt: Vector2i = _screen_to_tile((event as InputEventMouseMotion).position)
			if mt != _drag_last_tile:
				_drag_last_tile = mt
				_handle_tap_to_move((event as InputEventMouseMotion).position)
				get_viewport().set_input_as_handled()

func _on_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _tap_touch_index != -2:
			return  # already tracking another finger
		# Reject taps in the virtual joystick interactive areas.
		if _joystick_ref != null and _joystick_ref.has_method("is_touch_in_control_area"):
			if _joystick_ref.call("is_touch_in_control_area", touch.position):
				return
		# Reject taps on any visible HUD button (USE, Mount, Ghost Phase, etc.).
		if _world_hud != null and _world_hud.is_touch_on_hud_button(touch.position):
			return
		_tap_start_screen = touch.position
		_tap_touch_index = touch.index
		_drag_last_tile = Vector2i(-9999, -9999)
	else:
		if touch.index != _tap_touch_index:
			return
		var drag_dist: float = touch.position.distance_to(_tap_start_screen)
		_tap_touch_index = -2
		if drag_dist < _TAP_DRAG_THRESHOLD:
			_handle_tap_to_move(touch.position)
			get_viewport().set_input_as_handled()

## Entities whose interaction is simply "call one method on the node". Probed in
## this order and stopping at the first hit, exactly as the eight open-coded
## branches this replaces did. Anything that needs arguments or surrounding state
## (doors, chests, NPCs, mana wells, waystones, mailboxes, garden plots) keeps its
## own branch in _handle_interact.
##
## The table is built per call rather than being a const: a Callable bound to an
## instance method cannot be a constant, and this only runs on a button press.
func _try_simple_interaction(px: float, pz: float) -> bool:
	var r: float = IsoConst.INTERACT_RANGE
	for entry: Array in [
		[_find_nearby_scroll, "interact"],
		[_find_nearby_wilderness_camp, "interact"],
		[_find_nearby_maiteln, "interact"],
		[_find_nearby_shrine, "interact"],
		[_find_nearby_digspot, "dig"],
		[_find_nearby_burial_mound, "interact"],
	]:
		var finder: Callable = entry[0]
		var method: String = entry[1]
		var node: Node3D = finder.call(px, pz, r)
		if node != null and node.has_method(method):
			node.call(method)
			return true
	return false

func _handle_interact() -> void:
	if _player == null:
		return
	# Downed & rescue (GID-105 / TID-389): frozen — cannot interact with anything.
	if _coop_downed:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z

	var downed_pid: int = coop_session._find_nearby_downed_peer(px, pz, IsoConst.INTERACT_RANGE)
	if downed_pid != -1:
		coop_session._request_revive(downed_pid)
		return

	var door := _find_nearby_door(px, pz, IsoConst.INTERACT_RANGE * 2.0)
	if not door.is_empty():
		var door_id: String = str(door.get("id", ""))
		if door_id == "house_door":
			_show_house_door_panel()
			return
		var target_map: String = door.get("target_map", "")
		var tdoor: String = door.get("target_door_id", "")
		AudioManager.play_sfx("door_enter")
		# Auto-dismount when leaving the overworld for any named map
		if SceneManager.save_manager.is_mounted and target_map != "main" and not target_map.is_empty():
			SceneManager.save_manager.auto_dismiss_mount()
		if target_map == "spire":
			_show_spire_entrance_panel()
		elif target_map.is_empty():
			# Co-op (GID-098): broadcast exit so all peers pop together.
			if _coop_active and _net_sync != null and not _coop_map_transitioning:
				_coop_map_transitioning = true
				_net_sync.rpc("recv_map_transition", "", "")
			SceneManager.exit_map()
		else:
			if SceneManager.save_manager.current_map == "madrian" and target_map == "maykalene":
				SceneManager.save_manager.set_story_flag("chapter1_left_madrian")
			# Co-op (GID-098): broadcast enter so all peers follow.
			if _coop_active and _net_sync != null and not _coop_map_transitioning:
				_coop_map_transitioning = true
				_net_sync.rpc("recv_map_transition", target_map, tdoor)
			SceneManager.enter_map(target_map, tdoor)
		return

	var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
		_open_chest(chest, px, pz)
		return

	if not _is_infinite and world_map != null:
		var cracked := world_map.find_nearby_cracked_wall(px, pz, IsoConst.INTERACT_RANGE)
		if cracked != Vector2i(-1, -1):
			_break_cracked_wall(cracked.x, cracked.y)
			return

	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	if not npc.is_empty():
		_interact_with_npc(npc)
		return

	if _try_simple_interaction(px, pz):
		return

	var mana_well_node := _find_nearby_mana_well(px, pz, IsoConst.INTERACT_RANGE)
	if mana_well_node != null:
		var wid: String = str(mana_well_node.get_meta("well_id", ""))
		if wid != "" and not SceneManager.save_manager.is_mana_well_collected(wid):
			SceneManager.save_manager.mark_mana_well_collected(wid)
			GameBus.essence_changed.emit(15)
			SceneManager.save_manager.essence += 15
			AudioManager.play_sfx("chest_open")
			mana_well_node.queue_free()
			_mana_well_nodes.erase(wid)
			GameBus.hud_message_requested.emit("Mana Well absorbed: +15 essence.")
		return

	var waystone := _find_nearby_waystone(px, pz, IsoConst.INTERACT_RANGE)
	if not waystone.is_empty():
		var wid: String = str(waystone.get("id", ""))
		if bool(waystone.get("active", false)):
			_open_fast_travel_panel()
		else:
			var wnode := _valid_node3d(_waystone_nodes.get(wid))
			if wnode != null and wnode.has_method("mark_activated"):
				wnode.mark_activated()
		return

	var mailbox := _find_nearby_mailbox(px, pz, IsoConst.INTERACT_RANGE)
	if not mailbox.is_empty():
		GameBus.mailbox_requested.emit()
		return

	var garden_plot := _find_nearby_garden_plot(px, pz, IsoConst.INTERACT_RANGE)
	if garden_plot != null:
		_show_garden_plot_panel(garden_plot)

# ── Spire entrance ─────────────────────────────────────────────────────────


## Opens a chest the player is standing at: springs the mimic ambush, or marks
## it open, syncs that to the party, and spawns its loot — or starts a
## need/greed roll instead when the session is in that mode.

	# Hostile entities are probed last, so anything peaceful in reach wins: you can
	# take a door, open a chest or read a scroll with an enemy standing next to you
	# instead of being forced into the fight. See INTERACT_PRIORITY.
	var blight_heart_node := _find_nearby_blight_heart(px, pz, IsoConst.INTERACT_RANGE)
	if blight_heart_node != null and blight_heart_node.has_method("engage"):
		blight_heart_node.engage()
		return

	var scout_ambush_node := _find_nearby_scout_ambush(px, pz, IsoConst.INTERACT_RANGE)
	if scout_ambush_node != null and scout_ambush_node.has_method("interact"):
		scout_ambush_node.interact()
		return

	var enemy := _find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
	if enemy != null and enemy.has_method("engage"):
		if enemy.get("enemy_data") != null:
			var etype: String = str(enemy.enemy_data.get("enemy_type", ""))
			if etype.begins_with("rival_"):
				var dlg: String = str(enemy.enemy_data.get("pre_battle_dialogue", ""))
				if dlg != "":
					_show_dialogue(dlg)
		enemy.engage()
		return

func _open_chest(chest: Dictionary, px: float, pz: float) -> void:
	if chest.get("is_mimic", false):
		AudioManager.play_sfx("enemy_alert")
		SceneManager.show_toast("It's a Mimic!", "Prepare for battle!")
		var mimic_deck: Array[String] = []
		mimic_deck.assign(EnemyRegistry.get_deck("mimic"))
		var mimic_data: Dictionary = {
			"id": str(chest.get("id", "mimic_0")),
			"x": chest.get("x", px),
			"z": chest.get("z", pz),
			"alive": true, "tracking": false,
			"enemy_type": "mimic",
			"enemy_deck": mimic_deck,
		}
		GameBus.enemy_engaged.emit(mimic_data)
		return
	chest["opened"] = true
	AudioManager.play_sfx("chest_open")
	if OS.has_feature("mobile") and bool(SceneManager.save_manager.get_setting("haptics", true)):
		Input.vibrate_handheld(40)
	var cid: String = str(chest.get("id", ""))
	SceneManager.save_manager.mark_chest_opened(cid)
	SceneManager.save_manager.increment_bounty_progress("open_chests", {})
	SceneManager.session_stats["chests_opened"] = int(SceneManager.session_stats.get("chests_opened", 0)) + 1
	var node := _valid_node3d(_chest_nodes.get(cid))
	if node and node.has_method("mark_opened"):
		node.mark_opened()
	# Co-op (GID-096): reflect + persist the open for all players (this opener
	# keeps the loot below; peers only see the chest flip open). Inert solo.
	coop_session._on_chest_opened_coop(cid)
	var chest_pos := Vector3(float(chest.get("x", px)), get_terrain_height(float(chest.get("x", px)), float(chest.get("z", pz))) + 0.25, float(chest.get("z", pz)))
	var chest_card_ids: Array[String] = []
	chest_card_ids.assign(chest.get("card_ids", []))
	# Tier: treasure rooms (dtr_) = 3, dungeon chests (dc_) = 2, world chests = 1
	var chest_tier: int = 1
	if cid.begins_with("dtr_"):
		chest_tier = 3
	elif cid.begins_with("dc_"):
		chest_tier = 2
	# Party loot rolls (GID-102 / TID-381): when need/greed mode is on for this
	# co-op session, the opener does NOT keep the loot below — the authority
	# opens a roll among present session members and grants it to the winner
	# instead. Default (first-opener-takes) and single-player are unchanged.
	if _coop_active and coop_activities._coop_loot_mode_is_need_greed():
		coop_activities._start_loot_roll(cid, chest_tier)
		return
	# 20% chance to drop a map fragment instead of normal loot (only if no active map)
	var sm := SceneManager.save_manager
	if _is_infinite and sm.active_treasure.is_empty() and randf() < 0.20:
		sm.collect_treasure_fragment()
	else:
		_spawn_card_items(chest_card_ids, chest_pos, chest_tier)
		_spawn_coin_piles(chest_pos)
		# Treasure rooms (dtr_ prefix) have a 40% weapon drop chance vs standard 15%
		var weapon_chance: float = 0.40 if cid.begins_with("dtr_") else 0.15
		_maybe_drop_equipment_from_chest(weapon_chance)
	return

## Runs the interaction for whichever NPC type the player is standing at.
func _interact_with_npc(npc: Dictionary) -> void:
	if str(npc.get("npc_type", "")) == "traveling_merchant":
		var stock: Array[String] = []
		var raw: Variant = npc.get("merchant_stock", [])
		if raw is Array:
			stock.assign(raw as Array)
		GameBus.traveling_shop_requested.emit(stock, 30)
		return
	if str(npc.get("npc_type", "")) == "merchant":
		GameBus.shop_requested.emit()
		return
	if str(npc.get("npc_type", "")) == "blacksmith":
		GameBus.blacksmith_requested.emit()
		return
	if str(npc.get("npc_type", "")) == "bounty_board":
		GameBus.bounty_board_requested.emit()
		return
	if str(npc.get("npc_type", "")) == "stable":
		_show_stable_panel()
		return
	if str(npc.get("npc_type", "")) == "duelist":
		_show_duel_offer_panel(npc)
		return
	if str(npc.get("npc_type", "")) == "rest_site":
		_dungeon_session_ui.show_rest_site_panel(npc)
		return
	if str(npc.get("npc_type", "")) == "event_room":
		_dungeon_session_ui.show_event_panel(npc)
		return
	if str(npc.get("npc_type", "")) == "bed":
		_handle_bed_interaction()
		return
	if str(npc.get("npc_type", "")) == "trophy_pedestal":
		_show_trophy_info(npc)
		return
	if str(npc.get("npc_type", "")) == "chapter1_king_eldar":
		_handle_king_eldar_interaction(npc)
		return
	if str(npc.get("npc_type", "")) == "stash_chest":
		coop_social._toggle_stash_overlay()
		return
	var nid: String = str(npc.get("id", ""))
	var nnode := _valid_node3d(_npc_nodes.get(nid))
	var dlg: String
	if nnode != null and nnode.has_method("get_dialogue"):
		dlg = nnode.get_dialogue()
		var fk: String = str(npc.get("flag_key", ""))
		if fk != "":
			SceneManager.save_manager.set_story_flag(fk)
	else:
		dlg = str(npc.get("dialogue", "..."))
	_show_dialogue(dlg)
	return

func _show_spire_entrance_panel() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var is_active: bool = SceneManager.save_manager.is_spire_active()
	var curr_floor: int = 1
	if is_active:
		curr_floor = int(SceneManager.save_manager.get_spire_run().get("floor", 1))

	var modal: Dictionary = _build_modal(0.64, 0.40, Color(0.06, 0.04, 0.14, 0.96), 0.022)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := _UiUtil.make_label("The Endless Spire", int(vh * 0.038), Color(0.85, 0.50, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var desc := Label.new()
	if is_active:
		desc.text = "A run is in progress — Floor %d.\nResume your climb?" % curr_floor
	else:
		desc.text = "Your deck stays behind.\nDraft new cards as you climb — or fall."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", int(vh * 0.026))
	desc.modulate = Color(0.85, 0.85, 0.85)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var row := _UiUtil.make_hbox(int(vh * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var enter_btn := _UiUtil.make_button("Resume (Floor %d)" % curr_floor if is_active else "Enter", Vector2(vh * 0.20, vh * 0.07), int(vh * 0.028))
	enter_btn.modulate = Color(0.85, 0.50, 1.0)
	enter_btn.pressed.connect(func() -> void:
		layer.queue_free()
		SceneManager.enter_spire()
	)
	row.add_child(enter_btn)

	var leave_btn := _UiUtil.make_button("Leave", Vector2(vh * 0.16, vh * 0.07), int(vh * 0.028), func() -> void: layer.queue_free(), row)

# ── Player Home ────────────────────────────────────────────────────────────

const _HOUSE_PRICE: int = 500

func _show_house_door_panel() -> void:
	var sm := SceneManager.save_manager
	if sm.home_owned:
		AudioManager.play_sfx("door_enter")
		SceneManager.enter_map("player_home", "exit_door")
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	var modal: Dictionary = _build_modal(0.60, 0.32, Color(0.06, 0.04, 0.14, 0.96), 0.015, 0.02)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]

	var title := _UiUtil.make_label("House For Sale", int(vh * 0.035), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var desc := _UiUtil.make_label("Purchase this cozy home for %d coins.\nCurrent balance: %d coins." % [_HOUSE_PRICE, sm.coins], int(vh * 0.027), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var hbox := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var buy_btn := _UiUtil.make_button("Buy (%d coins)" % _HOUSE_PRICE, Vector2(vh * 0.26, vh * 0.065), int(vh * 0.027), Callable(), hbox)
	buy_btn.disabled = sm.coins < _HOUSE_PRICE

	var cancel_btn := _UiUtil.make_button("Cancel", Vector2(vh * 0.16, vh * 0.065), int(vh * 0.027), Callable(), hbox)

	cancel_btn.pressed.connect(func() -> void: layer.queue_free())
	buy_btn.pressed.connect(func() -> void:
		sm.add_coins(-_HOUSE_PRICE)
		sm.home_owned = true
		sm.mark_dirty()
		layer.queue_free()
		AudioManager.play_sfx("door_enter")
		SceneManager.enter_map("player_home", "exit_door")
	)

const MOUNT_PRICE: int = 750
const MOUNT_LEVEL_REQ: int = 10

func _toggle_mount() -> void:
	var sm := SceneManager.save_manager
	if sm.current_map != "main":
		return
	if sm.owned_mounts.size() == 0:
		return
	if sm.is_mounted:
		sm.dismiss_mount()
	else:
		sm.summon_mount(str(sm.owned_mounts[0]))

func _on_enemy_engaged_for_mount(_enemy_data: Dictionary) -> void:
	if SceneManager.save_manager.is_mounted:
		SceneManager.save_manager.auto_dismiss_mount()

## Music track for the current non-infinite (named) map (BID-048). Data-driven:
## prefers the map's own MapData.music_track override (threaded through
## WorldMap.load_from_resource()); falls back to dungeon.ogg only for actual
## procedurally generated dungeons/spire floors, and to a peaceful default for
## every other (hand-authored town/story) named map.
func _named_map_music_track() -> String:
	if world_map != null and world_map.music_track != "":
		return world_map.music_track
	if map_name.begins_with("dungeon_") or map_name.begins_with("spire_floor_"):
		return _DUNGEON_MUSIC
	return _TOWN_MUSIC_DEFAULT

func _on_battle_won(_result: Dictionary) -> void:
	# Co-op (GID-096): a victory over a shared enemy persists its defeat into the
	# session file (stays gone after reconnect). A loss isn't persisted, so the
	# enemy returns on reconnect — matching single-player. Inert single-player.
	coop_session._coop_persist_enemy_defeat()
	if _is_infinite and _current_biome >= 0:
		AudioManager.play_music(_BIOME_MUSIC[_current_biome])
		AudioManager.set_ambience(_current_biome)
		const BountyGen_cls = preload("res://game_logic/BountyGen.gd")
		if _current_biome < BountyGen_cls.BIOME_NAMES.size():
			var biome_name: String = BountyGen_cls.BIOME_NAMES[_current_biome]
			SceneManager.save_manager.increment_bounty_progress("defeat_in_biome", {"biome_name": biome_name})
	else:
		AudioManager.play_music(_named_map_music_track())
	var sm := SceneManager.save_manager
	if sm.active_mount != "" and sm.current_map == "main":
		sm.summon_mount(sm.active_mount)

func _on_coins_changed(n: int) -> void:
	_coin_label.text = "Coins: %d" % n

func _on_xp_changed(_xp: int, _level: int) -> void:
	_world_hud.refresh_xp_bar()
	_world_hud.update_xp_label()

func _show_stable_panel() -> void:
	var sm := SceneManager.save_manager
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	if sm.owned_mounts.has("stable_horse"):
		_show_dialogue("You already own a Stable Horse!")
		return

	var modal: Dictionary = _build_modal(0.60, 0.36, Color(0.06, 0.04, 0.14, 0.96), 0.015, 0.02)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]

	var title := _UiUtil.make_label("Madrian Stables", int(vh * 0.035), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var mount: Dictionary = MountRegistry.get_mount("stable_horse")
	var desc := Label.new()
	desc.text = "%s\n  Speed: ×%.1f   Price: %d coins" % [
		str(mount.get("display_name", "Stable Horse")),
		float(mount.get("speed_multiplier", 2.0)),
		MOUNT_PRICE,
	]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", int(vh * 0.027))
	vbox.add_child(desc)

	var level_lbl := Label.new()
	var level_ok: bool = sm.level >= MOUNT_LEVEL_REQ
	var coins_ok: bool = sm.coins >= MOUNT_PRICE
	if not level_ok:
		level_lbl.text = "Requires level %d (you are level %d)" % [MOUNT_LEVEL_REQ, sm.level]
		level_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	elif not coins_ok:
		level_lbl.text = "Insufficient coins (need %d, have %d)" % [MOUNT_PRICE, sm.coins]
		level_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		level_lbl.text = "Balance: %d coins" % sm.coins
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", int(vh * 0.025))
	vbox.add_child(level_lbl)

	var hbox := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var buy_btn := _UiUtil.make_button("Buy (%d coins)" % MOUNT_PRICE, Vector2(vh * 0.28, vh * 0.065), int(vh * 0.027), Callable(), hbox)
	buy_btn.disabled = not level_ok or not coins_ok

	var cancel_btn := _UiUtil.make_button("Cancel", Vector2(vh * 0.16, vh * 0.065), int(vh * 0.027), Callable(), hbox)

	cancel_btn.pressed.connect(func() -> void: layer.queue_free())
	buy_btn.pressed.connect(func() -> void:
		sm.add_coins(-MOUNT_PRICE)
		sm.owned_mounts.append("stable_horse")
		sm.summon_mount("stable_horse")
		layer.queue_free()
		_world_hud.update_mount_btn()
		_show_dialogue("You purchased a Stable Horse! Press T or tap Mount to ride.")
	)

func _handle_bed_interaction() -> void:
	var sm := SceneManager.save_manager
	sm.set_respawn_point("player_home", float(50) * IsoConst.TILE_SIZE, float(53) * IsoConst.TILE_SIZE)
	sm.time_of_day = 0.25
	_show_dialogue("You rest peacefully at home. Respawn point set!")

func _spawn_player_home_trophies() -> void:
	var sm := SceneManager.save_manager
	var trophy_ids: Array[String] = ["champion", "spire_7", "first_boss"]
	var tile_positions: Array[Vector2i] = [
		Vector2i(44, 49),
		Vector2i(47, 49),
		Vector2i(50, 49),
	]
	for i: int in range(trophy_ids.size()):
		var tid: String = trophy_ids[i]
		var trophy: Dictionary = TrophyRegistry.get_trophy(tid)
		if trophy.is_empty():
			continue
		var earned: bool = TrophyRegistry.is_earned(tid, sm)
		var tp: Vector2i = tile_positions[i]
		var wx: float = float(tp.x) * IsoConst.TILE_SIZE
		var wz: float = float(tp.y) * IsoConst.TILE_SIZE
		var terrain_y: float = get_terrain_height(wx, wz)
		var npc_data: Dictionary = {
			"id": "trophy_" + tid,
			"x": wx,
			"z": wz,
			"npc_type": "trophy_pedestal",
			"trophy_id": tid,
			"trophy_earned": earned,
			"dialogue": trophy.get("display_name", tid) + (": " + trophy.get("description", "") if earned else " (not yet earned)"),
			"flag_key": "",
		}
		var pedestal := _make_trophy_pedestal(earned, trophy.get("display_name", tid))
		pedestal.position = Vector3(wx, terrain_y, wz)
		_entity_root.add_child(pedestal)
		register_npc("trophy_" + tid, pedestal, npc_data)

func _make_trophy_pedestal(earned: bool, display_name: String) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.65, 0.2) if earned else Color(0.4, 0.4, 0.4)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.5, 0.9)
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = mat
	base.position = Vector3(0.0, 0.25, 0.0)
	root.add_child(base)

	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.5, 0.5, 0.5)
	var top := MeshInstance3D.new()
	top.mesh = top_mesh
	top.material_override = mat
	top.position = Vector3(0.0, 0.75, 0.0)
	root.add_child(top)

	root.add_child(_SpriteRegistry.make_name_label(display_name if earned else "???", Color(1.0, 0.9, 0.3) if earned else Color(0.5, 0.5, 0.5), 1.4, 28, 0.022))

	return root

func _show_trophy_info(npc: Dictionary) -> void:
	var dlg: String = str(npc.get("dialogue", "A mysterious trophy."))
	_show_dialogue(dlg)

# ── Garden plots ────────────────────────────────────────────────────────────

func _spawn_player_home_garden() -> void:
	_garden_plot_nodes.clear()
	var tile_positions: Array[Vector2i] = [
		Vector2i(52, 54),
		Vector2i(55, 54),
		Vector2i(58, 54),
	]
	for i: int in range(tile_positions.size()):
		var tp: Vector2i = tile_positions[i]
		var wx: float = float(tp.x) * IsoConst.TILE_SIZE
		var wz: float = float(tp.y) * IsoConst.TILE_SIZE
		var terrain_y: float = get_terrain_height(wx, wz)
		var plot: Node3D = _GardenPlotScript.new()
		plot.init_from_data({"plot_idx": i})
		plot.position = Vector3(wx, terrain_y, wz)
		_entity_root.add_child(plot)
		_garden_plot_nodes.append(plot)

func _find_nearby_garden_plot(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_garden_plot_nodes, px, pz, range_dist)

func _show_garden_plot_panel(plot: Node3D) -> void:
	var sm := SceneManager.save_manager
	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var font_size: int = int(vh * 0.03)
	var btn_h: float = vh * 0.07

	var panel := PanelContainer.new()
	panel.position = Vector2(vw * 0.15, vh * 0.2)
	panel.custom_minimum_size = Vector2(vw * 0.7, vh * 0.5)
	_hud.add_child(panel)

	var vbox := _UiUtil.make_vbox(int(vh * 0.012), panel)

	var title := _UiUtil.make_label("Garden Plot %d" % (int(plot.plot_idx) + 1), int(vh * 0.045), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var session_mode: bool = bool(plot.session_mode)
	var plot_data: Dictionary = plot.get_plot_data()
	var stage: int = plot.get_growth_stage() if not plot_data.is_empty() else 0

	if plot_data.is_empty():
		# Empty plot — seed picker
		var info := _UiUtil.make_label("Choose a seed to plant:", int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

		var has_any_seed: bool = false
		for seed_id in GardenDefs.SEEDS:
			var seed_count: int = int(sm.seeds.get(seed_id, 0))
			var sdata: Dictionary = GardenDefs.SEEDS[seed_id]
			var sname: String = str(sdata.get("display_name", seed_id))
			var days: int = int(sdata.get("growth_days", 2))
			var row := _UiUtil.make_hbox(0, vbox)
			var lbl := Label.new()
			# The co-op guildhall garden is free to plant (no session seed
			# economy is modeled, TID-393) — the owned-count only applies solo.
			lbl.text = ("%s — %d days" % [sname, days]) if session_mode \
				else "%s — %d days  (owned: %d)" % [sname, days, seed_count]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", font_size)
			row.add_child(lbl)
			var plant_btn := _UiUtil.make_button("Plant", Vector2(vh * 0.14, btn_h), int(font_size))
			plant_btn.disabled = false if session_mode else seed_count <= 0
			var captured_seed_id: String = seed_id
			var captured_sname: String = sname
			if session_mode:
				plant_btn.pressed.connect(func() -> void:
					_submit_session_plant(int(plot.plot_idx), captured_seed_id)
					SceneManager.show_toast("Planted!", captured_sname + " planted.")
					panel.queue_free()
				)
			else:
				plant_btn.pressed.connect(func() -> void:
					if sm.remove_seeds(captured_seed_id, 1):
						sm.set_plot(plot.plot_idx, captured_seed_id, sm.days_elapsed)
						plot.refresh_visual()
						SceneManager.show_toast("Planted!", captured_sname + " planted.")
						panel.queue_free()
				)
			row.add_child(plant_btn)
			if session_mode or seed_count > 0:
				has_any_seed = true

		if not has_any_seed:
			var hint := _UiUtil.make_label("No seeds — buy some from a merchant.", int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

	elif stage < 3:
		# Growing — show info
		var seed_id: String = str(plot_data.get("seed_id", ""))
		var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
		var sname: String = str(sdata.get("display_name", seed_id))
		var growth_days: int = int(sdata.get("growth_days", 2))
		var planted_day: int = int(plot_data.get("planted_day", 0))
		var current_days: int = coop_session._coop_current_days_elapsed() if session_mode else sm.days_elapsed
		var days_left: int = max(0, planted_day + growth_days - current_days)
		var info := _UiUtil.make_label("%s growing — ready in %d day(s)" % [sname, days_left], int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	else:
		# Mature — show harvest button
		var seed_id: String = str(plot_data.get("seed_id", ""))
		var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
		var sname: String = str(sdata.get("display_name", seed_id))
		var plant_id: String = str(sdata.get("plant_id", ""))
		var yield_count: int = int(sdata.get("yield", 1))
		var info := _UiUtil.make_label("%s is ready to harvest!" % sname, int(font_size), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)

		var harvest_btn := _UiUtil.make_button("Harvest (%d× %s)" % [yield_count, sname], Vector2(0, btn_h), int(font_size))
		if session_mode:
			harvest_btn.pressed.connect(func() -> void:
				_submit_session_harvest(int(plot.plot_idx))
				SceneManager.show_toast("Harvested!", "%d× %s" % [yield_count, sname])
				panel.queue_free()
			)
		else:
			harvest_btn.pressed.connect(func() -> void:
				sm.add_plants(plant_id, yield_count)
				sm.clear_plot(plot.plot_idx)
				GameBus.plant_harvested.emit(plot.plot_idx, yield_count)
				SceneManager.show_toast("Harvested!", "%d× %s" % [yield_count, sname])
				panel.queue_free()
			)
		vbox.add_child(harvest_btn)

	var cancel_btn := _UiUtil.make_button("Close", Vector2(0, btn_h), int(font_size), func() -> void: panel.queue_free(), vbox)

# ── Party Guildhall furnishings (GID-106 / TID-393) ──────────────────────────
# Trophies, garden, and a stash chest, furnishing the otherwise-empty guildhall
# (TID-392). All spawned only when map_name == "guildhall" and
# NetworkManager.is_active() (see _ready()'s named-map branch).

## Up to 3 pedestals from the already-synced _pve_leaderboards["coop_clears"]
## cache (party-size clears leaderboard, TID-391) — no new RPC needed. A slot
## with no entry is skipped entirely (dynamic top-N, not a fixed earned/unearned
## predicate list like the player-home trophies).
func _spawn_guildhall_trophies() -> void:
	var rows: Array = _pve_leaderboards.get("coop_clears", [])
	var tile_positions: Array[Vector2i] = [
		Vector2i(44, 50),
		Vector2i(50, 50),
		Vector2i(56, 50),
	]
	for i: int in range(mini(rows.size(), tile_positions.size())):
		var row: Dictionary = rows[i]
		var name_str: String = str(row.get("name", "A party"))
		var value: int = int(row.get("value", 0))
		var day: int = int(row.get("day", 0))
		var display_name: String = "%s's Clear — Party of %d" % [name_str, value]
		var tp: Vector2i = tile_positions[i]
		var wx: float = float(tp.x) * IsoConst.TILE_SIZE
		var wz: float = float(tp.y) * IsoConst.TILE_SIZE
		var terrain_y: float = get_terrain_height(wx, wz)
		var npc_data: Dictionary = {
			"id": "guildhall_trophy_%d" % i,
			"x": wx, "z": wz,
			"npc_type": "trophy_pedestal",
			"dialogue": "%s (Day %d)" % [display_name, day],
			"flag_key": "",
		}
		var pedestal := _make_trophy_pedestal(true, display_name)
		pedestal.position = Vector3(wx, terrain_y, wz)
		_entity_root.add_child(pedestal)
		register_npc("guildhall_trophy_%d" % i, pedestal, npc_data)

## 3 session-scoped garden plots (session_mode = true). The host builds its
## cache directly from SessionStore; a client requests a fresh snapshot since
## SessionStore can't be read locally (see class doc comment on
## _guildhall_garden_cache).
func _spawn_guildhall_garden() -> void:
	_garden_plot_nodes.clear()
	var tile_positions: Array[Vector2i] = [
		Vector2i(46, 54),
		Vector2i(50, 54),
		Vector2i(54, 54),
	]
	for i: int in range(tile_positions.size()):
		var tp: Vector2i = tile_positions[i]
		var wx: float = float(tp.x) * IsoConst.TILE_SIZE
		var wz: float = float(tp.y) * IsoConst.TILE_SIZE
		var terrain_y: float = get_terrain_height(wx, wz)
		var plot: Node3D = _GardenPlotScript.new()
		plot.init_from_data({"plot_idx": i})
		plot.session_mode = true
		plot.position = Vector3(wx, terrain_y, wz)
		_entity_root.add_child(plot)
		_garden_plot_nodes.append(plot)
	if NetworkManager.is_host():
		if SessionStore.is_open():
			var st = SessionStore.get_state()
			if st != null:
				var gh: Dictionary = st.guildhall_state
				_guildhall_garden_cache = {
					"plots": (gh.get("garden_plots", []) as Array).duplicate(true),
					"plants": (gh.get("plants", {}) as Dictionary).duplicate(true),
				}
		_refresh_guildhall_garden_visuals()
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_guildhall_garden_request")

## A procedural chest entity that routes to the existing party stash overlay
## (TID-376) — a physical anchor for a resource that's already always
## reachable via the HUD, reinforcing that it's shared. No new RPC: opening
## the overlay is a pure local UI action.
func _spawn_guildhall_stash_chest() -> void:
	var tx: int = 50
	var tz: int = 48
	var wx: float = float(tx) * IsoConst.TILE_SIZE
	var wz: float = float(tz) * IsoConst.TILE_SIZE
	var terrain_y: float = get_terrain_height(wx, wz)

	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.38, 0.15)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.55, 0.6)
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = mat
	base.position = Vector3(0.0, 0.275, 0.0)
	root.add_child(base)

	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.95, 0.2, 0.65)
	var lid := MeshInstance3D.new()
	lid.mesh = lid_mesh
	lid.material_override = mat
	lid.position = Vector3(0.0, 0.65, 0.0)
	root.add_child(lid)

	root.add_child(_SpriteRegistry.make_name_label("Guild Stash", Color(0.95, 0.85, 0.5), 1.1, 26, 0.020))

	root.position = Vector3(wx, terrain_y, wz)
	_entity_root.add_child(root)
	_guildhall_stash_chest_node = root
	register_npc("guildhall_stash_chest", root, {
		"id": "guildhall_stash_chest",
		"x": wx, "z": wz,
		"npc_type": "stash_chest",
		"dialogue": "",
		"flag_key": "",
	})

## Pushes the current cache into every spawned plot (session_mode) node.
func _refresh_guildhall_garden_visuals() -> void:
	var plots: Array = _guildhall_garden_cache.get("plots", [])
	var days: int = coop_session._coop_current_days_elapsed()
	for i in range(_garden_plot_nodes.size()):
		var plot: Node3D = _garden_plot_nodes[i]
		if not is_instance_valid(plot) or not plot.has_method("set_session_state"):
			continue
		var data: Dictionary = plots[i] if i < plots.size() and plots[i] is Dictionary else {}
		plot.set_session_state(data, days)

## Host: a client asked for a fresh guildhall garden snapshot (entering the map).
func _on_guildhall_garden_request_submitted(sender: int) -> void:
	_broadcast_guildhall_garden(sender)

## Host-only: push the current guildhall garden state to one peer (0 = all).
func _broadcast_guildhall_garden(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var gh: Dictionary = st.guildhall_state
	var payload: Dictionary = {
		"plots": (gh.get("garden_plots", []) as Array).duplicate(true),
		"plants": (gh.get("plants", {}) as Dictionary).duplicate(true),
	}
	_guildhall_garden_cache = payload
	if target_peer == 0:
		_net_sync.rpc("recv_guildhall_garden_update", payload)
	else:
		_net_sync.rpc_id(target_peer, "recv_guildhall_garden_update", payload)
	_refresh_guildhall_garden_visuals()

## Any peer: receive a guildhall garden snapshot and refresh plot visuals.
func _on_guildhall_garden_update_received(payload: Dictionary) -> void:
	_guildhall_garden_cache = payload
	_refresh_guildhall_garden_visuals()

## Local player (any peer) picked a seed for an empty plot.
func _submit_session_plant(plot_idx: int, seed_id: String) -> void:
	if NetworkManager.is_host():
		_on_session_plant_submitted(multiplayer.get_unique_id(), plot_idx, seed_id)
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_session_plant", plot_idx, seed_id)

## Host: plant a seed in the shared guildhall garden (free — no session seed
## economy is modeled, TID-393 Plan Notes) and broadcast the result.
func _on_session_plant_submitted(_sender: int, plot_idx: int, seed_id: String) -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	if not GardenDefs.SEEDS.has(seed_id):
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var gh: Dictionary = st.guildhall_state
	var plots: Array = gh.get("garden_plots", [])
	if plot_idx < 0 or plot_idx >= plots.size():
		return
	if not (plots[plot_idx] as Dictionary).is_empty():
		return  # already planted — ignore a stale/duplicate submit
	plots[plot_idx] = {"seed_id": seed_id, "planted_day": coop_session._coop_current_days_elapsed()}
	gh["garden_plots"] = plots
	st.guildhall_state = gh
	SessionStore.mark_dirty()
	_broadcast_guildhall_garden()

## Local player (any peer) harvested a mature plot.
func _submit_session_harvest(plot_idx: int) -> void:
	if NetworkManager.is_host():
		_on_session_harvest_submitted(multiplayer.get_unique_id(), plot_idx)
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_session_harvest", plot_idx)

## Host: harvest a mature shared guildhall plot into the session's dedicated
## `plants` pool (not the party stash — see TID-393 Plan Notes) and broadcast.
func _on_session_harvest_submitted(_sender: int, plot_idx: int) -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var gh: Dictionary = st.guildhall_state
	var plots: Array = gh.get("garden_plots", [])
	if plot_idx < 0 or plot_idx >= plots.size():
		return
	var plot_data: Dictionary = plots[plot_idx]
	if plot_data.is_empty():
		return
	var seed_id: String = str(plot_data.get("seed_id", ""))
	var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
	if sdata.is_empty():
		return
	var growth_days: int = int(sdata.get("growth_days", 2))
	var planted_day: int = int(plot_data.get("planted_day", 0))
	var stage: int = GardenDefs.growth_stage(planted_day, growth_days, coop_session._coop_current_days_elapsed())
	if stage < 3:
		return  # not mature yet — ignore a stale/duplicate submit
	var plant_id: String = str(sdata.get("plant_id", ""))
	var yield_count: int = int(sdata.get("yield", 1))
	var plants: Dictionary = gh.get("plants", {})
	plants[plant_id] = int(plants.get(plant_id, 0)) + yield_count
	gh["plants"] = plants
	plots[plot_idx] = {}
	gh["garden_plots"] = plots
	st.guildhall_state = gh
	SessionStore.mark_dirty()
	_broadcast_guildhall_garden()

# ── Dialogue ───────────────────────────────────────────────────────────────

func _show_dialogue(text: String) -> void:
	_world_hud.show_dialogue(text)

## Chapter 1 ending trigger (GID-108 / TID-405). King Eldar's dialogue is entirely
## custom (npc_type "chapter1_king_eldar" bypasses the generic MapNpc flag_key
## auto-set path — see WorldScene._handle_interact()) because it needs four
## states the 2-state MapNpc schema can't express: first meeting / council in
## session / ending trigger / post-ending epilogue.
func _handle_king_eldar_interaction(npc: Dictionary) -> void:
	var sm := SceneManager.save_manager
	if sm.get_story_flag("chapter1_complete"):
		# Chapter 2 beat 1 — the council's charge (GID-108 / TID-407): fires once,
		# the first time King Eldar is spoken to after the Chapter 1 ending.
		if not sm.get_story_flag("chapter2_charged"):
			sm.set_story_flag("chapter2_charged")
			_show_dialogue("Maiteln, Saimtar — you two ride west. Past Larik, to Lord Marsax. Ride swift, and ride true.")
			return
		_show_dialogue("The realm owes its warning to a servant boy from Larik. Remember that, all of you.")
		return
	if not sm.get_story_flag("chapter1_temple_council"):
		sm.set_story_flag("chapter1_temple_council")
		_show_dialogue(str(npc.get("dialogue", "...")))
		return
	if sm.get_story_flag("chapter1_spoke_queen") and sm.get_story_flag("chapter1_spoke_scargroth"):
		_trigger_chapter1_ending()
		return
	_show_dialogue("The council has heard the prophecy. We act at dawn.")

## Sets chapter1_complete and shows the three-page ending narration overlay.
## No scene transition — the player is already in the world (blancogov_temple);
## "return to the world as a playable epilogue" just means closing the overlay.
## Setting the flag fires _refresh_maiteln_presence() for free via the existing
## _on_local_story_flag_set hook (TID-403), hiding the follower with no new code.
func _trigger_chapter1_ending() -> void:
	SceneManager.save_manager.set_story_flag("chapter1_complete")
	var pages: Array[String] = [
		"The council resolves — the old alliance is re-sworn, riders will carry the warning to every lord.",
		"Maiteln, quietly proud, tells Saimtar he has earned his place at his side.",
		"Scargroth pulls Saimtar aside: \"There is a name from Larik in the old registers you should see.\"",
	]
	GameBus.narration_overlay_requested.emit(pages, "", "")

## Co-op (GID-108 / TID-408, design rule 3): the sole handler for narration
## overlays. Shows the overlay locally for every peer and, only for the peer
## whose local trigger caused it (i.e. not a co-op-received replay), broadcasts
## it to the rest of the party so everyone sees the same cinematic beat at the
## same time. Late-join/absent members simply never receive it and inherit the
## shared completion flag on the next story-flag sync instead (rule 1).
func _on_narration_overlay_requested(pages: Array, title: String, completion_flag: String) -> void:
	_show_narration_overlay(pages, title, completion_flag)
	if _coop_active and _net_sync != null and NetworkManager.is_active():
		_net_sync.rpc("recv_narration_overlay", pages, title, completion_flag)

## Called by NetSync when the authority's narration broadcast arrives.
func _on_narration_overlay_received(pages: Array, title: String, completion_flag: String) -> void:
	if not _coop_active:
		return
	_show_narration_overlay(pages, title, completion_flag)

func _show_narration_overlay(pages: Array, title: String, completion_flag: String) -> void:
	var typed_pages: Array[String] = []
	typed_pages.assign(pages)
	var overlay := _ChapterEndingOverlay.new()
	if title.is_empty():
		overlay.setup(typed_pages)
	else:
		overlay.setup(typed_pages, title)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 999
	get_tree().root.add_child(layer)
	layer.add_child(overlay)
	overlay.closed.connect(func() -> void:
		layer.queue_free()
		if not completion_flag.is_empty():
			SceneManager.save_manager.set_story_flag(completion_flag))

func _show_duel_offer_panel(npc: Dictionary) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var npc_id: String = str(npc.get("id", ""))
	var enemy_id: String = str(npc.get("duelist_enemy_id", "duelist_novice"))
	var wager: int = int(npc.get("wager_coins", 10))
	var is_rematch: bool = SceneManager.save_manager.defeated_duelists.has(npc_id)
	var player_coins: int = SceneManager.save_manager.coins
	var champion_reward: String = str(npc.get("champion_reward_card", ""))
	if is_rematch:
		wager = max(1, wager / 2)

	# Champion gate: count required duelists not yet beaten.
	var req_ids: Variant = npc.get("required_duelist_ids")
	var gate_remaining: int = 0
	if req_ids is PackedStringArray:
		var defeated: Array[String] = SceneManager.save_manager.defeated_duelists
		for rid: String in (req_ids as PackedStringArray):
			if not defeated.has(rid):
				gate_remaining += 1

	var modal: Dictionary = _build_modal(0.6, 0.38, Color(0.08, 0.08, 0.18, 0.96), 0.022, 0.03, 0.5)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var offer_lbl := Label.new()
	if gate_remaining > 0:
		offer_lbl.text = "I only duel proven players. Beat the others in town first. (%d more to go.)" % gate_remaining
	elif player_coins < wager:
		offer_lbl.text = "Come back when you can cover the wager."
	elif is_rematch:
		offer_lbl.text = "A rematch? Wager: %d coins." % wager
	else:
		offer_lbl.text = "Care for a friendly duel?\nWager: %d coins." % wager
	offer_lbl.add_theme_font_size_override("font_size", int(vh * 0.028))
	offer_lbl.add_theme_color_override("font_color", Color.WHITE)
	offer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(offer_lbl)

	var row := _UiUtil.make_hbox(int(vh * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	if gate_remaining == 0 and player_coins >= wager:
		var duel_btn := _UiUtil.make_button("Duel!", Vector2(vh * 0.18, vh * 0.07), int(vh * 0.028))
		duel_btn.pressed.connect(func() -> void:
			layer.queue_free()
			var enemy_deck: Array[String] = EnemyRegistry.get_deck(enemy_id)
			var enemy_data_dict: Dictionary = {
				"enemy_type": enemy_id,
				"enemy_deck": enemy_deck,
				"duel_npc_id": npc_id,
				"champion_reward_card": champion_reward,
			}
			GameBus.duel_requested.emit(enemy_data_dict, wager)
		)
		row.add_child(duel_btn)

	var decline_btn := _UiUtil.make_button("Decline", Vector2(vh * 0.18, vh * 0.07), int(vh * 0.028), func() -> void: layer.queue_free(), row)

## The lightweight accept/decline prompt the co-op request panels use: a
## CanvasLayer at `layer_index` on this scene, a dimming backdrop, and a
## content-hugging centred panel. Returns {"layer", "vbox"} — free the layer to
## dismiss. Distinct from _build_modal, which sizes its panel to the viewport.
func _build_prompt(layer_index: int, sep_frac: float) -> Dictionary:
	var vh: float = get_viewport().get_visible_rect().size.y
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	return {"layer": layer, "vbox": _UiUtil.make_vbox(int(vh * sep_frac), panel)}

## The standard centred modal used by the world interaction prompts: a
## CanvasLayer above the HUD, a dimming backdrop, a dark rounded panel sized to
## `w_frac` x `h_frac` of the viewport, and the margin + VBox body the caller
## fills. Returns {"layer", "backdrop", "panel", "vbox"} — free the layer to
## dismiss the modal.
func _build_modal(w_frac: float, h_frac: float, bg: Color, sep_frac: float,
		margin_v_frac: float = 0.03, dim: float = 0.55) -> Dictionary:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, dim)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * w_frac
	var panel_h: float = vh * h_frac
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(bg, 10))
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := _UiUtil.make_margin(int(vh * 0.03), int(vh * margin_v_frac),
		int(vh * 0.03), int(vh * margin_v_frac), panel)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	return {
		"layer": layer,
		"backdrop": backdrop,
		"panel": panel,
		"vbox": _UiUtil.make_vbox(int(vh * sep_frac), margin),
	}

func _show_tip(text: String) -> void:
	_world_hud.show_tip(text)

func _on_scroll_collected(scroll_id: String) -> void:
	var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
	var title: String = scroll.get("title", scroll_id) if not scroll.is_empty() else scroll_id
	_show_tip("Lore scroll found: " + title)
	# Chapter 2 beats 2 & 5 (GID-108 / TID-407): these two scrolls are also story
	# beats. A generic flag-on-collect field doesn't exist on MapScroll/
	# ScrollRegistry — two one-off hooks don't justify adding one.
	if scroll_id == "scroll_larik_letter":
		SceneManager.save_manager.set_story_flag("chapter2_found_letter")
	elif scroll_id == "scroll_traitor_seal":
		SceneManager.save_manager.set_story_flag("chapter2_traitor_seal")
	if SceneManager.save_manager.collected_scrolls.size() >= ScrollRegistry.SCROLL_COUNT:
		GameBus.all_scrolls_collected.emit()
	# Co-op (GID-108 / TID-408, design rule 5): mirror the GID-096 shared-chest
	# model — the collector's pickup (this tip/flags/completion check) is granted
	# to every session member. Skipped when this call is itself the result of
	# applying a co-op-received pickup, to avoid re-broadcasting a broadcast.
	if not _coop_scroll_syncing:
		_broadcast_scroll_collected_coop(scroll_id)

func _broadcast_scroll_collected_coop(scroll_id: String) -> void:
	if not _coop_active or _net_sync == null or not NetworkManager.is_active():
		return
	if NetworkManager.is_host():
		_coop_record_scroll_collected(scroll_id)
		_net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_SCROLL_COLLECTED, scroll_id))
	else:
		_net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_SCROLL_COLLECTED, scroll_id))

## Host-only: persist a collected scroll into the session file.
func _coop_record_scroll_collected(scroll_id: String) -> void:
	_coop_collected_scrolls[scroll_id] = true
	var st = SessionStore.get_state()
	if st != null and not st.collected_scrolls.has(scroll_id):
		st.collected_scrolls.append(scroll_id)
		SessionStore.mark_dirty()

## Apply a scroll pickup that originated elsewhere (a teammate, or a snapshot
## replay) to this peer's own SaveManager, re-running the same tip/flag/
## completion logic in _on_scroll_collected as a real local pickup would.
func _coop_apply_scroll_collected(scroll_id: String) -> void:
	_coop_collected_scrolls[scroll_id] = true
	if SceneManager.save_manager.collected_scrolls.has(scroll_id):
		return
	_coop_scroll_syncing = true
	SceneManager.save_manager.mark_scroll_collected(scroll_id)
	GameBus.story_scroll_collected.emit(scroll_id)
	_coop_scroll_syncing = false

# ── Card item spawning ──────────────────────────────────────────────────────

func _spawn_card_items(card_ids: Array[String], origin: Vector3, chest_tier: int = 1) -> void:
	const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
	var rng := RandomNumberGenerator.new()
	for i: int in range(card_ids.size()):
		var cid: String = str(card_ids[i])
		var rarity: String = CardDropUtil.effective_rarity(cid, CardDropUtil.roll_rarity(chest_tier))
		var stats: Dictionary = CardDropUtil.roll_stats(cid, rarity)
		var angle: float = (float(i) / float(max(card_ids.size(), 1))) * TAU + rng.randf_range(-0.4, 0.4)
		var dist: float = rng.randf_range(1.0, 1.8)
		var land_pos := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var item: Node3D = _WorldItemScene.instantiate()
		_entity_root.add_child(item)
		if item.has_method("setup"):
			item.setup(cid, origin, land_pos, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))

func _spawn_coin_piles(origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	var pile_count: int = rng.randi_range(3, 5)
	for i: int in range(pile_count):
		var angle: float = (float(i) / float(pile_count)) * TAU + rng.randf_range(-0.5, 0.5)
		var dist: float = rng.randf_range(0.8, 2.0)
		var land_pos := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var amount: int = rng.randi_range(5, 20)
		var item: Node3D = _WorldItemScene.instantiate()
		_entity_root.add_child(item)
		if item.has_method("setup_coin"):
			item.setup_coin(amount, origin, land_pos)

func _maybe_drop_equipment_from_chest(chance: float = 0.15) -> void:
	if randf() >= chance:
		return
	var sm := SceneManager.save_manager
	var candidates: Array[String] = []

	var owned_w: Array[String] = sm.get_owned_by_slot("weapon")
	for wid: String in WeaponRegistry.get_by_slot("weapon"):
		if wid != "rusty_dagger" and not owned_w.has(wid):
			candidates.append(wid)

	var owned_a: Array[String] = sm.owned_armor
	for eid: String in WeaponRegistry.get_by_slot("armor"):
		if not owned_a.has(eid):
			candidates.append(eid)

	var owned_r: Array[String] = sm.owned_rings
	for eid: String in WeaponRegistry.get_by_slot("ring"):
		if not owned_r.has(eid):
			candidates.append(eid)

	var owned_t: Array[String] = sm.owned_trinkets
	for eid: String in WeaponRegistry.get_by_slot("trinket"):
		if not owned_t.has(eid):
			candidates.append(eid)

	if candidates.is_empty():
		return
	var picked: String = candidates[randi() % candidates.size()]
	var weapon: WeaponData = WeaponRegistry.get_weapon(picked)
	if weapon == null:
		return
	if weapon.slot == "weapon":
		sm.add_weapon(picked)
	else:
		sm.add_equipment(picked, weapon.slot)
	GameBus.hud_message_requested.emit("Found: %s!" % weapon.display_name)
	GameBus.equipment_dropped.emit(picked)

# ── Weather visuals ────────────────────────────────────────────────────────

func _on_weather_changed(weather_id: String, _duration: float) -> void:
	# Swap particle rig
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

	if weather_id != "":
		var particles: GPUParticles3D = WeatherParticles.make(weather_id) as GPUParticles3D
		if particles != null:
			_entity_root.add_child(particles)
			if _player != null:
				particles.position = _player.position + Vector3(0.0, 12.0, 0.0)
			_active_weather_particles = particles

	# Begin tint transition
	_weather_tint_target = WeatherParticles.get_screen_tint(weather_id)
	_weather_tint_lerp_t = 0.0

	# Update grass wind direction
	if _grass != null:
		var grass_node: GrassBlades = _grass as GrassBlades
		if grass_node != null:
			grass_node.set_wind_direction(WeatherParticles.get_wind_direction(weather_id))

# ── Tap-to-move ────────────────────────────────────────────────────────────

# Entry point called by both touch and mouse input after basic validation.
func _handle_tap_to_move(screen_pos: Vector2) -> void:
	if _player == null or _camera == null:
		return
	# GID-101 (TID-365): ping mode intercepts taps and creates a world-space ping.
	if _ping_mode_active and _coop_active:
		coop_social._handle_ping_tap(screen_pos)
		return
	var tile: Vector2i = _screen_to_tile(screen_pos)
	var tile_type: int = get_tile_global(tile.x, tile.y)
	var is_walkable: bool = (tile_type == IsoConst.TILE_GRASS
		or tile_type == IsoConst.TILE_HILL
		or tile_type == IsoConst.TILE_PATH)
	if not is_walkable:
		_show_tip("Can't go there")
		_show_reject_marker(tile)
		return
	var player_tile: Vector2i = IsoConst.world_to_tile(_player.position.x, _player.position.z)
	var path: Array[Vector2i] = Pathfinder.find_path(
		Callable(self, "get_tile_global"), player_tile, tile, 64)
	if path.is_empty():
		_show_tip("Can't reach that tile")
		_show_reject_marker(tile)
		return
	# TID-461: if the tapped tile is itself near an interactable, queue an
	# auto-interact for when the path completes (natural arrival only —
	# see Player.path_arrived / _on_player_path_arrived()).
	var wx: float = (float(tile.x) + 0.5) * IsoConst.TILE_SIZE
	var wz: float = (float(tile.y) + 0.5) * IsoConst.TILE_SIZE
	_pending_tap_interact = _tile_has_interactable(wx, wz)
	_place_dest_marker(tile)
	if _player.has_method("set_destination_path"):
		_player.call("set_destination_path", path)

## Mirrors _check_interactions()'s "has_entity" check but against an
## arbitrary world point instead of the live player position, so a tap can be
## classified as "aimed at an interactable" before the player ever walks
## there. Deliberately does not replicate any of _handle_interact()'s
## per-type dispatch — that stays the single source of truth.
func _tile_has_interactable(wx: float, wz: float) -> bool:
	if not _find_nearby_door(wx, wz, IsoConst.INTERACT_RANGE * 2.0).is_empty():
		return true
	if _find_nearby_enemy(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if not _find_nearby_chest(wx, wz, IsoConst.INTERACT_RANGE).is_empty():
		return true
	if not _find_nearby_npc(wx, wz, IsoConst.INTERACT_RANGE).is_empty():
		return true
	if _find_nearby_scroll(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_wilderness_camp(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_scout_ambush(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_maiteln(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_shrine(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_digspot(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if not _find_nearby_waystone(wx, wz, IsoConst.INTERACT_RANGE).is_empty():
		return true
	if not _find_nearby_mailbox(wx, wz, IsoConst.INTERACT_RANGE).is_empty():
		return true
	if _find_nearby_garden_plot(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_burial_mound(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_blight_heart(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	if _find_nearby_mana_well(wx, wz, IsoConst.INTERACT_RANGE) != null:
		return true
	return false

## Connected to Player.path_arrived (TID-461). Fires the normal interact
## dispatch once, exactly as if the player had pressed E/USE on arrival —
## only when the tap that started this path was aimed at an interactable and
## nothing (overlay, downed state) blocks interaction right now.
func _on_player_path_arrived() -> void:
	var should_interact: bool = _pending_tap_interact and not _coop_downed \
		and not SceneManager.has_open_overlay()
	_pending_tap_interact = false
	if should_interact:
		_handle_interact()

# Convert a screen position to the nearest tile coordinate via analytic
# ray–plane intersection with the y=0 tile plane.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_pos)
	# Solve: ray_origin.y + t * ray_dir.y = 0 → t = -ray_origin.y / ray_dir.y
	if abs(ray_dir.y) < 0.0001:
		return IsoConst.world_to_tile(_player.position.x, _player.position.z)
	var t: float = -ray_origin.y / ray_dir.y
	var world_pos: Vector3 = ray_origin + t * ray_dir
	return IsoConst.world_to_tile(world_pos.x, world_pos.z)

# Place or move the destination marker to the centre of the given tile.
func _place_dest_marker(tile: Vector2i) -> void:
	var wx: float = (float(tile.x) + 0.5) * IsoConst.TILE_SIZE
	var wz: float = (float(tile.y) + 0.5) * IsoConst.TILE_SIZE
	var wy: float = 0.08  # just above the tile surface

	if _dest_marker == null or not is_instance_valid(_dest_marker):
		_dest_marker = _make_tap_marker("DestMarker", Color(0.25, 1.0, 0.55))
		add_child(_dest_marker)

	_dest_marker.position = Vector3(wx, wy, wz)
	_dest_marker.show()

	if _dest_tween != null and _dest_tween.is_valid():
		_dest_tween.kill()
	_dest_tween = create_tween().set_loops()
	_dest_tween.tween_property(_dest_marker, "scale",
		Vector3(1.2, 1.0, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
	_dest_tween.tween_property(_dest_marker, "scale",
		Vector3(0.85, 1.0, 0.85), 0.45).set_trans(Tween.TRANS_SINE)

## The glowing ring dropped on a tapped tile: green for the destination the
## player is walking to, red for a tap that resolved to a wall.
##
## The material is deliberately built per call rather than shared — the reject
## flash fades this exact StandardMaterial3D's albedo alpha, and a shared one
## would fade every marker on screen (and stay faded for the next).
func _make_tap_marker(node_name: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.72
	torus.rings = 12
	torus.ring_segments = 16
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.90)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	return root

## TID-462: brief red/orange flash at a tapped tile that resolved to a wall
## or an unreachable destination. Independent of _dest_marker/_dest_tween —
## a rejected tap must never cancel or interfere with an in-progress path.
## CAUTION (CLAUDE.md): Node3D has no modulate — fade via the material's
## albedo_color alpha instead, not a "modulate:a" tween on the root/mesh.
func _show_reject_marker(tile: Vector2i) -> void:
	var wx: float = (float(tile.x) + 0.5) * IsoConst.TILE_SIZE
	var wz: float = (float(tile.y) + 0.5) * IsoConst.TILE_SIZE
	var marker: Node3D = _make_tap_marker("RejectMarker", Color(1.0, 0.25, 0.2))
	marker.position = Vector3(wx, 0.08, wz)
	add_child(marker)
	var mesh_inst: MeshInstance3D = marker.get_child(0) as MeshInstance3D
	var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
	var tw: Tween = marker.create_tween()
	tw.set_parallel(true)
	tw.tween_property(marker, "scale", Vector3(1.4, 1.0, 1.4), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.set_parallel(false)
	tw.tween_callback(marker.queue_free)

## Safely coerce a tracking-dict value to Node3D. `as Node3D` on a Variant
## holding a freed object throws "Trying to cast a freed object" immediately,
## before is_instance_valid() can be checked — this checks validity first.
func _valid_node3d(v) -> Node3D:
	if is_instance_valid(v):
		return v
	return null

## Same as _valid_node3d but for plain Node (RemotePlayer avatars).
func _valid_node(v) -> Node:
	if is_instance_valid(v):
		return v
	return null

func _clear_dest_marker() -> void:
	if _dest_tween != null and _dest_tween.is_valid():
		_dest_tween.kill()
	_dest_tween = null
	if _dest_marker != null and is_instance_valid(_dest_marker):
		_dest_marker.hide()
	if _player != null and _player.has_method("cancel_path"):
		_player.call("cancel_path")
	_pending_tap_interact = false

# ── Return portal (TID-339) ───────────────────────────────────────────────
# Spawns a visible "Return to Town" portal in the main overworld near the
# player's initial spawn so there is always an exit that doesn't require a
# waystone. Registers itself in _active_door_data with target_map = "" so
# _handle_interact → exit_map() pops the map stack back to madrian.

func _spawn_return_portal() -> void:
	const PORTAL_TX: int = 3
	const PORTAL_TZ: int = 6  # 3 tiles south of the default infinite-world spawn
	var wx: float = (float(PORTAL_TX) + 0.5) * IsoConst.TILE_SIZE
	var wz: float = (float(PORTAL_TZ) + 0.5) * IsoConst.TILE_SIZE
	var wy: float = get_terrain_height(wx, wz)

	# Visual: glowing golden pillar with a label above it.
	var root := Node3D.new()
	root.name = "ReturnPortal"
	root.position = Vector3(wx, wy, wz)
	_entity_root.add_child(root)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.20
	cyl.bottom_radius = 0.20
	cyl.height        = 2.0
	mesh_inst.mesh = cyl
	mesh_inst.position = Vector3(0.0, 1.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.20, 0.90)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.10)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)

	var lbl := Label3D.new()
	lbl.text = "Return to Town"
	lbl.font_size = 24
	lbl.modulate = Color(1.0, 0.95, 0.60)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.5, 0.0)
	root.add_child(lbl)

	# Register as a door with empty target_map so _handle_interact calls exit_map().
	var portal_data: Dictionary = {
		"id":             "return_portal",
		"x":              wx,
		"z":              wz,
		"target_map":     "",
		"target_door_id": "",
	}
	_active_door_data["return_portal"] = portal_data
	_door_nodes["return_portal"] = root


# ── GID-101: Social & Rewards ─────────────────────────────────────────────────
# TID-365: Emotes & map pings
# TID-366: Card trading & gifting
# TID-367: Spectate a duel
# TID-368: Wagered duels & champion record
# TID-369: Shared party bounties


