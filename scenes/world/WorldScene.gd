# gdlint: disable=max-file-lines
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends Node3D

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
const WeatherParticles   = preload("res://scenes/world/WeatherParticles.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")
const LandmarkNames  = preload("res://game_logic/world/LandmarkNames.gd")
const _ChunkData     = preload("res://game_logic/world/ChunkData.gd")
const _GraphicsQuality = preload("res://game_logic/GraphicsQuality.gd")
const _ScreenVignette = preload("res://scenes/world/ScreenVignette.gd")
const _WorldEventManager = preload("res://autoloads/WorldEventManager.gd")

const _TexGrass:     Texture2D = preload("res://assets/textures/pixel_art/grass_pixel.png")
const _TexHillSide:  Texture2D = preload("res://assets/textures/pixel_art/hill_side_pixel.png")
const _TexHillTop:   Texture2D = preload("res://assets/textures/pixel_art/hill_top_pixel.png")
const _TexWallSide:  Texture2D = preload("res://assets/textures/pixel_art/wall_side_pixel.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/pixel_art/wall_top_pixel.png")
const _TexPath:      Texture2D = preload("res://assets/textures/pixel_art/path_pixel.png")

# Preload entity scenes — avoids filesystem hits during spawning
const _OverworldPauseOverlay = preload("res://scenes/ui/OverworldPauseOverlay.gd")
const _PlayerScene       = preload("res://scenes/world/entities/Player.tscn")
const _ObjectiveBeacon   = preload("res://scenes/world/entities/ObjectiveBeacon.gd")
const _ObjectiveTracker  = preload("res://game_logic/ObjectiveTracker.gd")
const _Player            = preload("res://scenes/world/entities/Player.gd")
# Party panel (GID-107 / TID-395): consolidated entry point for the always-on
# co-op HUD affordances (Roster, Loot Mode, Stash, Leaderboard, Ghost Duels,
# Team Duel, Dungeon Crawl) that used to each be an individually-positioned button.

# Co-op multiplayer (GID-090)
const _Mounts = preload("res://scenes/world/modules/Mounts.gd")
const _NpcInteractions = preload("res://scenes/world/modules/NpcInteractions.gd")
const _PlayerHome = preload("res://scenes/world/modules/PlayerHome.gd")
const _ChestLoot = preload("res://scenes/world/modules/ChestLoot.gd")
const _NightLights = preload("res://scenes/world/modules/NightLights.gd")
const _AmbientTouches = preload("res://scenes/world/modules/AmbientTouches.gd")
const _FakeVolumetrics = preload("res://scenes/world/modules/FakeVolumetrics.gd")
const _ContactShadows = preload("res://scenes/world/modules/ContactShadows.gd")
const _NamedMapProps = preload("res://scenes/world/modules/NamedMapProps.gd")
const _TownSiege = preload("res://scenes/world/modules/TownSiege.gd")
const _SunRaysFx = preload("res://scenes/world/SunRaysFx.gd")
const _TapToMove = preload("res://scenes/world/modules/TapToMove.gd")
const _StoryCast = preload("res://scenes/world/modules/StoryCast.gd")
const _HomeGarden = preload("res://scenes/world/modules/HomeGarden.gd")
const _Cantrips = preload("res://scenes/world/modules/Cantrips.gd")
const _NocturnalSpawner = preload("res://scenes/world/modules/NocturnalSpawner.gd")
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
const _SESSION_SNAPSHOT_INTERVAL: float = 5.0
const _LOOT_ROLL_TIMEOUT: float = 15.0
const _COOP_SPIRE_DRAFT_TIMEOUT: float = 30.0
# Rally waystones (GID-105 / TID-388) — guarded by NetworkManager.is_active().
const _RALLY_COOLDOWN: float = 3.0
const _CHALLENGE_RANGE: float = 3.0      # tiles; proximity to show the prompt
const TOURNAMENT_ANTE_COINS: int = 25  # flat per-player entry fee; pot = ante * players
# GID-102 / TID-376: Shared party stash
# GID-102 / TID-378: Async card auction house
const _ChapterEndingOverlay = preload("res://scenes/ui/ChapterEndingOverlay.gd")

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

const LANDMARK_DISCOVERY_RANGE: float = 9.0

## Menu actions that cancel any tap-to-move walk before opening.
const _MENU_ACTIONS: Array[String] = ["inventory", "journal", "character", "skill_tree"]

@export var map_name: String = "main"
@export var target_door_id: String = ""
@export var day_duration: float = 600.0   # seconds per full day

# Named-map path
var world_map: WorldMap
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
var coop_social: _CoopSocial = null
var coop_pvp: _CoopPvP = null
var coop_activities: _CoopActivities = null
var coop_session: _CoopSession = null

# Nocturnal spawn system (GID-055 Night Hunts) — see modules/NocturnalSpawner.gd
var nocturnal: _NocturnalSpawner = null
var cantrips: _Cantrips = null   # modules/Cantrips.gd (GID-065)
var home_garden: _HomeGarden = null   # modules/HomeGarden.gd (GID-059)
var story_cast: _StoryCast = null    # modules/StoryCast.gd (GID-108)

var world_seed: int = 42  # overwritten in _ready() for infinite worlds

var tap_move: _TapToMove = null   # modules/TapToMove.gd
var mounts: _Mounts = null     # modules/Mounts.gd (GID-048)
var player_home: _PlayerHome = null   # modules/PlayerHome.gd
var npc_interactions: _NpcInteractions = null   # modules/NpcInteractions.gd
var town_siege: _TownSiege = null   # modules/TownSiege.gd (GID-054)
var named_props: _NamedMapProps = null   # modules/NamedMapProps.gd
var chest_loot: _ChestLoot = null    # modules/ChestLoot.gd
var night_lights: _NightLights = null  # modules/NightLights.gd (TID-489)
var ambient: _AmbientTouches = null  # modules/AmbientTouches.gd (TID-493)
var fake_volumetrics: _FakeVolumetrics = null  # modules/FakeVolumetrics.gd (GID-130)
var contact_shadows: _ContactShadows = null  # modules/ContactShadows.gd (GID-131)

# Computed in _ready from map_name; true for "main" and "infinite", false for named dungeon maps
var _is_infinite: bool = false

# Common
var _player: _Player
var _grass: GrassBlades
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
# Co-op world-object sync (GID-096) — guarded by _coop_active; inert single-player.
var _coop_removed_enemies: Dictionary = {}  # enemy id -> true (engaged/defeated this session)
# Shared story scrolls (GID-108 / TID-408) — mirrors _coop_opened_objects exactly.
var _coop_collected_scrolls: Dictionary = {}  # scroll id -> true (collected by anyone this session)
var _coop_scroll_syncing: bool = false        # reentry guard, mirrors _coop_story_flag_syncing
# Party loot rolls (GID-102 / TID-381) — opt-in need/greed alternative to first-opener-takes.
# Authority only: roll_id -> {chest_id, item, tier, participants: Array[String],
# choices: {token: "need"|"greed"|"pass"}, timer: float}. Empty on clients and when unused.
var _loot_rolls_active: Dictionary = {}
# Client (or host's own local UI): the currently-shown roll prompt, or {} when none.
var _pending_loot_roll: Dictionary = {}
var _loot_roll_panel: Node = null   # transient Need/Greed/Pass panel (CanvasLayer), nil when closed
# Co-op Endless Spire alternating draft (GID-106 / TID-390). Authority only:
# non-empty while a draft round is in flight (a single floor's one-pick round —
# this task's scope; a full floor-by-floor loop is TID-391's job). Shape:
# {floor, options: Array[String], active_picker_token, active_picker_name, timer}.
var _coop_spire_draft_active: Dictionary = {}
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
var _door_nodes: Dictionary = {}    # id -> Node3D
var _npc_nodes: Dictionary = {}     # id -> Node3D
var _scroll_nodes: Array[Node3D] = []
var _wilderness_camp_node: Node3D = null
var _scout_ambush_node: Node3D = null
var _maiteln_node: Node3D = null
var _shrine_nodes: Array[Node3D] = []
var _siege_banner: Label = null
var _waystone_nodes: Dictionary = {}    # id -> Node3D
var _active_waystone_data: Dictionary = {}  # id -> Dictionary
var _mailbox_nodes: Dictionary = {}    # id -> Node3D
var _active_mailbox_data: Dictionary = {}  # id -> Dictionary
var _garden_plot_nodes: Array[Node3D] = []  # ordered by plot_idx
# Guildhall garden (GID-106 / TID-393): SessionStore is authority-only, so this
# cache mirrors _pve_leaderboards' pattern — kept current via request/broadcast
# RPCs, then pushed into each spawned GardenPlot (session_mode = true) node.
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
var _current_biome: int = -1
var _terrain_mat: ShaderMaterial
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0
var _roaming_boss_timer: float = 0.0
var _traveling_merchant_timer: float = 0.0
var _card_shower_items: Array[Node3D] = []
var _night_cue_played: bool = false

# Day/night cycle — delegated to DayNightCycle component
var _world_env: WorldEnvironment
var _dnc: DayNightCycle = null
var _sun_rays: _SunRaysFx = null  # TID-488 dawn/dusk light shafts

# Weather visuals
var _active_weather_particles: Node3D = null

# Camera smoothing: lerped toward player each _process frame to eliminate
# micro-stutter on high-refresh displays (camera runs at render rate, physics at ~60 Hz).
var _smooth_camera_target: Vector3 = Vector3.ZERO
var _fill_light: DirectionalLight3D
# Active GraphicsQuality knobs (TID-484). Atmosphere effects read these, never the platform.
var _graphics_knobs: Dictionary = {}

var _pause_overlay: _OverworldPauseOverlay = null
var _world_hud: WorldHUD = null
var _dungeon_session_ui: DungeonSessionUI = null
var _minimap: Minimap
var _map_overlay: MapViewOverlay = null

# Story objective beacon (one at most, on the objective's tile — see
# _refresh_objective_beacon).
var _objective_beacon: _ObjectiveBeacon = null

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel
@onready var _coin_label: Label = $HUD/CoinLabel
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _moon: DirectionalLight3D = $MoonLight

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
	_fill_light.light_volumetric_fog_energy = 0.0  # unshadowed: would only haze the sun-ray fog
	_fill_light.rotation_degrees = Vector3(60.0, 45.0, 0.0)
	add_child(_fill_light)
	add_child(_ScreenVignette.make())

## Re-reads the Graphics Quality setting and applies it (TID-484). Also runs
## live from Settings via GameBus.graphics_quality_changed.
func apply_graphics_quality(_tier: int = -1) -> void:
	var setting: Variant = SceneManager.save_manager.get_setting(_GraphicsQuality.SETTING_KEY, null)
	_graphics_knobs = _GraphicsQuality.current_knobs(setting)
	var env: Environment = _world_env.environment if _world_env != null else null
	_GraphicsQuality.apply(_graphics_knobs, env, _sun, get_viewport(), _moon)
	if _sun_rays != null:
		_sun_rays.set_mode(int(_graphics_knobs.get("sun_rays", 0)))
		_sun_rays.set_quality(int(_graphics_knobs.get("ray_samples", 10)), bool(_graphics_knobs.get("moon_rays", false)))
	if contact_shadows != null:
		contact_shadows.apply_knobs(_graphics_knobs)
	if _dnc != null:
		_dnc.set_height_fog(bool(_graphics_knobs.get("height_fog", false)))

## The active GraphicsQuality knobs — atmosphere effects read these, never the platform.
func graphics_knobs() -> Dictionary:
	return _graphics_knobs

func _ready() -> void:
	# Before anything else wires signals to them (the GameBus connections below
	# target module methods directly).
	_ensure_world_modules()
	_ensure_coop_modules()
	_setup_environment()
	_sun.shadow_opacity = 0.2
	# Sun shadows, SSAO, glow and MSAA follow the Graphics Quality tier (Medium,
	# the phone default, keeps sun shadows off — too expensive for phone GPUs).
	apply_graphics_quality()
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
		world_seed = SceneManager.save_manager.world_seed
		InfiniteWorldGen.forced_start_biome = SceneManager.save_manager.starting_biome
	_terrain_mat = _make_terrain_material(world_seed)
	_build_grass_blades_node()

	if not _is_infinite:
		_load_named_map()

	# ChunkStreamingManager owns all chunk lifecycle state and thread work.
	# Created after world_map is ready so it receives the correct reference.
	_csm = ChunkStreamingManager.new()
	_csm.name = "ChunkStreamingManager"
	add_child(_csm)
	_csm.setup(world_seed, _is_infinite, world_map, _terrain_mat, self)
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
	_sun_rays = _SunRaysFx.new()
	_sun_rays.name = "SunRays"
	add_child(_sun_rays)
	_sun_rays.setup(_camera, _sun, _moon, _world_env.environment, _dnc)
	apply_graphics_quality()
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
			nocturnal.despawn_all(true)
			_night_cue_played = false
		)
		# Storm lightning (TID-487): thunder after the flash; reduce-flashing read live.
		_dnc.thunder_rumbled.connect(func(pitch: float) -> void: AudioManager.play_sfx_varied("thunder", pitch, 0.05))
		_dnc.flashing_allowed = func() -> bool: return not bool(
			SceneManager.save_manager.get_setting("reduce_flashing", false))

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
		story_cast.refresh_maiteln_presence()
		_refresh_objective_beacon()

	coop_session._setup_coop()
	# Guildhall furnishings (GID-106 / TID-393): must run after _setup_coop() so
	# _net_sync exists — a client's garden snapshot request needs it. The map
	# itself is only ever entered from an active co-op session (TID-392), so
	# NetworkManager.is_active() here is a defensive guard, not a live gate.
	if map_name == "guildhall" and NetworkManager.is_active():
		coop_session.spawn_guildhall_furnishings()
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
			story_cast.spawn_open_world_rival()
			story_cast.spawn_wilderness_camp()
			story_cast.spawn_scout_ambush()
			if map_name == "main":
				_spawn_return_portal()
	else:
		# Named map: load all chunks covering the 100×100 tile map synchronously
		var max_cx: int = (WorldMap.MAP_WIDTH + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
		var max_cz: int = (WorldMap.MAP_HEIGHT + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
		var _named_ref: Vector3 = _player.position if _player != null else server_ref_pos
		_csm.build_all_named_map(max_cx, max_cz, _named_ref)
		named_props.spawn_all()
		story_cast.spawn_named_map_rivals()
		if map_name == "player_home":
			player_home.spawn_trophies()
			home_garden.spawn_home_plots()
		town_siege.on_map_entered(map_name)
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
	tap_move.joystick = joystick

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
		_minimap.tapped.connect(named_props.open_fast_travel_panel)
	else:
		_minimap.tapped.connect(_open_map_view)

	GameBus.hud_message_requested.connect(func(text: String) -> void: _world_hud.show_dialogue(text))
	GameBus.story_scroll_collected.connect(_on_scroll_collected)
	GameBus.waystone_activated.connect(named_props.on_waystone_activated)
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
			story_cast.inject_warcamp_boss(world_map)
	elif map_name.begins_with("spire_floor_"):
		var parts: PackedStringArray = map_name.split("_")
		var sp_floor: int = int(parts[2]) if parts.size() > 2 else 1
		var sp_seed: int  = int(parts[3]) if parts.size() > 3 else 0
		# An uncleared floor must have its enemy — see prepare_spire_floor. Runs
		# before the map is distributed into chunks, since ChunkRenderer consults
		# defeated_enemies as it spawns.
		SceneManager.save_manager.spire.prepare_spire_floor(sp_floor, sp_seed)
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
	GameBus.enemy_engaged.connect(mounts.on_enemy_engaged)
	GameBus.blight_changed.connect(_refresh_blight_tints)
	GameBus.graphics_quality_changed.connect(apply_graphics_quality)
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
	GameBus.enemy_engaged.connect(func(_enemy_data: Dictionary) -> void: tap_move.clear())
	GameBus.inventory_requested.connect(tap_move.clear)
	GameBus.journal_requested.connect(tap_move.clear)

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

## Creates the single-player feature modules split out of this scene. Same
## shape as the co-op modules: a child Node with a `_world` back-reference.
func _ensure_world_modules() -> void:
	nocturnal = _ensure_world_module(nocturnal, _NocturnalSpawner, "NocturnalSpawner") as _NocturnalSpawner
	cantrips = _ensure_world_module(cantrips, _Cantrips, "Cantrips") as _Cantrips
	home_garden = _ensure_world_module(home_garden, _HomeGarden, "HomeGarden") as _HomeGarden
	story_cast = _ensure_world_module(story_cast, _StoryCast, "StoryCast") as _StoryCast
	tap_move = _ensure_world_module(tap_move, _TapToMove, "TapToMove") as _TapToMove
	mounts = _ensure_world_module(mounts, _Mounts, "Mounts") as _Mounts
	player_home = _ensure_world_module(player_home, _PlayerHome, "PlayerHome") as _PlayerHome
	npc_interactions = _ensure_world_module(npc_interactions, _NpcInteractions, "NpcInteractions") as _NpcInteractions
	town_siege = _ensure_world_module(town_siege, _TownSiege, "TownSiege") as _TownSiege
	named_props = _ensure_world_module(named_props, _NamedMapProps, "NamedMapProps") as _NamedMapProps
	chest_loot = _ensure_world_module(chest_loot, _ChestLoot, "ChestLoot") as _ChestLoot
	night_lights = _ensure_world_module(night_lights, _NightLights, "NightLights") as _NightLights
	ambient = _ensure_world_module(ambient, _AmbientTouches, "AmbientTouches") as _AmbientTouches
	fake_volumetrics = _ensure_world_module(fake_volumetrics, _FakeVolumetrics, "FakeVolumetrics") as _FakeVolumetrics
	contact_shadows = _ensure_world_module(contact_shadows, _ContactShadows, "ContactShadows") as _ContactShadows

func _ensure_world_module(existing: Node, script: GDScript, node_name: String) -> Node:
	if existing != null and is_instance_valid(existing):
		return existing
	var mod: Node = script.new()
	mod.name = node_name
	mod.set("_world", self)
	add_child(mod)
	return mod

## Creates the co-op feature modules and, once NetSync exists, registers them as
## its RPC handler targets. Called from _ready (so _ready's own GameBus wiring
## has something to connect to) and again from _setup_coop. Idempotent: a PvP
## battle detaches and re-adds WorldScene without tearing the modules down.
## The modules are inert outside a session, so creating them always is free.
func _ensure_coop_modules() -> void:
	coop_social = _ensure_coop_module(coop_social, _CoopSocial, "CoopSocial") as _CoopSocial
	coop_pvp = _ensure_coop_module(coop_pvp, _CoopPvP, "CoopPvP") as _CoopPvP
	coop_activities = _ensure_coop_module(coop_activities, _CoopActivities, "CoopActivities") as _CoopActivities
	coop_session = _ensure_coop_module(coop_session, _CoopSession, "CoopSession") as _CoopSession

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
		cx, cz, world_seed, sm.days_elapsed, sm.blight_cleansed_hearts)
	var attuned: bool = _is_infinite and TerrainMath.is_on_ley_line(px, pz, world_seed)
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
	if _player.has_signal("path_arrived") and not _player.is_connected("path_arrived", tap_move.on_path_arrived):
		_player.connect("path_arrived", tap_move.on_path_arrived)
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

func _on_chunk_committed(_key: Vector2i, chunk_data: _ChunkData) -> void:
	for l_data: Dictionary in chunk_data.landmarks:
		var lid: String = str(l_data.get("id", ""))
		_active_landmark_data[lid] = l_data

func _on_chunk_unloading(chunk_key: Vector2i, chunk_data: _ChunkData) -> void:
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
	nocturnal.evict_chunk(chunk_key)

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
		var wem: _WorldEventManager = get_node_or_null("/root/WorldEventManager") as _WorldEventManager
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
		var wem: _WorldEventManager = get_node_or_null("/root/WorldEventManager") as _WorldEventManager
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
	for key in table:
		var d: Dictionary = table[key]
		if _data_in_range(d, px, pz, range_dist):
			return d
	return {}

## True when a {"x", "z", ...} entry lies within `range_dist` of (px, pz).
func _data_in_range(d: Dictionary, px: float, pz: float, range_dist: float) -> bool:
	var ddx: float = float(d.get("x", 0.0)) - px
	var ddz: float = float(d.get("z", 0.0)) - pz
	return ddx * ddx + ddz * ddz <= range_dist * range_dist

func _find_nearby_garden_plot(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_garden_plot_nodes, px, pz, range_dist)

func _find_nearby_scroll(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_scroll_nodes, px, pz, range_dist)

func _find_nearby_wilderness_camp(px: float, pz: float, range_dist: float) -> Node3D:
	return _node_in_range(_wilderness_camp_node, px, pz, range_dist)

func _find_nearby_scout_ambush(px: float, pz: float, range_dist: float) -> Node3D:
	return _node_in_range(_scout_ambush_node, px, pz, range_dist)

func _find_nearby_maiteln(px: float, pz: float, range_dist: float) -> Node3D:
	return _node_in_range(_maiteln_node, px, pz, range_dist)

## Any story flag change can move the cast around: Maiteln's follower is gated on
## several Chapter 1 flags, and NPCs carrying MapNpc.hide_flag_key leave their
## post when theirs is set. Both have to react on the flag, not just on the next
## map load — the player is standing right there when it flips.
func _on_story_flag_set_for_cast(_key: String) -> void:
	story_cast.refresh_maiteln_presence()
	_despawn_flag_hidden_npcs()
	_refresh_objective_beacon()

## Plants (or moves, or clears) the in-world beacon over the current story
## objective. The compass ribbon only gives a bearing; standing in the right
## street still left the player guessing which hut or which NPC was the target,
## so the objective also gets a marker on the thing itself.
##
## Story flags are what move the objective, so this runs on map entry and on
## every flag change — never per frame.
func _refresh_objective_beacon() -> void:
	if NetworkManager.is_dedicated_server():
		return
	var raw: Variant = _ObjectiveTracker.objective_world_pos(
		SceneManager.save_manager.story_flags, map_name)
	if raw == null:
		if is_instance_valid(_objective_beacon):
			_objective_beacon.queue_free()
		_objective_beacon = null
		return
	var pos: Vector3 = raw as Vector3
	if not is_instance_valid(_objective_beacon):
		_objective_beacon = _ObjectiveBeacon.new()
		_objective_beacon.name = "ObjectiveBeacon"
		add_child(_objective_beacon)
		_objective_beacon.setup(_player)
	_objective_beacon.position = Vector3(pos.x, get_terrain_height(pos.x, pos.z), pos.z)

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

func _find_nearby_shrine(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_shrine_nodes, px, pz, range_dist)

func _find_nearby_mailbox(px: float, pz: float, range_dist: float) -> Dictionary:
	return _first_data_in_range(_active_mailbox_data, px, pz, range_dist)

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

func _check_nearby_landmark(px: float, pz: float) -> void:
	if not _is_infinite:
		return
	var sm := SceneManager.save_manager
	for lid: String in _active_landmark_data:
		var l: Dictionary = _active_landmark_data[lid]
		if not sm.is_landmark_discovered(lid) and _data_in_range(l, px, pz, LANDMARK_DISCOVERY_RANGE):
			_discover_landmark(lid, l)

func _discover_landmark(lid: String, l_data: Dictionary) -> void:
	var sm := SceneManager.save_manager
	sm.mark_landmark_discovered(lid)
	var cx: int = int(l_data.get("cx", 0))
	var cz: int = int(l_data.get("cz", 0))
	var display_name: String = LandmarkNames.landmark_name(cx, cz, world_seed)
	GameBus.landmark_discovered.emit(lid, display_name)
	SceneManager.show_toast("Discovery!", display_name)
	# One-time reward: coins + random card
	sm.add_coins(50)
	var card_ids: Array[String] = ["ghost", "skeleton", "zombie", "ghoul"]
	var rng := RandomNumberGenerator.new()
	rng.seed = (cx * 73856093) ^ (cz * 19349663) ^ world_seed
	rng.seed = rng.seed & 0x7FFFFFFF
	var card_id: String = card_ids[rng.randi_range(0, card_ids.size() - 1)]
	sm.grant_card_reward(card_id, "rare")
	GameBus.hud_message_requested.emit("You discovered %s! +50 coins, +1 card." % display_name)

func _refresh_blight_tints() -> void:
	var sm := SceneManager.save_manager
	_csm.for_each_renderer(func(key: Vector2i, cr: ChunkRenderer) -> void:
		var intensity: float = BlightField.blight_intensity(
			key.x, key.y, world_seed, sm.days_elapsed, sm.blight_cleansed_hearts)
		cr.set_blight_amount(intensity)
	)

func _find_nearby_burial_mound(px: float, pz: float, range_dist: float) -> Node3D:
	return _first_node_in_range(_burial_mound_nodes, px, pz, range_dist, true)

func _find_nearby_waystone(px: float, pz: float, range_dist: float) -> Dictionary:
	return _first_data_in_range(_active_waystone_data, px, pz, range_dist)

## Chunk data for the loaded chunks in the 3×3 block around (px, pz). Enemies
## and chests are indexed per chunk, so their finders only scan these.
func _neighbour_chunks(px: float, pz: float) -> Array[_ChunkData]:
	var chunk_world: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var pcx: int = int(floor(px / chunk_world))
	var pcz: int = int(floor(pz / chunk_world))
	var out: Array[_ChunkData] = []
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var key := Vector2i(pcx + dx, pcz + dz)
			if _csm.has_chunk_data(key):
				out.append(_csm.get_chunk_data(key))
	return out

func _find_nearby_enemy(px: float, pz: float, range_dist: float) -> Node3D:
	for chunk: _ChunkData in _neighbour_chunks(px, pz):
		for e_data: Dictionary in chunk.enemies:
			var node: Node3D = _node_in_range(_enemy_nodes.get(str(e_data.get("id", ""))), px, pz, range_dist)
			if node != null:
				return node
	return null

## The first unopened chest within range, as its live `_active_chest_data` entry.
func _find_nearby_chest(px: float, pz: float, range_dist: float) -> Dictionary:
	for chunk: _ChunkData in _neighbour_chunks(px, pz):
		for c_data: Dictionary in chunk.chests:
			var d: Dictionary = _active_chest_data.get(str(c_data.get("id", "")), {})
			if not d.is_empty() and not d.get("opened", false) and _data_in_range(d, px, pz, range_dist):
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

func _create_player_node() -> _Player:
	var p: _Player = _PlayerScene.instantiate()
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

## SceneManager probes these by name before leaving the world (go_to_menu,
## battles, puzzles). `_process` only saves position after a >1 unit move and
## time of day alongside it, so without them the last step and any time spent
## standing still were lost. Neither existed until the unsafe-access pass
## surfaced SceneManager's has_method guards as always-false.
func flush_save_position() -> void:
	if _player == null:
		return
	_last_save_pos = Vector2(_player.position.x, _player.position.z)
	SceneManager.save_manager.update_position(map_name, _player.position.x, _player.position.z)

func flush_time_of_day() -> void:
	if _dnc:
		SceneManager.save_manager.time_of_day = _dnc.get_time_of_day()

func _process(delta: float) -> void:
	# Co-op and time ticks run before the player null-check so they work in
	# dedicated-server mode (no local player) as well as in normal sessions.
	if _coop_active:
		_tick_coop(delta)
	if _dnc:
		_dnc.tick(delta)
		AudioManager.set_time_of_day(_dnc.get_time_of_day())  # day/night ambience layer

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

	# Keep particle rig centred on the player
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.position = _player.position + Vector3(0.0, 12.0, 0.0)

	if _is_infinite:
		if _world_hud != null:
			_world_hud.set_ley_indicator_visible(TerrainMath.is_on_ley_line(
				_player.position.x, _player.position.z, world_seed))
		_tick_roaming_boss(delta)
		_tick_traveling_merchant(delta)
		_tick_card_shower()
		nocturnal.tick(delta)
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

	tap_move.tick()

	if Input.is_action_just_pressed("interact"):
		_handle_interact()

	if Input.is_action_just_pressed("mount"):
		mounts.toggle()

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
	# gdlint:ignore = max-returns
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

## Fades every Sprite3D on the player (ghost phase, downed state).
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

func _pressed_menu_action(event: InputEvent) -> String:
	for action: String in _MENU_ACTIONS:
		if event.is_action_pressed(action):
			return action
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Esc closes an open fast-travel panel rather than pausing over it.
		if not named_props.close_fast_travel() and _pause_overlay == null:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map_view"):
		tap_move.clear()
		_open_map_view()
		get_viewport().set_input_as_handled()
		return
	var menu: String = _pressed_menu_action(event)
	if menu != "":
		tap_move.clear()
		match menu:
			"inventory": GameBus.inventory_requested.emit()
			"journal": GameBus.journal_requested.emit()
			"character": GameBus.character_requested.emit()
			"skill_tree": GameBus.skill_tree_requested.emit()
		get_viewport().set_input_as_handled()
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_G:
		cantrips.activate_ghost_phase()
		get_viewport().set_input_as_handled()
	elif key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_D:
		# D is also move_right: dig only when a mound is in reach, and never
		# consume the event, so walking right stays silent.
		cantrips.activate_skeleton_dig(true)
	elif key_event != null and key_event.pressed \
			and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER) \
			and _coop_active and _chat_input != null and is_instance_valid(_chat_input) \
			and not _chat_input.has_focus():
		# Desktop chat-focus shortcut (TID-374). Mobile equivalent is the "Chat"
		# HUD button (_chat_toggle_btn), which also reveals/focuses the input.
		_chat_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif tap_move.handle_input(event):
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
			player_home.show_house_door_panel()
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
		chest_loot.open(chest, px, pz)
		return

	if not _is_infinite and world_map != null:
		var cracked := world_map.find_nearby_cracked_wall(px, pz, IsoConst.INTERACT_RANGE)
		if cracked != Vector2i(-1, -1):
			_break_cracked_wall(cracked.x, cracked.y)
			return

	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	if not npc.is_empty():
		npc_interactions.interact(npc)
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
			named_props.open_fast_travel_panel()
		else:
			var wnode := _valid_node3d(_waystone_nodes.get(wid))
			if wnode != null and wnode.has_method("mark_activated"):
				wnode.call("mark_activated")
		return

	var mailbox := _find_nearby_mailbox(px, pz, IsoConst.INTERACT_RANGE)
	if not mailbox.is_empty():
		GameBus.mailbox_requested.emit()
		return

	var garden_plot: Node3D = _find_nearby_garden_plot(px, pz, IsoConst.INTERACT_RANGE)
	if garden_plot != null:
		home_garden.show_panel(garden_plot)

# ── Spire entrance ─────────────────────────────────────────────────────────


	# Hostile entities are probed last, so anything peaceful in reach wins: you can
	# take a door, open a chest or read a scroll with an enemy standing next to you
	# instead of being forced into the fight. See INTERACT_PRIORITY.
	var blight_heart_node := _find_nearby_blight_heart(px, pz, IsoConst.INTERACT_RANGE)
	if blight_heart_node != null and blight_heart_node.has_method("engage"):
		blight_heart_node.call("engage")
		return

	var scout_ambush_node := _find_nearby_scout_ambush(px, pz, IsoConst.INTERACT_RANGE)
	if scout_ambush_node != null and scout_ambush_node.has_method("interact"):
		scout_ambush_node.call("interact")
		return

	var enemy := _find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
	if enemy != null and enemy.has_method("engage"):
		var enemy_data: Variant = enemy.get("enemy_data")
		if enemy_data != null:
			var edict: Dictionary = enemy_data as Dictionary
			var etype: String = str(edict.get("enemy_type", ""))
			if etype.begins_with("rival_"):
				var dlg: String = str(edict.get("pre_battle_dialogue", ""))
				if dlg != "":
					_show_dialogue(dlg)
		enemy.call("engage")
		# gdlint:ignore = max-returns
		return

func _show_spire_entrance_panel() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var is_active: bool = SceneManager.save_manager.spire.is_spire_active()
	var curr_floor: int = 1
	if is_active:
		curr_floor = int(SceneManager.save_manager.spire.get_spire_run().get("floor", 1))

	var modal: Dictionary = _build_modal(0.64, 0.40, Color(0.06, 0.04, 0.14, 0.96), 0.022)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := _UiUtil.make_label("The Endless Spire", int(vh * 0.038), Color(0.85, 0.50, 1.0),
			HORIZONTAL_ALIGNMENT_CENTER, vbox)

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

	var enter_btn := _UiUtil.make_button("Resume (Floor %d)" % curr_floor if is_active else "Enter",
			Vector2(vh * 0.20, vh * 0.07), int(vh * 0.028))
	enter_btn.modulate = Color(0.85, 0.50, 1.0)
	enter_btn.pressed.connect(func() -> void:
		layer.queue_free()
		SceneManager.enter_spire()
	)
	row.add_child(enter_btn)

	var leave_btn := _UiUtil.make_button("Leave", Vector2(vh * 0.16, vh * 0.07), int(vh * 0.028),
			func() -> void: layer.queue_free(), row)

# ── Player Home ────────────────────────────────────────────────────────────

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
			SceneManager.save_manager.bounties.increment_bounty_progress("defeat_in_biome", {"biome_name": biome_name})
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

func _show_dialogue(text: String) -> void:
	_world_hud.show_dialogue(text)

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
		coop_session._broadcast_scroll_collected_coop(scroll_id)

# ── Weather visuals ────────────────────────────────────────────────────────

func _on_weather_changed(weather_id: String, _duration: float) -> void:
	# Swap particle rig
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

	if weather_id != "":
		var particles: GPUParticles3D = WeatherParticles.make(weather_id) as GPUParticles3D
		if particles != null:
			particles.amount = _GraphicsQuality.scaled_amount(particles.amount, _graphics_knobs)
			_entity_root.add_child(particles)
			if _player != null:
				particles.position = _player.position + Vector3(0.0, 12.0, 0.0)
			_active_weather_particles = particles

	# Fog, sky, sun, shadows, ambient tint and grass wind blend in via
	# DayNightCycle from the WeatherLook table (TID-486).
	if _dnc != null:
		_dnc.set_weather(weather_id)

	# Update grass wind direction
	if _grass != null:
		var grass_node: GrassBlades = _grass as GrassBlades
		if grass_node != null:
			grass_node.set_wind_direction(WeatherParticles.get_wind_direction(weather_id))

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


