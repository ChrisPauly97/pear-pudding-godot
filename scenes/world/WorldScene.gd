extends Node3D

const WorldEvents     = preload("res://game_logic/WorldEvents.gd")
const WorldMap        = preload("res://game_logic/world/WorldMap.gd")
const DungeonGen      = preload("res://game_logic/world/DungeonGen.gd")
const SpireFloorGen   = preload("res://game_logic/spire/SpireFloorGen.gd")
const GrassBlades     = preload("res://scenes/world/GrassBlades.gd")
const VirtualJoystick = preload("res://scenes/ui/VirtualJoystick.gd")
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
const SaveManager        = preload("res://autoloads/SaveManager.gd")
const MountRegistry      = preload("res://game_logic/MountRegistry.gd")
const TrophyRegistry     = preload("res://game_logic/TrophyRegistry.gd")
const WeatherParticles   = preload("res://scenes/world/WeatherParticles.gd")
const _TerrainShader: Shader = preload("res://assets/shaders/terrain.gdshader")
const TextureGen = preload("res://game_logic/TextureGen.gd")
const Pathfinder  = preload("res://game_logic/Pathfinder.gd")
const RivalSystem = preload("res://game_logic/RivalSystem.gd")
const CantripManager = preload("res://game_logic/world/CantripManager.gd")
const LandmarkNames  = preload("res://game_logic/world/LandmarkNames.gd")
const _BurialMoundScene = preload("res://scenes/world/entities/BurialMound.tscn")

const _TexGrass:     Texture2D = preload("res://assets/textures/pixel_art/grass_pixel.png")
const _TexHillSide:  Texture2D = preload("res://assets/textures/pixel_art/hill_side_pixel.png")
const _TexHillTop:   Texture2D = preload("res://assets/textures/pixel_art/hill_top_pixel.png")
const _TexWallSide:  Texture2D = preload("res://assets/textures/pixel_art/wall_side_pixel.png")
const _TexWallTop:   Texture2D = preload("res://assets/textures/pixel_art/wall_top_pixel.png")

# Preload entity scenes — avoids filesystem hits during spawning
const _OverworldPauseOverlay = preload("res://scenes/ui/OverworldPauseOverlay.gd")
const _PlayerScene       = preload("res://scenes/world/entities/Player.tscn")
const _EnemyScene        = preload("res://scenes/world/entities/EnemyNPC.tscn")
const _ChestScene        = preload("res://scenes/world/entities/Chest.tscn")
const _DoorScene         = preload("res://scenes/world/entities/Door.tscn")
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
const _RatingMath        = preload("res://game_logic/net/RatingMath.gd")
const _LeaderboardOverlay = preload("res://scenes/ui/LeaderboardOverlay.gd")
# Party panel (GID-107 / TID-395): consolidated entry point for the always-on
# co-op HUD affordances (Roster, Loot Mode, Stash, Leaderboard, Ghost Duels,
# Team Duel, Dungeon Crawl) that used to each be an individually-positioned button.
const _PartyPanel        = preload("res://scenes/ui/PartyPanel.gd")

# Co-op multiplayer (GID-090)
const _NetSyncScript     = preload("res://scenes/world/NetSync.gd")
const _RemotePlayerScene = preload("res://scenes/world/entities/RemotePlayer.tscn")
const _AvatarSync        = preload("res://game_logic/net/AvatarSync.gd")
const _PlayerIdentity    = preload("res://game_logic/net/PlayerIdentity.gd")
const _NET_BROADCAST_INTERVAL: float = 1.0 / 15.0  # 15 Hz avatar broadcast
# Co-op world-object sync (GID-096)
const _EnemySync         = preload("res://game_logic/net/EnemySync.gd")
const _WorldObjectSync   = preload("res://game_logic/net/WorldObjectSync.gd")
const _ENEMY_POS_INTERVAL: float = 1.0 / 5.0  # 5 Hz enemy position broadcast (host)
# Ghost duels (GID-102 / TID-377): async solo battle vs. an AI-piloted snapshot of
# another session member's deck. Zero live networking (no NetSync RPC involved).
const _GhostDuelOverlay  = preload("res://scenes/ui/GhostDuelOverlay.gd")
# Party loot rolls (GID-102 / TID-381)
const _LootRoll          = preload("res://game_logic/net/LootRoll.gd")
const _CardDropUtil      = preload("res://game_logic/CardDropUtil.gd")
const _CardInstanceUtil  = preload("res://game_logic/CardInstanceUtil.gd")
const _SessionState      = preload("res://game_logic/net/SessionState.gd")
# Session tournaments (GID-104 / TID-386)
const _TournamentSync    = preload("res://game_logic/net/TournamentSync.gd")
# Downed & rescue in shared dungeons (GID-105 / TID-389)
const _DownedSync        = preload("res://game_logic/net/DownedSync.gd")
# Shared world life (GID-103): synced clock/weather, party night hunts, co-op siege
const _EnvSync           = preload("res://game_logic/net/EnvSync.gd")
const _CoopNightHunts    = preload("res://game_logic/CoopNightHunts.gd")
const _CoopSiege         = preload("res://game_logic/CoopSiege.gd")
const _CardRegistry      = preload("res://autoloads/CardRegistry.gd")
const _ENV_BROADCAST_INTERVAL: float = 3.0  # host: low-Hz clock/weather broadcast

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
var _remote_player_maps: Dictionary = {}   # peer_id -> last-known map name (TID-352)
var _party_panel: Node = null              # Party panel overlay (GID-107); roster lives inside it
var _party_roster_rows: Array = []         # cached roster row data fed into _party_panel
var _net_sync: Node = null
var _coop_active: bool = false
var _net_broadcast_accum: float = 0.0
# Persistent session (GID-095 / TID-346) — character adopted from the authority's
# SessionState; persist-back snapshots batched at _SESSION_SNAPSHOT_INTERVAL.
var _session_adopted: bool = false
var _session_token_by_peer: Dictionary = {}  # host: peer_id -> identity token
var _session_snapshot_accum: float = 0.0
const _SESSION_SNAPSHOT_INTERVAL: float = 5.0
# Co-op world-object sync (GID-096) — guarded by _coop_active; inert single-player.
var _coop_removed_enemies: Dictionary = {}  # enemy id -> true (engaged/defeated this session)
var _coop_opened_objects: Dictionary = {}   # object id -> true (chest opened this session)
var _coop_last_engaged_enemy_id: String = ""  # id of the enemy the local battle is against
var _coop_enemy_targets: Dictionary = {}    # enemy id -> Vector2(x,z) interp target (clients)
var _enemy_pos_accum: float = 0.0
# Party loot rolls (GID-102 / TID-381) — opt-in need/greed alternative to first-opener-takes.
# Authority only: roll_id -> {chest_id, item, tier, participants: Array[String],
# choices: {token: "need"|"greed"|"pass"}, timer: float}. Empty on clients and when unused.
var _loot_rolls_active: Dictionary = {}
const _LOOT_ROLL_TIMEOUT: float = 15.0
# Client (or host's own local UI): the currently-shown roll prompt, or {} when none.
var _pending_loot_roll: Dictionary = {}
var _loot_roll_panel: Node = null   # transient Need/Greed/Pass panel (CanvasLayer), nil when closed
# Co-op story mode (GID-098): true once a map transition is in flight on this
# WorldScene instance so duplicate recv_map_transition packets are ignored.
var _coop_map_transitioning: bool = false
# Rally waystones (GID-105 / TID-388) — guarded by NetworkManager.is_active().
var _last_rally_time: float = -999.0
const _RALLY_COOLDOWN: float = 3.0
# Downed & rescue in shared dungeons (GID-105 / TID-389) — guarded by _coop_active
# and current_map.begins_with("dungeon_"); inert everywhere else.
var _coop_downed: bool = false                # true while the LOCAL player is downed
var _coop_downed_peers: Dictionary = {}       # peer_id -> bool, mirrored via the avatar stream
var _dungeon_spawn_pos: Vector3 = Vector3.ZERO  # cached on entry to a "dungeon_*" map
var _downed_banner: Label = null
var _downed_started_at: float = 0.0
# Co-op story mode (GID-098): guard against re-entering the network broadcast
# while processing our own GameBus.story_flag_set echo.
var _coop_story_flag_syncing: bool = false
var _initial_ready_done: bool = false  # so _enter_tree re-setup only runs on re-entry
# PvP challenges (GID-091)
var _challenge_btn: Button = null
var _challenge_target_peer: int = -1     # nearby remote peer eligible to challenge
# Shared dungeon crawl (GID-102 / TID-380) — host-only trigger, now a Party-panel action.
var _pending_challenge_from: int = -1    # incoming challenge awaiting our response
var _pending_challenge_deck: Array = []  # challenger's deck stored until we accept
var _pending_challenge_ranked: bool = false  # GID-102 (TID-373): challenger's ranked opt-in
var _challenge_accept_panel: Node = null
const _CHALLENGE_RANGE: float = 3.0      # tiles; proximity to show the prompt
# Dedicated-server PvP routing (GID-097 / TID-353) — server tracks pending challenge
var _session_dedicated: bool = false      # client: true when connected to a dedicated server
var _pvp_relay_challenger_id: int = -1   # server: peer_id of the challenger awaiting response
var _pvp_relay_challenger_deck: Array = [] # server: challenger's deck
var _pvp_relay_target_id: int = -1       # server: peer_id of the challenged player
# Team PvP duels (GID-102 / TID-371): host-only trigger, visible at 4 players (host
# + 3 clients), now a Party-panel action. No accept/decline — keeps team-formation
# UI minimal (see task notes).
# Host-only: remembers the formation of the duel it started so _on_team_battle_ended_coop
# can resolve all 4 participants' tokens for the rating update. Empty when no team
# duel is in flight (the host itself never started one, or it already finished).
var _active_team_duel_peer_ids: Array[int] = []
var _active_team_duel_teams: Array = []
# Session tournaments (GID-104 / TID-386): host-run round-robin bracket. Guarded
# end-to-end by _tournament_active so it never touches normal PvP/team-duel state.
var _tournament_btn: Button = null
var _tournament_panel_outer: Control = null   # outer panel Control, nil when never built
var _tournament_panel: VBoxContainer = null   # inner row container
var _tournament_active: bool = false          # true while a bracket is in progress (both host+clients)
var _tournament_bracket: Dictionary = {}      # TournamentSync bracket dict; kept after finish for the panel
var _tournament_peer_ids: Array[int] = []     # host-only: participant idx -> peer id
var _tournament_tokens: Array[String] = []    # host-only: participant idx -> identity token
var _tournament_decks: Array = []             # host-only: participant idx -> deck instances
var _tournament_ante: int = 0                 # host-only: ante used to build the current bracket
var _tournament_pending_result: Dictionary = {}  # host-only: {} or {"winner_participant_idx": int}
var _tournament_current_is_host_match: bool = false  # host-only: is the in-flight match one the host is playing?
var _tournament_canonical_to_participant: Dictionary = {}  # host-only: {0: participant_idx, 1: participant_idx}
var _tournament_match_countdown: float = 0.0  # host-only: seconds until the next match starts (lets peers return to world + read the bracket)
const TOURNAMENT_ANTE_COINS: int = 25  # flat per-player entry fee; pot = ante * players
# GID-101 — Social & Rewards ──────────────────────────────────────────────────
# TID-365: Emotes & pings
const _SocialSync = preload("res://game_logic/net/SocialSync.gd")
var _emote_wheel_panel: Control = null   # the radial preset panel; nil when closed
var _ping_mode_active: bool = false      # true while player has ping mode toggled on
var _ping_btn: Button = null             # HUD toggle button for ping mode
var _emote_btn: Button = null            # HUD button that opens the emote wheel
var _ping_markers: Array[Node3D] = []    # active world-space ping markers
var _emote_timer_self: float = 0.0      # local avatar emote bubble countdown
var _emote_label_self: Label3D = null   # local avatar emote bubble
# TID-366: Card trading
const _TradeSync = preload("res://game_logic/net/TradeSync.gd")
var _trade_window: Node = null           # the two-sided trade UI, nil when closed
var _pending_trade: Dictionary = {}      # active trade offer held by authority
var _trade_window_mine: Button = null    # "Trade" HUD button (proximity-gated)
var _trade_target_peer: int = -1         # peer we'd trade with (nearest in range)
# TID-367: Spectating
var _pvp_active_peers: Array[int] = []  # host: peer_ids currently in a PvP duel
var _spectate_btn: Button = null         # shown to non-participants while duel active
# TID-368: Wagered duels & champion record
var _pending_wager_from: int = -1        # peer_id of an incoming wagered challenge
var _pending_wager_deck: Array = []      # challenger's deck for a wagered challenge
var _pending_wager_coins: int = 0        # ante for the pending wagered challenge
var _pvp_ante_coins: int = 0             # ante for the active duel (escrowed on start)
var _pvp_ante_peer0: int = -1           # host peer in the active wager
var _pvp_ante_peer1: int = -1           # client peer in the active wager
# TID-369: Shared party bounties
var _party_bounty_panel: VBoxContainer = null   # HUD panel showing shared progress
# TID-374: Party chat
const _ChatSync = preload("res://game_logic/net/ChatSync.gd")
var _chat_log_panel: Control = null        # outer panel (always visible while in co-op)
var _chat_log_vbox: VBoxContainer = null   # scrolling log of chat lines
var _chat_lines: Array[Dictionary] = []    # retained {name, color, text} rows, capped
var _chat_quick_panel: Control = null      # quick-chat preset button row; nil when closed
var _chat_input: LineEdit = null           # free-text input (desktop always-visible; mobile behind toggle)
var _chat_send_btn: Button = null          # send button next to the free-text input
var _chat_toggle_btn: Button = null        # HUD button: opens quick-chat row + reveals input (mobile parity)
# GID-102 / TID-376: Shared party stash
const _StashTransfer = preload("res://game_logic/net/StashTransfer.gd")
const _PartyStashOverlay = preload("res://scenes/ui/PartyStashOverlay.gd")
var _stash_overlay: Node = null           # PartyStashOverlay instance, nil when closed
var _stash_cache: Dictionary = {"cards": [], "coins": 0}  # last-known stash snapshot
# GID-102 / TID-378: Async card auction house
const _AuctionTransfer = preload("res://game_logic/net/AuctionTransfer.gd")
const _AuctionSync = preload("res://game_logic/net/AuctionSync.gd")
const _AuctionHouseOverlay = preload("res://scenes/ui/AuctionHouseOverlay.gd")
const _ChapterEndingOverlay = preload("res://scenes/ui/ChapterEndingOverlay.gd")
var _auction_btn: Button = null           # "Auction" HUD button (always visible in co-op)
var _auction_overlay: Node = null         # AuctionHouseOverlay instance, nil when closed
var _auction_cache: Array = []            # last-known listings snapshot
var _pvp_ended_pending_broadcast: bool = false  # set in pvp_battle_ended; cleared on _enter_tree
# GID-102 (TID-373): Ranked UI & leaderboard
var _leaderboard_rows: Array = []        # cached SessionState.get_leaderboard() rows
var _leaderboard_overlay: Node = null    # LeaderboardOverlay instance, nil when closed
var _ranked_toggle_btn: Button = null    # "Ranked" opt-in toggle next to the challenge button
var _ranked_toggle_on: bool = false      # local challenger's ranked opt-in state
var _pvp_ranked: bool = false            # ranked flag captured for the active duel (both peers)
# GID-102 (TID-379): PvE leaderboards (Endless Spire + co-op boss clears). Distinct
# cache/RPC names from the TID-373 ranked-rating board above — never touches rating.
var _pve_leaderboards: Dictionary = {"spire": [], "coop_clears": [], "night_hunts": []}  # cached snapshot
# GID-103 (TID-382): Synced world clock & weather — host-only rolling/broadcast state.
# Clients mirror the authority's days_elapsed/weather here since they have no
# SessionStore of their own to read from.
var _coop_env_broadcast_timer: float = 0.0
var _coop_weather_timer: float = 0.0
var _coop_weather_rng: RandomNumberGenerator = null
var _coop_env_days_elapsed: int = 0
var _coop_env_weather_id: String = ""
# GID-103 (TID-383): Party Night Hunts — deterministic spectral spawns on synced night.
var _coop_night_hunt_active: bool = false
var _coop_night_hunt_day: int = -1
var _coop_night_hunt_nodes: Dictionary = {}  # id -> Node3D
var _coop_night_hunt_kills: int = 0          # resets at dawn
# GID-103 (TID-384): Co-op Town Siege — host-only trigger; escalating waves + joint boss.
var _siege_btn: Button = null
var _coop_siege_active: bool = false
var _coop_siege_id: int = 0
var _coop_siege_wave: int = -1               # -1 = not started; >= WAVE_COUNT = boss phase
var _coop_siege_wave_nodes: Dictionary = {}  # id -> Node3D (current wave only)
# TID-377: Ghost duels — host-only Party-panel action + overlay (SessionStore is
# only ever open on the authority; a client has no local SessionState to list
# opponents from).
var _ghost_duel_overlay: Node = null
# GID-104 (TID-385): Draft duels — sealed-deck PvP. Both peers derive identical
# 1-of-3 pick rounds from one shared seed (DraftDuelGen); only the two finished
# TRANSIENT decks cross the wire. Drafted cards never touch owned_cards /
# SaveManager / SessionState. All state below is inert in single-player.
const _DraftDuelGen = preload("res://game_logic/net/DraftDuelGen.gd")
const _DraftDuelPickScene = preload("res://scenes/ui/DraftDuelPickScene.gd")
var _draft_duel_btn: Button = null      # proximity-gated HUD button (mobile + desktop)
var _pending_draft_from: int = -1       # incoming draft challenge awaiting our response
var _pending_draft_seed: int = 0        # seed carried by that pending challenge
var _draft_accept_panel: Node = null    # Accept/Decline prompt (CanvasLayer)
var _draft_peer: int = -1               # opponent peer for the outgoing/active draft
var _draft_seed: int = 0                # agreed shared seed for the active draft
var _draft_picking: bool = false        # true once the pick overlay is open
var _draft_picker: Node = null          # DraftDuelPickScene instance, nil when closed
var _draft_picker_layer: Node = null    # its CanvasLayer wrapper
var _draft_local_deck: Array = []       # my finished transient deck (instance dicts)
var _draft_opp_deck: Array = []         # opponent's finished transient deck
var _draft_local_done: bool = false
var _draft_opp_done: bool = false
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
var _terrain_mat: ShaderMaterial
var _last_save_pos: Vector2 = Vector2(-9999, -9999)
var _interact_timer: float = 0.0
var _roaming_boss_timer: float = 0.0
var _traveling_merchant_timer: float = 0.0
var _card_shower_items: Array[Node3D] = []

# Nocturnal spawn system (GID-055 Night Hunts)
var _nocturnal_enemies: Dictionary = {}        # spawn_id -> {"node": Node3D, "chunk": Vector2i}
var _nocturnal_spawn_timer: float = 0.0
var _nocturnal_spawn_interval: float = 45.0   # randomised each spawn
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
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect         = 0.7
	env.fog_light_color        = Color(0.70, 0.85, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 1.0
	# Filmic tone mapping lifts shadow detail and prevents blown highlights
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Bloom so emissive materials (items, coins) visibly glow
	env.glow_enabled = true
	env.glow_bloom = 0.25
	env.glow_intensity = 1.5
	env.glow_strength = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.5
	env.glow_hdr_luminance_cap = 12.0
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)
	# Fill light: soft sky-blue from above-opposite, no shadows, lifts black areas
	_fill_light = DirectionalLight3D.new()
	_fill_light.light_color = Color(0.55, 0.65, 0.85)
	_fill_light.light_energy = 0.5
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
	_setup_environment()
	_sun.shadow_opacity = 0.2
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
			if MapRegistry.get_map(map_name) != null:
				world_map = WorldMap.new(map_name)
			else:
				var parts: PackedStringArray = map_name.split("_")
				var sp_floor: int = int(parts[2]) if parts.size() > 2 else 1
				var sp_seed: int  = int(parts[3]) if parts.size() > 3 else 0
				world_map = SpireFloorGen.generate(sp_floor, sp_seed)
		else:
			world_map = WorldMap.new(map_name)
			if world_map.is_fallback:
				# Deferred so the dialogue label exists and the world is visible
				_show_dialogue.call_deferred(
					"Map '%s' could not be loaded — using a generated map instead." % map_name)

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

	if _is_infinite:
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 2
		floor_body.collision_mask = 0
		var floor_col := CollisionShape3D.new()
		floor_col.shape = WorldBoundaryShape3D.new()
		floor_body.add_child(floor_col)
		add_child(floor_body)
		var _inf_ref: Vector3 = _player.position if _player != null else _server_ref_pos
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
		var _named_ref: Vector3 = _player.position if _player != null else _server_ref_pos
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

	# Re-enter any battle that was interrupted (e.g. app quit mid-fight).
	# Dedicated server has no local player, so this is skipped.
	if not SceneManager.save_manager.pending_battle_enemy_data.is_empty() \
			and not NetworkManager.is_dedicated_server():
		GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)

	if not NetworkManager.is_dedicated_server():
		_interact_label.hide()
		_interact_label.text = "[Tap] Interact" if OS.has_feature("android") else "[E] Interact"

		var joystick := VirtualJoystick.new()
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
		AudioManager.play_music("res://assets/audio/music/dungeon.ogg")
		AudioManager.set_ambience(-1)  # -1 = named map / no biome ambience
		GameBus.entered_named_map.emit(map_name)
		if map_name.begins_with("dungeon_"):
			_dungeon_session_ui.reset_hero_hp()
	GameBus.battle_won.connect(_on_battle_won)
	GameBus.enemy_engaged.connect(_on_enemy_engaged_for_mount)
	GameBus.blight_changed.connect(_refresh_blight_tints)

	# Auto-remount when returning to the overworld from a named map
	if map_name == "main":
		var sm_ready := SceneManager.save_manager
		if sm_ready.active_mount != "" and not sm_ready.is_mounted:
			sm_ready.summon_mount(sm_ready.active_mount)

	# Co-op (GID-096): when the local player engages a shared enemy, tell the
	# authority so it is removed for everyone (engage-locks). Inert single-player.
	GameBus.enemy_engaged.connect(_on_enemy_engaged_coop)

	# Cancel tap-to-move path when battle or menu interrupts movement.
	GameBus.enemy_engaged.connect(func(_enemy_data: Dictionary) -> void: _clear_dest_marker())
	GameBus.inventory_requested.connect(_clear_dest_marker)
	GameBus.journal_requested.connect(_clear_dest_marker)

	# GID-101 (TID-368): champion record + wager payout when PvP ends. Connected
	# permanently (not in _setup_coop) because WorldScene is detached during battle.
	if not GameBus.pvp_battle_ended.is_connected(_on_pvp_battle_ended_coop):
		GameBus.pvp_battle_ended.connect(_on_pvp_battle_ended_coop)

	# GID-104 (TID-386): session tournaments — a referee'd match's real winner
	# (the host isn't a combatant) arrives via this dedicated signal instead of
	# pvp_battle_ended's plain bool. Same "connected permanently" reasoning.
	if not GameBus.pvp_referee_match_ended.is_connected(_on_pvp_referee_match_ended):
		GameBus.pvp_referee_match_ended.connect(_on_pvp_referee_match_ended)

	# GID-102 (TID-371): ranked rating for team duels. Same "connected permanently" reasoning.
	if not GameBus.team_battle_ended.is_connected(_on_team_battle_ended_coop):
		GameBus.team_battle_ended.connect(_on_team_battle_ended_coop)

	# GID-102 (TID-379): PvE leaderboard submission. Connected permanently (same
	# "WorldScene detaches during battle" reasoning as pvp_battle_ended above) so a
	# co-op boss clear is recorded regardless of which map/battle state re-attaches us.
	if not GameBus.coop_pve_battle_ended.is_connected(_on_coop_pve_battle_ended_leaderboard):
		GameBus.coop_pve_battle_ended.connect(_on_coop_pve_battle_ended_leaderboard)
	# GID-103 (TID-384): co-op Town Siege finale is the first caller of the joint PvE
	# engine — reset siege UI/state and grant party rewards on the outcome. Same
	# "connected permanently" reasoning (WorldScene detaches during the battle).
	if not GameBus.coop_pve_battle_ended.is_connected(_on_coop_siege_battle_ended):
		GameBus.coop_pve_battle_ended.connect(_on_coop_siege_battle_ended)
	# Spire runs happen while WorldScene is loaded (no battle-detach involved), but the
	# connection is still made once here (not in _setup_coop) so a Spire run that starts
	# before any co-op session is active still reaches this handler once co-op does start.
	if not GameBus.spire_run_ended.is_connected(_on_spire_run_ended_leaderboard):
		GameBus.spire_run_ended.connect(_on_spire_run_ended_leaderboard)

	if not NetworkManager.is_dedicated_server():
		_refresh_maiteln_presence()

	_setup_coop()
	_initial_ready_done = true

# Re-establish co-op when the world is re-attached after a PvP battle detached it
# (SceneManager keeps the WorldScene alive but removes it from the tree, which runs
# _exit_tree → _teardown_coop). On first load _ready handles setup, so this only
# fires on re-entry.
func _enter_tree() -> void:
	if _initial_ready_done and not _coop_active and NetworkManager.is_active():
		_setup_coop()
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

func _exit_tree() -> void:
	_teardown_coop()
	if _csm != null:
		_csm.exit_cleanup()
	if _active_weather_particles != null and is_instance_valid(_active_weather_particles):
		_active_weather_particles.queue_free()
	_active_weather_particles = null

# ── Co-op multiplayer (GID-090) ───────────────────────────────────────────────
# All of this is inert unless a NetworkManager session is active when the world
# loads. Single-player behaviour is unchanged.

func _setup_coop() -> void:
	if not NetworkManager.is_active():
		return
	if _coop_active:
		return
	_coop_active = true

	# Fixed-name RPC relay child. Path /root/WorldScene/NetSync matches on both
	# peers. Reused across a PvP battle detach (not freed in _teardown_coop).
	if _net_sync == null or not is_instance_valid(_net_sync):
		_net_sync = _NetSyncScript.new()
		_net_sync.name = "NetSync"
		_net_sync.set("world_scene", self)
		add_child(_net_sync)

	NetworkManager.peer_connected.connect(_on_coop_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_coop_peer_disconnected)
	NetworkManager.session_ended.connect(_on_coop_session_ended)

	# Dedicated server has no player, no HUD, no identity to share.
	if not NetworkManager.is_dedicated_server():
		_ensure_challenge_button()
		_ensure_draft_duel_button()
		_ensure_social_buttons()
		_ensure_chat_ui()
		_ensure_tournament_button()
		_ensure_siege_button()
		# Party panel (GID-107 / TID-395): single entry point for Roster, Loot Mode,
		# Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl.
		_world_hud.register_action("party", "Party", WorldHUD.ZONE_NAV, _open_party_panel)
		# Discoverability (GID-107 / TID-398): players used to the old scattered
		# buttons need a one-time nudge to the new consolidated entry point.
		# SceneManager dedups via the "seen_tutorial_party_panel" flag, so this is
		# safe to emit every time co-op becomes active (matches the "night_hunts"
		# precedent — emitter just emits, the handler owns the seen-once logic).
		GameBus.tutorial_popup_requested.emit("party_panel")
	# GID-101 (TID-369): host initialises party bounties; all peers build the HUD.
	_setup_party_bounties()
	if not NetworkManager.is_dedicated_server():
		_build_party_bounty_panel()

	# Host: surface the LAN IP so the other player knows what to type into
	# "Join by IP" (only shown on the first co-op entry, not on battle re-attach).
	if NetworkManager.is_host() and not NetworkManager.is_dedicated_server() and not _initial_ready_done:
		var lan_ip: String = NetworkManager.get_lan_ip()
		if lan_ip != "":
			SceneManager.show_toast("Hosting", "Other player: Join by IP  →  %s" % lan_ip)

	# Spawn avatars for peers already connected when this world loads (the
	# client-joining-host case; the host's peer is already present).
	for pid in multiplayer.get_peers():
		_spawn_remote_player(int(pid))

	# Persistent session (GID-095 / TID-346): the host (authority) opens its session
	# file and adopts its own character; clients adopt on the character handshake.
	_setup_session()

	# Co-op story mode (GID-098): sync story flag changes through the authority.
	if not GameBus.story_flag_set.is_connected(_on_local_story_flag_set):
		GameBus.story_flag_set.connect(_on_local_story_flag_set)

	# Identity handshake (TID-342): broadcast this peer's identity to everyone
	# already in-world. Dedicated server has no player identity to share.
	if not NetworkManager.is_dedicated_server():
		_refresh_coop_roster()
		_send_local_identity(false, 0)

func _teardown_coop() -> void:
	if not _coop_active:
		return
	if NetworkManager.peer_connected.is_connected(_on_coop_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_coop_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_coop_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_coop_peer_disconnected)
	if NetworkManager.session_ended.is_connected(_on_coop_session_ended):
		NetworkManager.session_ended.disconnect(_on_coop_session_ended)
	if GameBus.story_flag_set.is_connected(_on_local_story_flag_set):
		GameBus.story_flag_set.disconnect(_on_local_story_flag_set)
	# Keep _net_sync alive across a battle detach so the RPC node persists; set
	# inactive so re-entry (_enter_tree) re-runs setup and reconnects signals.
	_coop_active = false

func _spawn_remote_player(pid: int) -> void:
	if _remote_player_nodes.has(pid):
		return
	# Seed near the local player but fan out by a deterministic per-peer ring offset
	# so up to 4 avatars don't stack on the shared SPAWN tile before packets flow.
	var base_x: float = _player.position.x if _player != null else 0.0
	var base_z: float = _player.position.z if _player != null else 0.0
	var off: Vector2 = _AvatarSync.spawn_offset(pid, IsoConst.TILE_SIZE)
	var spawn_x: float = base_x + off.x
	var spawn_z: float = base_z + off.y
	var rp: Node3D = _RemotePlayerScene.instantiate() as Node3D
	rp.set("world_scene", self)
	rp.init_from_data({"peer_id": pid, "x": spawn_x, "z": spawn_z})
	# Map-scoped sync (TID-352): hidden until the first packet confirms the peer is on
	# our map, so a peer on a different map never flashes a cross-map ghost on load.
	rp.visible = false
	_entity_root.add_child(rp)
	_remote_player_nodes[pid] = rp
	# Apply identity if it already arrived before the avatar spawned (lazy ordering).
	if _remote_identities.has(pid):
		_apply_identity_to_avatar(pid)

func _on_coop_peer_connected(pid: int) -> void:
	_spawn_remote_player(pid)

func _on_coop_peer_disconnected(pid: int) -> void:
	var rp: Node = _valid_node(_remote_player_nodes.get(pid))
	if is_instance_valid(rp):
		rp.queue_free()
	_remote_player_nodes.erase(pid)
	_remote_identities.erase(pid)
	_remote_player_maps.erase(pid)
	_session_token_by_peer.erase(pid)
	# Downed & rescue (GID-105 / TID-389): a disconnected peer can't be revived or
	# time out anymore — drop their entry so a stale revive request can't match it.
	_coop_downed_peers.erase(pid)
	# Draft duel (GID-104 / TID-385): abort a draft in flight with this peer.
	_abort_draft_duel_for_peer(pid)
	# Flush so the leaving player's last persisted snapshot is on disk (host only).
	if NetworkManager.is_host():
		SessionStore.flush_now()
	# GID-104 (TID-386): a tournament participant disconnecting mid-bracket has no
	# resume/refund path in v1 (documented gap) — abort cleanly rather than leave
	# the bracket stuck forever waiting for a match that can never finish.
	if _tournament_active and NetworkManager.is_host() and _tournament_peer_ids.has(pid):
		_reset_tournament_state()
		_tournament_bracket = {}
		if _net_sync != null:
			_net_sync.rpc("recv_tournament_update", _TournamentSync.encode_bracket({}))
		_refresh_tournament_panel()
		GameBus.hud_message_requested.emit("Tournament aborted — a player disconnected.")
	_refresh_coop_roster()

func _on_coop_session_ended() -> void:
	for pid in _remote_player_nodes.keys():
		var rp: Node = _valid_node(_remote_player_nodes[pid])
		if is_instance_valid(rp):
			rp.queue_free()
	_remote_player_nodes.clear()
	_remote_identities.clear()
	_remote_player_maps.clear()
	_session_token_by_peer.clear()
	# Downed & rescue (GID-105 / TID-389) is session-scoped state.
	_coop_downed_peers.clear()
	if _coop_downed:
		_exit_downed_state()
	# Co-op world-object sync state (GID-096) is session-scoped; clear it so a fresh
	# session starts from the deterministic spawn (persisted progress reloads via
	# _setup_session / the join snapshot).
	_coop_removed_enemies.clear()
	_coop_opened_objects.clear()
	_coop_enemy_targets.clear()
	_coop_last_engaged_enemy_id = ""
	# Party loot rolls (GID-102 / TID-381) are session-scoped too.
	_loot_rolls_active.clear()
	_pending_loot_roll = {}
	# Draft duel (GID-104 / TID-385): session gone — abort any draft in flight.
	_abort_draft_duel()
	# Session tournaments (GID-104 / TID-386) are session-scoped: a bracket cannot
	# outlive the session that scheduled it. No refunds in v1 (documented gap).
	_reset_tournament_state()
	_tournament_bracket = {}
	_refresh_tournament_panel()
	if _loot_roll_panel != null and is_instance_valid(_loot_roll_panel):
		_loot_roll_panel.queue_free()
	_loot_roll_panel = null
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.queue_free()
	_party_panel = null
	# Authority owns the session file: flush + close it on session end (host left /
	# server stopped). On clients SessionStore is never open, so this is a no-op.
	if SessionStore.is_open():
		SessionStore.close(true)
	_session_adopted = false
	_refresh_coop_roster()
	# Shared world life (GID-103) is session-scoped: clear the night hunt and
	# siege state so a fresh session starts clean.
	_coop_despawn_night_hunt()
	_coop_siege_active = false
	_coop_siege_wave = -1
	_coop_siege_wave_nodes.clear()
	if _siege_banner != null and is_instance_valid(_siege_banner):
		_siege_banner.queue_free()
	_siege_banner = null
	_coop_env_weather_id = ""
	_coop_weather_rng = null
	_coop_active = false

# ── Player identity handshake (GID-094 / TID-342) ─────────────────────────────

## Broadcast (target_peer == 0) or unicast this peer's identity. `is_reply` marks
## the one-shot direct answer so the exchange terminates after one round-trip.
func _send_local_identity(is_reply: bool, target_peer: int) -> void:
	if not _coop_active or _net_sync == null or not NetworkManager.is_active():
		return
	var payload: Array = _PlayerIdentity.encode(
		MpProfile.get_token(), MpProfile.get_display_name(), MpProfile.get_color())
	if target_peer == 0:
		_net_sync.rpc("recv_identity", payload, is_reply)
	else:
		_net_sync.rpc_id(target_peer, "recv_identity", payload, is_reply)

## Called by NetSync when a peer's identity packet arrives.
func _on_identity_received(sender: int, payload: Array, is_reply: bool) -> void:
	var d: Dictionary = _PlayerIdentity.decode(payload)
	_remote_identities[sender] = d
	_apply_identity_to_avatar(sender)
	_refresh_coop_roster()
	# Authority: now that we know this peer's token, resolve + send its session
	# character (resume or fresh starter). GID-095 / TID-346.
	if NetworkManager.is_host():
		_send_character_to_peer(sender, str(d.get("token", "")), str(d.get("name", "Player")))
		# World-object snapshot (GID-096): reconcile the joiner's freshly-spawned
		# enemies/chests to the live + persisted removed/opened sets.
		_send_world_snapshot_to_peer(sender)
		# Co-op story mode (GID-098): send the shared story flags so the new peer
		# has the same story state as the rest of the party.
		_send_story_flags_snapshot_to_peer(sender)
		# Co-op story mode (GID-098): if the party has already moved beyond the
		# default lobby map, redirect the late joiner to the party's current map.
		if SessionStore.is_open() and _net_sync != null:
			var st = SessionStore.get_state()
			if st != null and st.current_map != "" and st.current_map != map_name:
				_net_sync.rpc_id(sender, "recv_map_transition", st.current_map, "")
	# Answer an initiator's broadcast exactly once so it learns our identity too.
	if not is_reply:
		_send_local_identity(true, sender)

## Push a stored identity onto the matching RemotePlayer avatar, if spawned.
func _apply_identity_to_avatar(pid: int) -> void:
	var rp: Node = _valid_node(_remote_player_nodes.get(pid))
	if not is_instance_valid(rp) or not rp.has_method("set_player_identity"):
		return
	var d: Dictionary = _remote_identities.get(pid, {})
	var nm: String = str(d.get("name", "Player"))
	var col: Color = d.get("color", Color.WHITE)
	rp.set_player_identity(nm, col)

# ── Persistent session character (GID-095 / TID-346) ──────────────────────────
# The authority (host) owns SessionStore and the per-player character roster, keyed
# by the GID-094 identity token. The host adopts its own character here; each client
# adopts the record the host sends on the identity handshake. All guarded by
# _coop_active / NetworkManager.is_host(); inert in single-player and on clients.

func _setup_session() -> void:
	# Re-entry after a PvP battle keeps the same WorldScene (SessionStore stays open),
	# so only the first co-op entry initialises + adopts.
	if _session_adopted:
		return
	if not NetworkManager.is_host():
		return  # clients adopt later, in _on_character_received
	SessionStore.open(MpProfile.get_host_session_id(),
		"%s's world" % MpProfile.get_display_name())
	var st = SessionStore.get_state()
	if st != null:
		st.current_map = map_name
		st.world_seed = SceneManager.save_manager.world_seed
		SessionStore.mark_dirty()
		# GID-103 (TID-382): resume the host's own clock from the persisted session
		# value (a fresh session's default 0.4 matches _dnc's own default, so this is
		# a no-op the first time a session file is created).
		if _dnc != null:
			_dnc.set_time_of_day(st.time_of_day)
	var token: String = MpProfile.get_token()
	var resume: bool = st != null and st.has_member(token)
	var rec: Dictionary = SessionStore.ensure_member(token, MpProfile.get_display_name())
	if rec.is_empty():
		return
	SceneManager.save_manager.adopt_session_character(rec)
	if resume:
		_restore_session_position(rec)
	_session_adopted = true
	# Reconcile the deterministically-spawned world to the session's persisted
	# progress (defeated enemies / opened chests) so a resumed host world matches
	# what was left behind (GID-096).
	if st != null:
		_coop_apply_world_progress(st.defeated_enemies, st.opened_chests)
		for eid in st.defeated_enemies:
			_coop_removed_enemies[str(eid)] = true
		for cid in st.opened_chests:
			_coop_opened_objects[str(cid)] = true
		# Co-op story mode (GID-098): restore session story flags so the host
		# re-entering a saved co-op session sees the correct story state.
		if not st.story_flags.is_empty():
			_coop_story_flag_syncing = true
			for key in st.story_flags:
				SceneManager.save_manager.story_flags[str(key)] = bool(st.story_flags[key])
			_coop_story_flag_syncing = false
		# GID-102 (TID-373): seed the host's own leaderboard cache immediately so the
		# roster badge + leaderboard panel are populated even before any peer joins or
		# any duel has been played this session (e.g. a solo host re-entering a session
		# with existing ranked history).
		_leaderboard_rows = st.get_leaderboard(20) if st != null else []
		# GID-102 (TID-379): same seeding for the PvE leaderboards cache.
		_pve_leaderboards = st.get_pve_leaderboards_snapshot() if st != null else \
			{"spire": [], "coop_clears": []}

## Client: adopt the character record the host resolved for our token. On a resume
## the host flags it so we also restore our saved position.
func _on_character_received(record: Dictionary, resume: bool) -> void:
	if record.is_empty():
		return
	SceneManager.save_manager.adopt_session_character(record)
	if resume:
		_restore_session_position(record)
	_session_adopted = true
	_refresh_coop_roster()

## Host: a client pushed its latest character snapshot — persist it under its token.
func _on_character_submitted(sender: int, record: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var token: String = str(_session_token_by_peer.get(sender, ""))
	if token == "":
		token = str(record.get("token", ""))
	if token == "":
		return
	SessionStore.update_member(token, record)

## Host: resolve (or create) the character for a just-identified client and send it.
## Called from _on_identity_received once the client's token is known.
func _send_character_to_peer(peer_id: int, token: String, member_name: String) -> void:
	if not NetworkManager.is_host() or _net_sync == null:
		return
	if token == "" or not SessionStore.is_open():
		return
	_session_token_by_peer[peer_id] = token
	var st = SessionStore.get_state()
	var resume: bool = st != null and st.has_member(token)
	var rec: Dictionary = SessionStore.ensure_member(token, member_name)
	if rec.is_empty():
		return
	_net_sync.rpc_id(peer_id, "recv_character", rec, resume)
	if NetworkManager.is_dedicated_server():
		_net_sync.rpc_id(peer_id, "set_session_flags", {"dedicated": true})
	# GID-101 (TID-369): send party bounties snapshot so joining client is in sync.
	if st != null and not (st.party_bounties as Array).is_empty():
		_net_sync.rpc_id(peer_id, "recv_party_bounties_snapshot", st.party_bounties)
	# GID-102 (TID-373): send the current leaderboard so the joining client's roster
	# badges + leaderboard panel start populated instead of showing "—" until the
	# next duel ends.
	if st != null:
		_net_sync.rpc_id(peer_id, "recv_leaderboard", st.get_leaderboard(20))
	# GID-102 (TID-376): send the current stash snapshot so the joining client's
	# panel starts populated instead of showing stale/empty until the next change.
	if st != null:
		_net_sync.rpc_id(peer_id, "recv_stash_update", st.stash)
		# GID-102 (TID-379): send the current PvE leaderboards snapshot alongside it so
		# a joining client's Spire/Co-op-clears tabs start populated too.
		_net_sync.rpc_id(peer_id, "recv_pve_leaderboards", st.get_pve_leaderboards_snapshot())
		# GID-102 (TID-378): send the current auction listings snapshot so a joining
		# client's Auction House panel starts populated instead of empty.
		_net_sync.rpc_id(peer_id, "recv_auction_update", st.auctions)
		# GID-103 (TID-382): send the current clock/weather so a late joiner never
		# sees a mismatched sky before the next low-Hz broadcast tick.
		if _dnc != null:
			_net_sync.rpc_id(peer_id, "recv_env_state",
				_EnvSync.encode(_dnc.get_time_of_day(), st.days_elapsed, st.weather_id))

## Move the local player to the position stored in a session record (same map only).
func _restore_session_position(record: Dictionary) -> void:
	if _player == null or str(record.get("map", "")) != map_name:
		return
	var x: float = float(record.get("x", 0.0))
	var z: float = float(record.get("z", 0.0))
	_player.position = Vector3(x, get_terrain_height(x, z), z)

## Build a session record from the local in-memory character + current position.
func _build_local_character_record() -> Dictionary:
	var rec: Dictionary = SceneManager.save_manager.export_session_character()
	rec["token"] = MpProfile.get_token()
	rec["display_name"] = MpProfile.get_display_name()
	rec["map"] = map_name
	rec["x"] = _player.position.x if _player != null else 0.0
	rec["z"] = _player.position.z if _player != null else 0.0
	return rec

## Persist-back tick (called from _process at _SESSION_SNAPSHOT_INTERVAL): host writes
## its own member directly; clients send an intent the host merges + persists.
func _tick_session_persist(delta: float) -> void:
	if not _coop_active or not _session_adopted or not NetworkManager.is_active():
		return
	_session_snapshot_accum += delta
	if _session_snapshot_accum < _SESSION_SNAPSHOT_INTERVAL:
		return
	_session_snapshot_accum = 0.0
	var rec: Dictionary = _build_local_character_record()
	if NetworkManager.is_host():
		SessionStore.update_member(MpProfile.get_token(), rec)
		_sweep_expired_auctions()
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_character", rec)

# ── In-world session roster (GID-094 / TID-342) ───────────────────────────────
# GID-107 (TID-395): the roster no longer builds its own always-visible HUD panel —
# it recomputes _party_roster_rows and, if the Party panel is currently open,
# pushes the update into it. The row data/shape is unchanged from the old
# _add_roster_row() calls, just collected into an Array[Dictionary] instead of
# built straight into Control nodes.

## Rebuild the roster row data: local player first, then each connected remote.
func _refresh_coop_roster() -> void:
	_party_roster_rows.clear()
	if _coop_active:
		# Rating badge (GID-102 / TID-373): looked up from the cached leaderboard rows by
		# identity token; shows "—" until the first snapshot arrives.
		var my_rating: String = _rating_badge_for_token(MpProfile.get_token())
		_party_roster_rows.append({
			"text": "%s (you)  [%s]" % [MpProfile.get_display_name(), my_rating],
			"color": MpProfile.get_color(),
			"token": "",
		})
		for pid in _remote_player_nodes.keys():
			var d: Dictionary = _remote_identities.get(pid, {})
			var nm: String = str(d.get("name", "Player"))
			var col: Color = d.get("color", Color(0.7, 0.85, 1.0))
			var token: String = str(d.get("token", ""))
			# Friends list (GID-102 / TID-375): a friend currently in-session is "seen now".
			if token != "":
				MpProfile.touch_friend_last_seen(token)
			var clean_name: String = nm
			# Rating badge (GID-102 / TID-373): looked up from the cached leaderboard rows.
			var rating_badge: String = _rating_badge_for_token(token)
			nm += "  [%s]" % rating_badge
			# Map-scoped sync (TID-352): peers on another map are greyed + "(elsewhere)".
			var peer_map: String = str(_remote_player_maps.get(pid, map_name))
			if peer_map != "" and peer_map != map_name:
				nm += " (elsewhere)"
				col = col.darkened(0.45)
			_party_roster_rows.append({
				"text": nm,
				"color": col,
				"token": token,
				"clean_name": clean_name,
				"is_friend": MpProfile.is_friend(token) if token != "" else false,
			})
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.refresh_roster(_party_roster_rows)

## Party loot rolls (GID-102 / TID-381): host-only toggle between the default
## first-opener-takes rule and the opt-in need/greed roll. Now a Party-panel
## action (GID-107 / TID-395) rather than its own always-visible HUD button.
func _loot_mode_label_text() -> String:
	return "Loot: Need/Greed" if _coop_loot_mode_is_need_greed() else "Loot: First-Opener"

func _on_loot_mode_toggle_pressed() -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var new_mode: String = _SessionState.LOOT_MODE_FIRST_OPENER
	if not _coop_loot_mode_is_need_greed():
		new_mode = _SessionState.LOOT_MODE_NEED_GREED
	SessionStore.set_loot_mode(new_mode)
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.refresh_loot_label(_loot_mode_label_text())
	GameBus.hud_message_requested.emit(
		"Loot mode: %s" % ("Need/Greed" if new_mode == _SessionState.LOOT_MODE_NEED_GREED else "First-Opener"))

## Opens (or closes, if already open) the Party panel (GID-107 / TID-395):
## Roster, Loot Mode, Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl —
## each section keeps the exact gating/behavior its old standalone button had.
func _open_party_panel() -> void:
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.queue_free()
		_party_panel = null
		return
	var panel := _PartyPanel.new()
	panel.roster_rows = _party_roster_rows
	panel.on_add_friend = func(token: String, clean_name: String, color: Color) -> void:
		MpProfile.add_friend(token, clean_name, color.to_html(false))
		_refresh_coop_roster()
	# Loot mode (host-only, same gate as the old button's press-handler check).
	panel.show_loot_mode = NetworkManager.is_host() and SessionStore.is_open()
	panel.loot_mode_label = _loot_mode_label_text()
	panel.on_loot_mode_toggle = _on_loot_mode_toggle_pressed
	# Stash / Leaderboard: always available while co-op is active (global to the
	# session, not proximity-gated) — matches the old buttons' gating exactly.
	panel.show_stash = true
	panel.on_stash = _toggle_stash_overlay
	panel.show_leaderboard = true
	panel.on_leaderboard = _toggle_leaderboard_overlay
	# Ghost Duels: host-only, gated on SessionStore.is_open() (see _ensure_ghost_duel_button's
	# old comment — a client never opens SessionStore locally).
	panel.show_ghost_duels = SessionStore.is_open()
	panel.on_ghost_duels = _toggle_ghost_duel_overlay
	# Team Duel: host-only, needs 3 connected clients (4 total) — mirrors the old
	# _update_team_duel_button_visibility() condition exactly.
	panel.show_team_duel = NetworkManager.is_host() and not NetworkManager.is_dedicated_server() \
		and SceneManager._state == SceneManager.State.WORLD \
		and multiplayer.get_peers().size() >= 3 and _pending_challenge_from == -1
	panel.on_team_duel = _start_team_duel
	# Dungeon Crawl: host-only trigger — mirrors the old _ensure_dungeon_button() gate.
	panel.show_dungeon_crawl = NetworkManager.is_host()
	panel.on_dungeon_crawl = _start_dungeon_crawl
	_hud.add_child(panel)
	panel.closed.connect(func() -> void: _party_panel = null)
	_party_panel = panel

# Called by NetSync when a remote avatar packet arrives.
func _on_avatar_received(sender: int, payload: Array) -> void:
	var rp: Node = _valid_node(_remote_player_nodes.get(sender))
	if not is_instance_valid(rp):
		# Packet arrived before the connect signal was processed — spawn now.
		_spawn_remote_player(sender)
		rp = _valid_node(_remote_player_nodes.get(sender))
	var d: Dictionary = _AvatarSync.decode(payload)
	# Map-scoped avatar sync (TID-352): only render a peer that is on our map. An
	# empty map (legacy/garbage payload) is treated as same-map so nothing regresses.
	var sender_map: String = str(d.get("map", ""))
	var prev_map: String = str(_remote_player_maps.get(sender, ""))
	_remote_player_maps[sender] = sender_map
	if prev_map != sender_map:
		_refresh_coop_roster()
	var same_map: bool = sender_map == "" or sender_map == map_name
	# Downed & rescue (GID-105 / TID-389): mirror the sender's downed flag regardless
	# of map (cheap bookkeeping) but only apply the visual tint when they're rendered.
	var sender_downed: bool = bool(d.get("downed", false))
	_coop_downed_peers[sender] = sender_downed
	if not is_instance_valid(rp):
		return
	(rp as Node3D).visible = same_map
	if rp.has_method("set_downed"):
		rp.set_downed(sender_downed)
	# Only feed position while on the same map; otherwise the avatar holds its last
	# same-map position so re-convergence resumes cleanly (no cross-map coordinates).
	if same_map and rp.has_method("set_net_state"):
		rp.set_net_state(d["x"], d["z"], d["flip_h"], d["moving"])

# Broadcast the local avatar's state at 15 Hz. Called from _process.
func _broadcast_local_avatar(delta: float) -> void:
	if not _coop_active or _net_sync == null or _player == null:
		return
	if not NetworkManager.is_active():
		return
	_net_broadcast_accum += delta
	if _net_broadcast_accum < _NET_BROADCAST_INTERVAL:
		return
	_net_broadcast_accum = 0.0
	var flip_h: bool = false
	var spr: AnimatedSprite3D = _player.get("_sprite") as AnimatedSprite3D
	if spr != null:
		flip_h = spr.flip_h
	var moving: bool = bool(_player.get("_is_moving"))
	var payload: Array = _AvatarSync.encode(
		_player.position.x, _player.position.z, flip_h, moving, map_name, _coop_downed)
	_net_sync.rpc("recv_avatar", payload)

# ── Co-op world-object sync (GID-096) ─────────────────────────────────────────
# The authority (host) owns the canonical lifecycle of shared world objects
# (enemies, chests). Enemies/chests are spawned deterministically from the shared
# map on every peer, so only *discrete* state changes are synced: an enemy engaged
# (removed for all — engage-locks), an enemy defeated (persisted to the session
# file), a chest opened (reflected for all + persisted). Positions are correct by
# construction; a low-Hz position stream exists for future moving enemies. All
# guarded by _coop_active; single-player hits none of this.

## True only when a co-op session is live and this peer is the authority (host).
func _coop_world_authority() -> bool:
	return _coop_active and NetworkManager.is_active() and NetworkManager.is_host()

## Local player engaged an enemy. Authority broadcasts its removal to all peers;
## a client submits the intent and lets the authority fan it out. Either way the
## engaging peer already removed the node locally (EnemyNPC.engage queue_free'd it).
## Records the id so a subsequent battle win can persist the defeat.
func _on_enemy_engaged_coop(edata: Dictionary) -> void:
	if not _coop_active or _net_sync == null or not NetworkManager.is_active():
		return
	var eid: String = str(edata.get("id", ""))
	if eid == "":
		return
	# GID-103 (TID-384): the siege finale boss is a joint battle for the whole
	# party, not a solo engage-lock fight — route it separately and skip the
	# normal single-player-battle path entirely.
	if _coop_siege_active and eid.begins_with("siege_boss_"):
		_coop_engage_siege_boss(edata)
		return
	_coop_last_engaged_enemy_id = eid
	if NetworkManager.is_host():
		_coop_removed_enemies[eid] = true
		_net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_REMOVED, eid))
	else:
		_net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_ENGAGED, eid))

## Persist a co-op battle victory against a shared enemy. Host writes the session
## file directly; a client submits the defeat for the host to persist. Called from
## _on_battle_won when a session is active.
func _coop_persist_enemy_defeat() -> void:
	if not _coop_active or not NetworkManager.is_active():
		return
	var eid: String = _coop_last_engaged_enemy_id
	_coop_last_engaged_enemy_id = ""
	if eid == "":
		return
	if NetworkManager.is_host():
		_coop_record_enemy_defeated(eid)
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_DEFEATED, eid))
	# GID-103 (TID-383): tally + announce a party night-hunt kill and record it to
	# the session's night_hunts leaderboard (best single-night tally per member).
	if eid.begins_with("night_hunt_"):
		_coop_night_hunt_kills += 1
		_submit_pve_score("night_hunts", _coop_night_hunt_kills)
		GameBus.hud_message_requested.emit("Spectral kill! (%d tonight)" % _coop_night_hunt_kills)
		if _coop_night_hunt_kills == 5:
			GameBus.hud_message_requested.emit("The party has defeated 5 spectral enemies tonight!")

## Host-only: record a defeated enemy into the session file (resumes on reconnect).
func _coop_record_enemy_defeated(eid: String) -> void:
	_coop_removed_enemies[eid] = true
	var st = SessionStore.get_state()
	if st != null and not st.defeated_enemies.has(eid):
		st.defeated_enemies.append(eid)
		SessionStore.mark_dirty()

## Local player opened a chest. Authority persists + broadcasts; a client submits the
## intent. The opener keeps the loot (first-opener-takes); peers only flip it open.
func _on_chest_opened_coop(cid: String) -> void:
	if not _coop_active or _net_sync == null or not NetworkManager.is_active() or cid == "":
		return
	_coop_opened_objects[cid] = true
	if NetworkManager.is_host():
		_coop_record_chest_opened(cid)
		_net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_CHEST_OPENED, cid))
	else:
		_net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_CHEST_OPENED, cid))

## Host-only: persist an opened chest into the session file.
func _coop_record_chest_opened(cid: String) -> void:
	_coop_opened_objects[cid] = true
	var st = SessionStore.get_state()
	if st != null and not st.opened_chests.has(cid):
		st.opened_chests.append(cid)
		SessionStore.mark_dirty()

## Remove a shared enemy node locally (a peer reflecting the authority's removal).
func _coop_remove_enemy_node(eid: String) -> void:
	_coop_removed_enemies[eid] = true
	_coop_enemy_targets.erase(eid)
	var node: Node3D = _valid_node3d(_enemy_nodes.get(eid))
	if is_instance_valid(node):
		if node.has_method("mark_defeated"):
			node.mark_defeated()
		else:
			node.queue_free()
	_enemy_nodes.erase(eid)

## Flip a shared chest node to opened locally (no loot — first-opener already took it).
func _coop_mark_chest_opened_node(cid: String) -> void:
	_coop_opened_objects[cid] = true
	if _active_chest_data.has(cid):
		(_active_chest_data[cid] as Dictionary)["opened"] = true
	var node: Node3D = _valid_node3d(_chest_nodes.get(cid))
	if is_instance_valid(node) and node.has_method("mark_opened"):
		node.mark_opened()

## NetSync → peer: apply a discrete world event from the authority.
func _on_world_event_received(_sender: int, payload: Array) -> void:
	if not _coop_active:
		return
	var ev: Dictionary = _WorldObjectSync.decode_event(payload)
	var kind: String = str(ev.get("kind", ""))
	var id: String = str(ev.get("id", ""))
	if id == "":
		return
	match kind:
		_WorldObjectSync.EV_ENEMY_REMOVED:
			_coop_remove_enemy_node(id)
		_WorldObjectSync.EV_CHEST_OPENED:
			_coop_mark_chest_opened_node(id)

## NetSync → authority: apply a client's world-event intent (host only).
func _on_world_event_submitted(sender: int, payload: Array) -> void:
	if not _coop_world_authority():
		return
	var ev: Dictionary = _WorldObjectSync.decode_event(payload)
	var kind: String = str(ev.get("kind", ""))
	var id: String = str(ev.get("id", ""))
	if id == "":
		return
	match kind:
		_WorldObjectSync.EV_ENEMY_ENGAGED:
			# A client engaged a shared enemy: drop it on the host and fan the
			# removal out to every other peer (the sender already removed its own).
			_coop_remove_enemy_node(id)
			for pid in multiplayer.get_peers():
				if int(pid) != sender:
					_net_sync.rpc_id(int(pid), "recv_world_event",
						_WorldObjectSync.encode_event(_WorldObjectSync.EV_ENEMY_REMOVED, id))
		_WorldObjectSync.EV_ENEMY_DEFEATED:
			_coop_record_enemy_defeated(id)
		_WorldObjectSync.EV_CHEST_OPENED:
			_coop_record_chest_opened(id)
			_coop_mark_chest_opened_node(id)
			for pid in multiplayer.get_peers():
				if int(pid) != sender:
					_net_sync.rpc_id(int(pid), "recv_world_event",
						_WorldObjectSync.encode_event(_WorldObjectSync.EV_CHEST_OPENED, id))

## Host: send the current removed/opened snapshot to a just-joined peer.
func _send_world_snapshot_to_peer(peer_id: int) -> void:
	if not _coop_world_authority() or _net_sync == null:
		return
	var payload: Array = _WorldObjectSync.encode_snapshot(
		_coop_removed_enemies.keys(), _coop_opened_objects.keys())
	_net_sync.rpc_id(peer_id, "recv_world_snapshot", payload)

## Client: reconcile freshly-spawned nodes to the authority's snapshot on join.
func _on_world_snapshot_received(payload: Array) -> void:
	if not _coop_active:
		return
	var snap: Dictionary = _WorldObjectSync.decode_snapshot(payload)
	_coop_apply_world_progress(
		snap.get("removed_enemies", []), snap.get("opened_objects", []))

# ── Synced world clock & weather (GID-103 / TID-382) ──────────────────────────
# The authority (host) is the single source of truth for time_of_day/days_elapsed/
# weather. Its own local DayNightCycle (_dnc) already advances every frame — this
# section only adds the low-Hz broadcast (+ the co-op-only weather roll, since
# WeatherManager is hard-gated to the "main" infinite-world map). Clients apply the
# broadcast read-only to their own _dnc and to weather visuals. Guarded by
# _coop_active + not _is_infinite (co-op stays on finite named maps); single-player
# and the infinite world are completely untouched.

## Host-only: roll/broadcast tick, called every frame from _process while co-op is
## active. A no-op on clients (they only ever receive recv_env_state) and on the
## infinite world (WeatherManager already owns weather there).
func _tick_env_sync(delta: float) -> void:
	if _is_infinite or not _coop_world_authority() or _dnc == null:
		return
	_coop_weather_timer -= delta
	var weather_rolled: bool = false
	if _coop_weather_timer <= 0.0:
		_coop_weather_timer = _coop_roll_weather()
		weather_rolled = true
	_coop_env_broadcast_timer -= delta
	if weather_rolled or _coop_env_broadcast_timer <= 0.0:
		_coop_env_broadcast_timer = _ENV_BROADCAST_INTERVAL
		_broadcast_env_state()

## Host-only: pick the next weather id + duration, apply it locally, and persist it.
## Returns the seconds until the next reroll.
func _coop_roll_weather() -> float:
	if _coop_weather_rng == null:
		_coop_weather_rng = RandomNumberGenerator.new()
		var seed_val: int = 0
		if SessionStore.is_open():
			seed_val = SessionStore.get_state().world_seed
		_coop_weather_rng.seed = seed_val if seed_val != 0 else randi()
	var weather_id: String = _EnvSync.roll_weather(_coop_weather_rng)
	var duration: float = _EnvSync.roll_duration(_coop_weather_rng, weather_id)
	if SessionStore.is_open():
		SessionStore.get_state().weather_id = weather_id
		SessionStore.mark_dirty()
	_on_weather_changed(weather_id, duration)
	return duration

## Host-only: broadcast the current clock/weather to every peer.
func _broadcast_env_state() -> void:
	if not _coop_world_authority() or _net_sync == null or _dnc == null:
		return
	var days: int = 0
	var weather_id: String = ""
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		days = st.days_elapsed
		weather_id = st.weather_id
	_net_sync.rpc("recv_env_state", _EnvSync.encode(_dnc.get_time_of_day(), days, weather_id))

## Any peer: apply the authority's clock/weather broadcast (or late-join snapshot).
func _on_env_state_received(payload: Array) -> void:
	if not _coop_active:
		return
	var d: Dictionary = _EnvSync.decode(payload)
	if _dnc != null:
		_dnc.set_time_of_day(float(d.get("time_of_day", 0.4)))
	_coop_env_days_elapsed = int(d.get("days_elapsed", 0))
	var weather_id: String = str(d.get("weather_id", ""))
	if weather_id != _coop_env_weather_id:
		_coop_env_weather_id = weather_id
		if not _is_infinite:
			_on_weather_changed(weather_id, 0.0)

## The current shared co-op day counter, read from the authoritative SessionStore on
## the host or from the last-received broadcast on a client. Used to key the
## deterministic night-hunt/siege plans so every peer computes the same result.
func _coop_current_days_elapsed() -> int:
	if NetworkManager.is_host() and SessionStore.is_open():
		return SessionStore.get_state().days_elapsed
	return _coop_env_days_elapsed

# ── Party Night Hunts (GID-103 / TID-383) ─────────────────────────────────────
# Deterministic spectral spawns on the shared co-op map at synced night — reuses
# the GID-096 engage-lock/defeat sync generically (the spawn id alone keys it, no
# new event kind or RPC needed: EnemyNPC.engage() emits enemy_data["id"], and
# _on_enemy_engaged_coop already handles any id). Guarded by _coop_active + not
# _is_infinite — the infinite world keeps its own single-player nocturnal system
# (GID-055) untouched.

## Called every frame from _process while co-op is active. Spawns/despawns the
## whole nightly hunt as the synced clock crosses the night/day boundary.
func _coop_update_night_hunts(_delta: float) -> void:
	if not _coop_active or _is_infinite or not _CoopNightHunts.supports_map(map_name):
		return
	var is_night: bool = _dnc != null and _dnc.is_night_now()
	var days: int = _coop_current_days_elapsed()
	if is_night:
		if not _coop_night_hunt_active or _coop_night_hunt_day != days:
			_coop_spawn_night_hunt(days)
	elif _coop_night_hunt_active:
		_coop_despawn_night_hunt()

## Spawn tonight's deterministic spectral enemies. Every peer computes the exact
## same plan independently (see CoopNightHunts.generate_hunt) — nothing is
## broadcast for the spawn itself, only the later engage/defeat events.
func _coop_spawn_night_hunt(days: int) -> void:
	if _coop_night_hunt_active:
		_coop_despawn_night_hunt()
	_coop_night_hunt_active = true
	_coop_night_hunt_day = days
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(map_name, Vector3.ZERO)
	var plan: Array[Dictionary] = _CoopNightHunts.generate_hunt(map_name, days)
	var spawned_any: bool = false
	for entry: Dictionary in plan:
		var eid: String = str(entry.get("id", ""))
		if eid == "" or _coop_removed_enemies.has(eid):
			continue  # already engaged/defeated earlier tonight (e.g. re-entering the map)
		var off: Vector2 = entry.get("offset", Vector2.ZERO)
		var wx: float = gate.x + off.x
		var wz: float = gate.z + off.y
		var wy: float = get_terrain_height(wx, wz) + 0.5
		var node: Node3D = _EnemyScene.instantiate() as Node3D
		if node == null:
			continue
		node.set_meta("is_nocturnal", true)
		node.call("init_from_data", {
			"id": eid,
			"enemy_type": str(entry.get("enemy_type", "spectre_wisp")),
			"tracking": true,
		})
		node.position = Vector3(wx, wy, wz)
		node.modulate = Color(0.7, 0.85, 1.0, 0.85)
		_entity_root.add_child(node)
		_enemy_nodes[eid] = node
		_coop_night_hunt_nodes[eid] = node
		spawned_any = true
	if spawned_any:
		GameBus.hud_message_requested.emit("The party hears spectral howls on the wind…")

## Dawn (or map exit): clear tonight's surviving hunt nodes and reset the tally.
func _coop_despawn_night_hunt() -> void:
	for eid: String in _coop_night_hunt_nodes.keys():
		var n: Node3D = _valid_node3d(_coop_night_hunt_nodes[eid])
		if is_instance_valid(n):
			n.queue_free()
		_enemy_nodes.erase(eid)
	_coop_night_hunt_nodes.clear()
	_coop_night_hunt_active = false
	_coop_night_hunt_kills = 0

# ── Party loot rolls (GID-102 / TID-381) ──────────────────────────────────────
# Opt-in need/greed alternative to the GID-096 first-opener-takes chest rule.
# Guarded by _coop_active + the session's loot_mode; completely inert (and this whole
# section unreached) when the mode is left at the default "first_opener".

## True when a co-op session has need/greed loot mode enabled. Reads the live
## SessionState on the host; a client mirrors the flag locally when it receives
## a roll-start broadcast (there's nothing to read before the first roll on a client,
## which is fine — a client never decides to start a roll, only the authority does).
func _coop_loot_mode_is_need_greed() -> bool:
	if not SessionStore.is_open():
		return false
	return SessionStore.get_loot_mode() == _SessionState.LOOT_MODE_NEED_GREED

## Opener (host or client) triggers a roll for a just-opened chest's drop. The chest's
## position/card ids/tier are re-derived from _active_chest_data[cid] rather than sent
## over the wire — chests are deterministically spawned from the same map data on every
## peer (the GID-096 invariant), so the authority already knows the exact same values the
## opener does without needing a payload for the item shape.
func _start_loot_roll(cid: String, chest_tier: int) -> void:
	if _coop_world_authority():
		_authority_open_loot_roll(cid, chest_tier)
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_loot_roll_request", cid, chest_tier)

## Client → authority: "a chest I opened should start a need/greed roll." The chest-open
## itself is already synced via the existing EV_CHEST_OPENED path; this only carries the
## tier (the id is enough for the host to re-derive position/card ids locally).
func _on_loot_roll_request_submitted(sender: int, cid: String, chest_tier: int) -> void:
	if not _coop_world_authority():
		return
	_authority_open_loot_roll(cid, chest_tier)


## Authority: build the roll session for a chest's resolved drop and broadcast the prompt
## to every connected session member (present = connected to the session; a same-map/
## proximity filter was judged out of scope for v1 — documented in the task).
func _authority_open_loot_roll(cid: String, chest_tier: int) -> void:
	if _loot_roll_by_chest(cid) != "":
		return  # a roll for this chest is already in flight — never double-grant
	var chest_data: Dictionary = _active_chest_data.get(cid, {}) as Dictionary
	var chest_card_ids: Array[String] = []
	chest_card_ids.assign(chest_data.get("card_ids", []))
	var roll_id: String = "roll_%s_%d" % [cid, Time.get_ticks_msec()]
	var participants: Array = []
	participants.append(MpProfile.get_token())
	for token in _session_token_by_peer.values():
		if not participants.has(token):
			participants.append(str(token))
	_loot_rolls_active[roll_id] = {
		"chest_id": cid,
		"card_ids": chest_card_ids,
		"tier": chest_tier,
		"participants": participants,
		"choices": {},
		"timer": 0.0,
	}
	var item: Dictionary = {"card_ids": chest_card_ids, "tier": chest_tier}
	var payload: Dictionary = _LootRoll.encode_start(roll_id, item, participants)
	if _net_sync != null:
		_net_sync.rpc("recv_loot_roll_start", payload)
	_on_loot_roll_start_received(payload)  # authority also sees its own prompt


## Find the in-flight roll_id for a chest id, or "" if none (authority only; empty dict
## on clients so this is always "").
func _loot_roll_by_chest(cid: String) -> String:
	for rid in _loot_rolls_active.keys():
		if str((_loot_rolls_active[rid] as Dictionary).get("chest_id", "")) == cid:
			return str(rid)
	return ""


## Any peer (including the authority itself): show the Need/Greed/Pass prompt.
func _on_loot_roll_start_received(payload: Dictionary) -> void:
	var start: Dictionary = _LootRoll.decode_start(payload)
	if str(start.get("roll_id", "")) == "":
		return
	_pending_loot_roll = start
	_show_loot_roll_panel(start)


## Local player picked Need/Greed/Pass. Sends the choice to the authority (or applies
## it directly if this peer IS the authority).
func _submit_loot_roll_choice(roll_id: String, choice: String) -> void:
	if _loot_roll_panel != null and is_instance_valid(_loot_roll_panel):
		_loot_roll_panel.queue_free()
		_loot_roll_panel = null
	_pending_loot_roll = {}
	if NetworkManager.is_host():
		_on_loot_roll_choice_submitted(multiplayer.get_unique_id(), roll_id, choice)
	elif _net_sync != null:
		var payload: Array = _LootRoll.encode_choice(roll_id, choice)
		_net_sync.rpc_id(1, "submit_loot_roll_choice", payload[0], payload[1])


## Authority: record a participant's choice. Resolves early once every expected
## participant has responded (rather than always waiting out the full timeout).
func _on_loot_roll_choice_submitted(sender: int, roll_id: String, choice: String) -> void:
	if not _coop_world_authority():
		return
	if not _loot_rolls_active.has(roll_id):
		return
	var roll: Dictionary = _loot_rolls_active[roll_id]
	var token: String = str(_session_token_by_peer.get(sender,
		MpProfile.get_token() if sender == multiplayer.get_unique_id() else ""))
	if token == "":
		return
	var choices: Dictionary = roll.get("choices", {})
	choices[token] = _LootRoll.normalize_choice(choice)
	roll["choices"] = choices
	_loot_rolls_active[roll_id] = roll
	var participants: Array = roll.get("participants", [])
	if choices.size() >= participants.size():
		_settle_loot_roll(roll_id)


## Ticked from _process while any roll is in flight (authority only). Missing
## responses auto-pass once the timeout elapses.
func _tick_loot_rolls(delta: float) -> void:
	if not _coop_world_authority() or _loot_rolls_active.is_empty():
		return
	for roll_id in _loot_rolls_active.keys().duplicate():
		var roll: Dictionary = _loot_rolls_active[roll_id]
		var t: float = float(roll.get("timer", 0.0)) + delta
		roll["timer"] = t
		_loot_rolls_active[roll_id] = roll
		if t >= _LOOT_ROLL_TIMEOUT:
			_settle_loot_roll(str(roll_id))


## Authority: resolve the winner (missing participants auto-pass), grant the loot to
## the winner's session character, persist, and broadcast the result. No item is ever
## granted twice — the roll is removed from _loot_rolls_active before any grant happens.
func _settle_loot_roll(roll_id: String) -> void:
	if not _loot_rolls_active.has(roll_id):
		return
	var roll: Dictionary = _loot_rolls_active[roll_id]
	_loot_rolls_active.erase(roll_id)
	var participants: Array = roll.get("participants", [])
	var choices: Dictionary = (roll.get("choices", {}) as Dictionary).duplicate()
	for token in participants:
		if not choices.has(str(token)):
			choices[str(token)] = _LootRoll.CHOICE_PASS
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var outcome: Dictionary = _LootRoll.resolve_winner(choices, rng)
	var winner_token: String = str(outcome.get("winner_token", ""))
	var rolls: Dictionary = outcome.get("rolls", {})
	if winner_token != "":
		var chest_card_ids: Array[String] = []
		chest_card_ids.assign(roll.get("card_ids", []))
		_grant_chest_loot_to_token(winner_token, chest_card_ids, int(roll.get("tier", 1)))
	var payload: Dictionary = _LootRoll.encode_result(roll_id, winner_token, rolls)
	if _net_sync != null:
		_net_sync.rpc("recv_loot_roll_result", payload)
	_on_loot_roll_result_received(payload)


## Authority: grant a resolved chest's cards + a flat coin reward directly into the
## winner's GID-095 session character record (they may not be the local player, so this
## reuses the direct-SessionStore-write pattern from _transfer_card_in_session /
## party-bounty rewards rather than the physical WorldItem pickup path, which only ever
## grants to the local opener). Equipment drops are out of scope for the roll path — no
## session-scoped equipment inventory exists to grant to an arbitrary winner (see BID).
func _grant_chest_loot_to_token(token: String, card_ids: Array[String], tier: int) -> void:
	var st = SessionStore.get_state()
	if st == null or token == "":
		return
	var rec: Dictionary = st.get_member(token)
	if rec.is_empty():
		return
	var owned: Array = rec.get("owned_cards", []) as Array
	var counter: int = owned.size()
	for cid_tpl: String in card_ids:
		var rarity: String = _CardDropUtil.effective_rarity(cid_tpl, _CardDropUtil.roll_rarity(tier))
		var stats: Dictionary = _CardDropUtil.roll_stats(cid_tpl, rarity)
		var uid: String = "%s_%s_roll_%d" % [cid_tpl, token, counter]
		counter += 1
		owned.append(_CardInstanceUtil.make(
			uid, cid_tpl, rarity,
			int(stats.get("attack", 0)), int(stats.get("health", 0)), int(stats.get("cost", 1))))
	rec["owned_cards"] = owned
	rec["coins"] = int(rec.get("coins", 0)) + randi_range(5, 20) * 3
	st.update_member(token, rec)
	SessionStore.mark_dirty()


## Any peer: announce the winner (toast) and close the prompt if one was open.
func _on_loot_roll_result_received(payload: Dictionary) -> void:
	if _loot_roll_panel != null and is_instance_valid(_loot_roll_panel):
		_loot_roll_panel.queue_free()
		_loot_roll_panel = null
	_pending_loot_roll = {}
	var result: Dictionary = _LootRoll.decode_result(payload)
	var winner_token: String = str(result.get("winner_token", ""))
	if winner_token == "":
		GameBus.hud_message_requested.emit("Loot roll: everyone passed — nothing claimed.")
		return
	var winner_name: String = _display_name_for_token(winner_token)
	GameBus.hud_message_requested.emit("%s won the loot roll!" % winner_name)


## Public accessor for SceneManager.session_token_for_peer (GID-104 / TID-387),
## called from BattleScene while this scene is detached from the tree during a PvP
## battle/spectate session (spectator-wager escrow needs to resolve a spectator's
## peer_id to their GID-095 session token). Returns "" for an unresolved peer (e.g.
## the identity handshake hasn't completed) — callers must treat that as ineligible.
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
func _show_loot_roll_panel(start: Dictionary) -> void:
	if _loot_roll_panel != null and is_instance_valid(_loot_roll_panel):
		_loot_roll_panel.queue_free()
		_loot_roll_panel = null
	var roll_id: String = str(start.get("roll_id", ""))
	var item: Dictionary = start.get("item", {})
	var card_ids: Array = item.get("card_ids", [])
	var tier: int = int(item.get("tier", 1))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var layer := CanvasLayer.new()
	layer.layer = 183
	add_child(layer)
	_loot_roll_panel = layer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.02))
	panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Loot roll! Tier %d chest — %d card(s).\nNeed, Greed, or Pass?" % [tier, card_ids.size()]
	lbl.add_theme_font_size_override("font_size", int(vh * 0.026))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.025))
	vbox.add_child(row)
	var need_btn := Button.new()
	need_btn.text = "Need"
	need_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.06)
	need_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	need_btn.pressed.connect(_submit_loot_roll_choice.bind(roll_id, _LootRoll.CHOICE_NEED))
	row.add_child(need_btn)
	var greed_btn := Button.new()
	greed_btn.text = "Greed"
	greed_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.06)
	greed_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	greed_btn.pressed.connect(_submit_loot_roll_choice.bind(roll_id, _LootRoll.CHOICE_GREED))
	row.add_child(greed_btn)
	var pass_btn := Button.new()
	pass_btn.text = "Pass"
	pass_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.06)
	pass_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	pass_btn.pressed.connect(_submit_loot_roll_choice.bind(roll_id, _LootRoll.CHOICE_PASS))
	row.add_child(pass_btn)

# ── Co-op story mode — shared story flags (GID-098 / TID-356) ────────────────

## Host: send current session story flags to a just-joined peer.
func _send_story_flags_snapshot_to_peer(peer_id: int) -> void:
	if not _coop_world_authority() or _net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	_net_sync.rpc_id(peer_id, "recv_story_flags_snapshot", st.story_flags.duplicate())

## Client: apply the session story flags on join so NPCs/gates are consistent.
func _on_story_flags_snapshot_received(flags: Dictionary) -> void:
	if not _coop_active:
		return
	_coop_story_flag_syncing = true
	for key in flags:
		var val: bool = bool(flags[key])
		SceneManager.save_manager.story_flags[key] = val
		if val:
			GameBus.story_flag_set.emit(str(key))
	_coop_story_flag_syncing = false

## Called when GameBus.story_flag_set fires locally (any setter).
## Routes the flag change through the authority so the whole party stays in sync.
func _on_local_story_flag_set(key: String) -> void:
	# Maiteln's journey presence (GID-108 / TID-403) is gated on several Chapter 1
	# flags that can flip while this exact map/WorldScene instance stays loaded
	# (rabbit hunt won, fire learned, temple council resolved) — re-evaluate on
	# every flag change so he appears/disappears immediately, not just on the
	# next map load. Runs before the co-op-only early return below: single-player
	# needs this too.
	if not NetworkManager.is_dedicated_server():
		_refresh_maiteln_presence()
	if not _coop_active or _net_sync == null or not NetworkManager.is_active():
		return
	if _coop_story_flag_syncing:
		return
	var value: bool = SceneManager.save_manager.get_story_flag(key)
	if NetworkManager.is_host():
		# Apply to session state and broadcast to all clients.
		if SessionStore.is_open():
			var st = SessionStore.get_state()
			if st != null:
				st.story_flags[key] = value
				SessionStore.mark_dirty()
		_coop_story_flag_syncing = true
		_net_sync.rpc("recv_story_flag", key, value)
		_coop_story_flag_syncing = false
	else:
		# Submit intent to authority; the authority will broadcast back to everyone.
		_net_sync.rpc_id(1, "submit_story_flag", key, value)

## Any peer: the authority broadcast a flag change — apply locally.
func _on_story_flag_received(key: String, value: bool) -> void:
	if not _coop_active:
		return
	_coop_story_flag_syncing = true
	SceneManager.save_manager.story_flags[key] = value
	if value:
		GameBus.story_flag_set.emit(key)
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null:
			st.story_flags[key] = value
			SessionStore.mark_dirty()
	_coop_story_flag_syncing = false

## Authority: a client wants to set a flag — arbitrate (idempotent) and broadcast.
func _on_story_flag_submitted(sender: int, key: String, value: bool) -> void:
	if not _coop_world_authority() or _net_sync == null:
		return
	# Idempotency: if the flag is already this value, skip side-effects.
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null and st.story_flags.get(key, false) == value:
			return
		if st != null:
			st.story_flags[key] = value
			SessionStore.mark_dirty()
	_coop_story_flag_syncing = true
	SceneManager.save_manager.story_flags[key] = value
	if value:
		GameBus.story_flag_set.emit(key)
	# Broadcast to all peers (including the submitter so their SaveManager is synced).
	_net_sync.rpc("recv_story_flag", key, value)
	_coop_story_flag_syncing = false

## Remove already-resolved enemy nodes and flip opened chests. Shared by host resume
## (_setup_session) and client join (_on_world_snapshot_received).
func _coop_apply_world_progress(removed_enemies: Array, opened_objects: Array) -> void:
	for eid in removed_enemies:
		_coop_remove_enemy_node(str(eid))
	for cid in opened_objects:
		_coop_mark_chest_opened_node(str(cid))

## Host: broadcast positions for any live shared enemy at a low Hz (inert while all
## enemies are static, as on every current co-op map). Called from _process.
func _broadcast_enemy_positions(delta: float) -> void:
	if not _coop_world_authority() or _net_sync == null or _enemy_nodes.is_empty():
		return
	_enemy_pos_accum += delta
	if _enemy_pos_accum < _ENEMY_POS_INTERVAL:
		return
	_enemy_pos_accum = 0.0
	var states: Array = []
	for eid in _enemy_nodes.keys():
		var raw = _enemy_nodes.get(eid)
		if is_instance_valid(raw):
			var node: Node3D = raw
			states.append(_EnemySync.encode_state(
				str(eid), node.position.x, node.position.z, true))
	if not states.is_empty():
		_net_sync.rpc("recv_enemy_positions", _EnemySync.encode_batch(states))

## Client: store the latest authority positions; _process interpolates toward them.
func _on_enemy_positions_received(payload: Array) -> void:
	if not _coop_active or NetworkManager.is_host():
		return
	for st: Dictionary in _EnemySync.decode_batch(payload):
		var eid: String = str(st.get("id", ""))
		if eid == "" or _coop_removed_enemies.has(eid):
			continue
		_coop_enemy_targets[eid] = Vector2(float(st.get("x", 0.0)), float(st.get("z", 0.0)))

## Client: smooth shared enemies toward their last synced position (no-op for static
## enemies, where target == spawn). Called from _process.
func _interp_synced_enemies(delta: float) -> void:
	if _coop_enemy_targets.is_empty():
		return
	for eid in _coop_enemy_targets.keys():
		var node: Node3D = _valid_node3d(_enemy_nodes.get(eid))
		if not is_instance_valid(node):
			_coop_enemy_targets.erase(eid)
			continue
		var tgt2: Vector2 = _coop_enemy_targets[eid]
		var target: Vector3 = Vector3(tgt2.x, get_terrain_height(tgt2.x, tgt2.y), tgt2.y)
		node.position = _EnemySync.interp(node.position, target, delta, 12.0)

# ── Co-op story mode — map transitions (GID-098 / TID-355) ───────────────────

## Received from any peer: follow them to target_map / door_id.
## Guards against double-transition on the same WorldScene instance.
func _on_map_transition_received(target_map: String, door_id: String) -> void:
	if not _coop_active:
		return
	if _coop_map_transitioning:
		return
	# A peer already on the destination map (e.g. everyone but the rallier, in a
	# rally-to-peer broadcast — GID-105 / TID-388) has nothing to follow; re-entering
	# would needlessly reload the map and reset their position to the spawn/door
	# default.
	if not target_map.is_empty() and target_map == map_name:
		return
	_coop_map_transitioning = true
	if target_map.is_empty():
		SceneManager.exit_map()
	else:
		SceneManager.enter_map(target_map, door_id)

# ── Rally waystones (GID-105 / TID-388) ──────────────────────────────────────
# Lets any connected party member teleport instantly to a teammate from the
# fast-travel UI — same-map is an instant local position sync, cross-map reuses
# the TID-355 followed-transition mechanism (so the rest of the party, if any,
# converges too). Guarded by NetworkManager.is_active(); single-player fast
# travel sees no rally section at all (MapViewOverlay._rally_targets is empty).

## Connected session members eligible for rally-to: everyone whose last-known
## map we've learned (skips late-joiners whose location hasn't arrived yet).
func _build_rally_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not NetworkManager.is_active():
		return out
	for pid in _remote_identities.keys():
		var peer_map: String = str(_remote_player_maps.get(pid, ""))
		if peer_map == "":
			continue
		var ident: Dictionary = _remote_identities[pid]
		out.append({
			"peer_id": int(pid),
			"name": str(ident.get("name", "Player")),
			"color": ident.get("color", Color.WHITE),
			"map": peer_map,
		})
	return out

## Rally to a connected teammate. Same-map: instant local position sync.
## Cross-map: broadcast the existing followed-transition RPC + follow locally.
func _rally_to_peer(peer_id: int) -> void:
	if not NetworkManager.is_active() or _player == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_rally_time < _RALLY_COOLDOWN:
		GameBus.hud_message_requested.emit("Rally is on cooldown.")
		return
	var target_map: String = str(_remote_player_maps.get(peer_id, ""))
	if target_map == "":
		return
	var target_name: String = str(_remote_identities.get(peer_id, {}).get("name", "Player"))
	_last_rally_time = now
	GameBus.hud_message_requested.emit("Rallying to %s…" % target_name)
	if _net_sync != null:
		_net_sync.rpc_id(peer_id, "recv_rally_notice", MpProfile.get_display_name())
	if target_map == map_name:
		var rp: Node3D = _valid_node3d(_remote_player_nodes.get(peer_id))
		if rp != null and is_instance_valid(rp):
			_player.global_position = rp.global_position
		return
	if _coop_map_transitioning:
		return
	_coop_map_transitioning = true
	if _net_sync != null:
		_net_sync.rpc("recv_map_transition", target_map, "")
	SceneManager.enter_map(target_map, "")

## A teammate is rallying to us — surface a hero-moment toast.
func _on_rally_notice_received(rallier_name: String) -> void:
	GameBus.hud_message_requested.emit("%s is rallying to you!" % rallier_name)

# ── Downed & rescue in shared dungeons (GID-105 / TID-389) ───────────────────
# A PvE loss inside a co-op shared dungeon ("dungeon_*") leaves the player downed
# (frozen in place) instead of routing to the single-player defeat screen
# (SceneManager._on_battle_lost intercepts before that path). A teammate can
# revive them via the same interact prompt pattern as chests/NPCs; otherwise a
# self-managed timeout auto-respawns them at the dungeon entrance. The downed
# flag itself rides the existing AvatarSync stream (see _on_avatar_received);
# only the revive action needs host arbitration, to avoid two teammates racing
# to revive the same target.

## Called by SceneManager (via _saved_world_scene.call) right after the world is
## restored following a co-op-dungeon PvE loss.
func enter_downed_state() -> void:
	if not _coop_active or _player == null:
		return
	_coop_downed = true
	_coop_downed_peers[NetworkManager.local_id()] = true
	_downed_started_at = Time.get_ticks_msec() / 1000.0
	_player.set_physics_process(false)
	_set_player_alpha(0.55)
	_show_downed_banner()
	GameBus.hud_message_requested.emit("Downed! Waiting for rescue…")
	get_tree().create_timer(_DownedSync.RESCUE_TIMEOUT, false).timeout.connect(_on_downed_timeout)

## Fires RESCUE_TIMEOUT seconds after enter_downed_state(). No-ops if already
## revived (a stale timer from a downed period that already ended).
func _on_downed_timeout() -> void:
	if not _coop_downed:
		return
	GameBus.hud_message_requested.emit("Respawning at the dungeon entrance…")
	if _player != null:
		_player.position = _dungeon_spawn_pos
	_exit_downed_state()

## Un-freeze the local player and clear downed bookkeeping (revived or timed out).
func _exit_downed_state() -> void:
	_coop_downed = false
	_coop_downed_peers[NetworkManager.local_id()] = false
	if _player != null:
		_player.set_physics_process(true)
		_set_player_alpha(1.0)
	_hide_downed_banner()

func _show_downed_banner() -> void:
	if _downed_banner != null and is_instance_valid(_downed_banner):
		_downed_banner.show()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_downed_banner = Label.new()
	_downed_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_banner.add_theme_font_size_override("font_size", int(vp.y * 0.030))
	_downed_banner.add_theme_color_override("font_color", Color(0.75, 0.80, 1.0))
	_downed_banner.custom_minimum_size = Vector2(vp.x * 0.6, vp.y * 0.06)
	_downed_banner.position = Vector2(vp.x * 0.2, vp.y * 0.12)
	_hud.add_child(_downed_banner)

func _hide_downed_banner() -> void:
	if _downed_banner != null and is_instance_valid(_downed_banner):
		_downed_banner.queue_free()
		_downed_banner = null

## Nearest downed teammate within range, or -1. Local player is never a valid
## target here — you cannot revive yourself.
func _find_nearby_downed_peer(px: float, pz: float, range_dist: float) -> int:
	if not _coop_active:
		return -1
	for pid in _remote_player_nodes.keys():
		if not bool(_coop_downed_peers.get(pid, false)):
			continue
		var rp: Node3D = _valid_node3d(_remote_player_nodes[pid])
		if not is_instance_valid(rp) or not rp.visible:
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(Vector2(px, pz))
		if d <= range_dist:
			return int(pid)
	return -1

## Local player interacted with a downed teammate. Host applies directly;
## a client submits the request for the host to arbitrate.
func _request_revive(peer_id: int) -> void:
	if NetworkManager.is_host():
		_authority_apply_revive(peer_id)
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_revive_request", peer_id)

## Host-only: validate and apply a revive, then broadcast it. A stale request
## (target already respawned via timeout, or already revived) is silently
## discarded — DownedSync.can_revive centralizes that check.
func _authority_apply_revive(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return
	if not _DownedSync.can_revive(bool(_coop_downed_peers.get(peer_id, false))):
		return
	_coop_downed_peers[peer_id] = false
	if peer_id == NetworkManager.local_id():
		_exit_downed_state()
	else:
		var rp: Node3D = _valid_node3d(_remote_player_nodes.get(peer_id))
		if rp != null and is_instance_valid(rp) and rp.has_method("set_downed"):
			rp.set_downed(false)
	GameBus.hud_message_requested.emit("Revived!")
	if _net_sync != null:
		_net_sync.rpc("recv_revive", peer_id)

## NetSync → host: a client's revive request.
func _on_revive_request_submitted(_sender: int, peer_id: int) -> void:
	_authority_apply_revive(peer_id)

## NetSync → peer: the host confirmed a revive.
func _on_revive_received(peer_id: int) -> void:
	if not _coop_active:
		return
	_coop_downed_peers[peer_id] = false
	if peer_id == NetworkManager.local_id():
		_exit_downed_state()
		GameBus.hud_message_requested.emit("Revived!")
	else:
		var rp: Node3D = _valid_node3d(_remote_player_nodes.get(peer_id))
		if rp != null and is_instance_valid(rp) and rp.has_method("set_downed"):
			rp.set_downed(false)

# ── Shared dungeon crawl (GID-102 / TID-380) ──────────────────────────────────
#
# madrian (and any other co-op-supported named map) has no authored dungeon
# door, so the party has no way to reach DungeonGen's procedural dungeons
# together. This adds a host-only HUD trigger that picks a shared seed and
# broadcasts the same "dungeon_<seed>" map name via the existing TID-355
# recv_map_transition RPC — no new sync RPC needed, since DungeonGen is a pure
# function of (name, seed) and WorldScene's dungeon-load branch only inspects
# the map_name string, not how it was constructed.

## Host-only: derive a shared seed and broadcast the transition so every peer
## follows into the identical generated dungeon.
func _start_dungeon_crawl() -> void:
	if not NetworkManager.is_host():
		return  # defensive: don't trust client-side button visibility alone
	if not _coop_active or _net_sync == null or _coop_map_transitioning:
		return
	var seed_val: int = randi()
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		# world_seed + days_elapsed: reopening the crawl on the same in-game day
		# reproduces the same dungeon; a new day yields a fresh one.
		seed_val = hash(str(st.world_seed) + "_dungeon_" + str(st.days_elapsed))
	var target_map: String = "dungeon_%d" % seed_val
	_coop_map_transitioning = true
	_net_sync.rpc("recv_map_transition", target_map, "")
	SceneManager.enter_map(target_map, "")

# ── Co-op Town Siege (GID-103 / TID-384) ──────────────────────────────────────
#
# Host-only trigger (same precedent as the Dungeon Crawl button above): a
# deterministic siege id seeds WAVE_COUNT escalating raider waves, each spawned
# identically on every peer (CoopSiege.generate_wave) and synced purely through
# the existing GID-096 engage-lock events — no new spawn RPC needed, only "advance
# to wave N" / "start the boss phase" broadcasts. The finale boss hands off to the
# GID-099 joint PvE battle engine (this is that engine's first caller) so the
# whole party fights it together; victory splits gold + a card among every
# session member.

## Creates the hidden "Siege" HUD button. Visible only for the host, and only on
## a map with a known town-gate anchor (SiegeDefs.TOWN_GATES).
func _ensure_siege_button() -> void:
	if not _CoopSiege.supports_map(map_name):
		return
	if _siege_btn != null and is_instance_valid(_siege_btn):
		_siege_btn.visible = NetworkManager.is_host() and not _coop_siege_active
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_siege_btn = Button.new()
	_siege_btn.text = "Siege"
	_siege_btn.tooltip_text = "Trigger a party siege defense event"
	_siege_btn.custom_minimum_size = Vector2(vp.y * 0.22, vp.y * 0.06)
	_siege_btn.add_theme_font_size_override("font_size", int(vp.y * 0.024))
	_siege_btn.position = Vector2((vp.x - vp.y * 0.22) * 0.5, vp.y * 0.63)
	_siege_btn.visible = NetworkManager.is_host() and not _coop_siege_active
	_siege_btn.pressed.connect(_start_coop_siege)
	_hud.add_child(_siege_btn)

## Host-only: derive a shared siege id and broadcast the start so every peer
## begins the identical wave sequence.
func _start_coop_siege() -> void:
	if not NetworkManager.is_host() or _net_sync == null:
		return
	if not _coop_active or _coop_siege_active or not _CoopSiege.supports_map(map_name):
		return
	var siege_id: int = randi()
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		# world_seed + days_elapsed: retriggering later the same day reproduces the
		# same waves; a new day yields a fresh sequence (mirrors _start_dungeon_crawl).
		siege_id = hash(str(st.world_seed) + "_siege_" + str(st.days_elapsed))
	_net_sync.rpc("recv_siege_started", siege_id)
	_on_siege_started_received(siege_id)

## Any peer: a siege has begun — reset local state and spawn wave 0.
func _on_siege_started_received(siege_id: int) -> void:
	if not _coop_active:
		return
	_coop_siege_active = true
	_coop_siege_id = siege_id
	_coop_siege_wave = 0
	if _siege_btn != null and is_instance_valid(_siege_btn):
		_siege_btn.visible = false
	GameBus.hud_message_requested.emit("The town is under siege!")
	_coop_spawn_siege_wave()

## Spawn the current wave's deterministic raiders (identical on every peer).
func _coop_spawn_siege_wave() -> void:
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(map_name, Vector3.ZERO)
	var plan: Array[Dictionary] = _CoopSiege.generate_wave(map_name, _coop_siege_id, _coop_siege_wave)
	_coop_siege_wave_nodes.clear()
	for entry: Dictionary in plan:
		var eid: String = str(entry.get("id", ""))
		if eid == "" or _coop_removed_enemies.has(eid):
			continue
		var off: Vector2 = entry.get("offset", Vector2.ZERO)
		var wx: float = gate.x + off.x
		var wz: float = gate.z + off.y
		var wy: float = get_terrain_height(wx, wz) + 0.5
		var node: Node3D = _EnemyScene.instantiate() as Node3D
		if node == null:
			continue
		node.call("init_from_data", {"id": eid, "enemy_type": str(entry.get("enemy_type", "martarquas_raider_1"))})
		node.position = Vector3(wx, wy, wz)
		_entity_root.add_child(node)
		_enemy_nodes[eid] = node
		_coop_siege_wave_nodes[eid] = node
	GameBus.hud_message_requested.emit(
		"Wave %d of %d: Siege intensifies…" % [_coop_siege_wave + 1, _CoopSiege.WAVE_COUNT])

## Any peer: the host advanced to a new raider wave.
func _on_siege_wave_received(siege_id: int, wave: int) -> void:
	if not _coop_active or siege_id != _coop_siege_id:
		return
	_coop_siege_wave = wave
	_coop_spawn_siege_wave()

## Any peer: every raider wave is cleared — spawn the finale boss.
func _on_siege_boss_phase_received(siege_id: int) -> void:
	if not _coop_active or siege_id != _coop_siege_id:
		return
	_coop_siege_wave = _CoopSiege.WAVE_COUNT
	_coop_siege_wave_nodes.clear()
	GameBus.hud_message_requested.emit("The Siege Commander arrives!")
	var boss_id: String = _CoopSiege.boss_id(siege_id)
	if _coop_removed_enemies.has(boss_id):
		return  # already resolved (e.g. a re-delivered broadcast on late reconciliation)
	const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(map_name, Vector3.ZERO)
	var node: Node3D = _EnemyScene.instantiate() as Node3D
	if node == null:
		return
	var wy: float = get_terrain_height(gate.x, gate.z) + 0.5
	node.position = Vector3(gate.x, wy, gate.z)
	node.call("init_from_data", {"id": boss_id, "enemy_type": _CoopSiege.boss_enemy_type(), "tracking": false})
	_entity_root.add_child(node)
	_enemy_nodes[boss_id] = node

## Host-only: watches the current wave's engage-lock state; called every frame
## from _process while a siege is active.
func _coop_tick_siege(_delta: float) -> void:
	if not _coop_world_authority() or not _coop_siege_active:
		return
	if _coop_siege_wave < 0 or _coop_siege_wave >= _CoopSiege.WAVE_COUNT:
		return  # boss phase already reached, or not started
	if _coop_siege_wave_nodes.is_empty():
		return
	for eid in _coop_siege_wave_nodes.keys():
		if not _coop_removed_enemies.has(eid):
			return  # a raider from this wave is still standing somewhere
	_coop_siege_wave_nodes.clear()
	_coop_siege_wave += 1
	if _coop_siege_wave >= _CoopSiege.WAVE_COUNT:
		_net_sync.rpc("recv_siege_boss_phase", _coop_siege_id)
		_on_siege_boss_phase_received(_coop_siege_id)
	else:
		_net_sync.rpc("recv_siege_wave", _coop_siege_id, _coop_siege_wave)
		_on_siege_wave_received(_coop_siege_id, _coop_siege_wave)

## Local player engaged the siege boss. A client relays the intent to the host;
## the host starts the joint battle directly.
func _coop_engage_siege_boss(edata: Dictionary) -> void:
	if not NetworkManager.is_host():
		if _net_sync != null:
			_net_sync.rpc_id(1, "submit_siege_boss_engaged", edata)
		return
	_coop_start_siege_boss_battle(edata)

## Host: a client engaged the siege boss — start the joint battle for everyone.
func _on_siege_boss_engaged_submitted(_sender: int, edata: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	_coop_start_siege_boss_battle(edata)

## Host-only: gathers every connected member's deck and starts the joint PvE
## battle (GID-099). Boss HP/tier scaling by party size happens inside
## BattleScene._build_coop_pve_state — edata is passed through unscaled, exactly
## like a normal EnemyNPC.engage() payload.
func _coop_start_siege_boss_battle(edata: Dictionary) -> void:
	if not NetworkManager.is_host() or _net_sync == null:
		return
	var boss_eid: String = str(edata.get("id", ""))
	if boss_eid != "":
		# Remove the boss node locally too: if a CLIENT engaged it, the host's own
		# copy is still standing (only the engager's local node freed itself via
		# EnemyNPC.engage()). RPCs in this codebase are declared "call_remote" (never
		# self-invoking), so the broadcast below reaches every *other* peer but not
		# this one — _coop_remove_enemy_node covers the host's own copy and is a
		# harmless no-op if it's already gone (the host-engaged case).
		_coop_remove_enemy_node(boss_eid)
		_net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_REMOVED, boss_eid))
	var abs_peer_ids: Array[int] = [multiplayer.get_unique_id()]
	var clients: Array = multiplayer.get_peers()
	clients.sort()
	for pid in clients:
		abs_peer_ids.append(int(pid))
	var all_decks: Array = []
	for pid in abs_peer_ids:
		all_decks.append(_team_deck_for_peer(pid))
	for i in range(abs_peer_ids.size()):
		var pid: int = abs_peer_ids[i]
		if pid != multiplayer.get_unique_id():
			_net_sync.rpc_id(pid, "notify_coop_pve_start", i, all_decks, edata)
	if _siege_btn != null and is_instance_valid(_siege_btn):
		_siege_btn.hide()
	SceneManager.enter_coop_pve_battle(0, all_decks, edata)

## Client: the host started the joint siege-boss battle — enter with our index.
func _on_notify_coop_pve_start(my_idx: int, all_ally_decks: Array, enemy_data: Dictionary) -> void:
	if _siege_btn != null and is_instance_valid(_siege_btn):
		_siege_btn.hide()
	SceneManager.enter_coop_pve_battle(my_idx, all_ally_decks, enemy_data)

## Any peer: the joint siege-boss battle ended — reset siege UI/state; the host
## additionally distributes victory rewards to the whole party. A no-op unless a
## siege was actually active (coop_pve_battle_ended may fire for future non-siege
## joint battles too, once something else calls enter_coop_pve_battle).
func _on_coop_siege_battle_ended(did_win: bool) -> void:
	if not _coop_siege_active:
		return
	_coop_siege_active = false
	_coop_siege_wave = -1
	_coop_siege_wave_nodes.clear()
	if _siege_banner != null and is_instance_valid(_siege_banner):
		_siege_banner.queue_free()
		_siege_banner = null
	if _siege_btn != null and is_instance_valid(_siege_btn):
		_siege_btn.visible = NetworkManager.is_host()
	if did_win:
		if NetworkManager.is_host():
			_finish_coop_siege_victory()
	else:
		GameBus.hud_message_requested.emit("The siege defense failed…")

## Host-only: split gold + a random rare-or-better card across every session
## member, record the clear to the co-op leaderboard, and push refreshed
## character records so connected peers see their reward immediately.
func _finish_coop_siege_victory() -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	const SIEGE_COINS: int = 150
	var tokens: Array[String] = [MpProfile.get_token()]
	for pid in multiplayer.get_peers():
		var tok: String = str(_session_token_by_peer.get(int(pid), ""))
		if tok != "" and not tokens.has(tok):
			tokens.append(tok)
	var all_ids: Array[String] = _CardRegistry.get_all_ids()
	for token: String in tokens:
		var rec: Dictionary = st.get_member(token)
		if rec.is_empty():
			continue
		rec["coins"] = int(rec.get("coins", 0)) + SIEGE_COINS
		if not all_ids.is_empty():
			var reward_id: String = all_ids[randi() % all_ids.size()]
			var rarity: String = _CardDropUtil.roll_rarity(3)  # tier 3 = rare-or-better weighted
			var stats: Dictionary = _CardDropUtil.roll_stats(reward_id, rarity)
			var owned: Array = rec.get("owned_cards", [])
			var uid: String = "%s_%s_siege_%d" % [reward_id, token, Time.get_ticks_msec()]
			owned.append(_CardInstanceUtil.make(uid, reward_id, rarity,
				int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1))))
			rec["owned_cards"] = owned
		st.update_member(token, rec)
	# Note: the co-op boss-clear leaderboard entry itself is recorded generically by
	# _on_coop_pve_battle_ended_leaderboard (permanently connected to the same
	# GameBus.coop_pve_battle_ended signal for every joint PvE battle) — recording it
	# again here would double-submit to the "coop_clears" board.
	SessionStore.mark_dirty()
	# Push refreshed character records so connected peers see their new coins/card
	# without waiting for their next unrelated sync (mirrors _send_character_to_peer).
	for pid in multiplayer.get_peers():
		var tok: String = str(_session_token_by_peer.get(int(pid), ""))
		if tok == "":
			continue
		var rec2: Dictionary = st.get_member(tok)
		if not rec2.is_empty() and _net_sync != null:
			_net_sync.rpc_id(int(pid), "recv_character", rec2, true)
	var host_rec: Dictionary = st.get_member(MpProfile.get_token())
	if not host_rec.is_empty():
		SceneManager.save_manager.adopt_session_character(host_rec)
	GameBus.hud_message_requested.emit("Party earned %d gold and defeated the Siege!" % SIEGE_COINS)

# ── PvP challenge handshake (GID-091) ─────────────────────────────────────────

## Creates the hidden "Challenge to Battle" contextual-bar action (GID-107 / TID-396:
## registered into WorldHUD.ZONE_CONTEXT so it can never pixel-overlap the Android
## USE/Interact button or the other proximity-gated social actions, which share the
## same zone). Mobile + desktop parity.
func _ensure_challenge_button() -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_challenge_btn = _world_hud.register_action("challenge", "Challenge to Battle",
		WorldHUD.ZONE_CONTEXT, _request_challenge, Callable(), Vector2(vp.y * 0.34, vp.y * 0.07))
	_challenge_btn.hide()
	# Ranked opt-in toggle (GID-102 / TID-373): stacks below the challenge button in
	# the shared contextual zone — a touch/click target like every other HUD toggle
	# (no separate keybind needed). Built directly (not via register_action) since it
	# needs a `.toggled` connection, not a simple `.pressed` callback.
	_ranked_toggle_btn = Button.new()
	_ranked_toggle_btn.toggle_mode = true
	_ranked_toggle_btn.text = "Ranked: OFF"
	_ranked_toggle_btn.tooltip_text = "When ON, this duel counts toward your ranked rating."
	_ranked_toggle_btn.custom_minimum_size = Vector2(vp.y * 0.20, vp.y * 0.05)
	_ranked_toggle_btn.add_theme_font_size_override("font_size", int(vp.y * 0.020))
	_ranked_toggle_btn.hide()
	_ranked_toggle_btn.toggled.connect(func(on: bool) -> void:
		_ranked_toggle_on = on
		_ranked_toggle_btn.text = "Ranked: ON" if on else "Ranked: OFF")
	var context_zone: Container = _world_hud.get_zone_container(WorldHUD.ZONE_CONTEXT)
	if context_zone != null:
		context_zone.add_child(_ranked_toggle_btn)
	else:
		_hud.add_child(_ranked_toggle_btn)

## Shows/hides the challenge button based on proximity to a remote player. Called
## each frame from _process while co-op is active. GID-107 / TID-396 priority rule:
## the world-interact prompt (door/chest/NPC/scroll) always wins the shared
## contextual slot over a social action — interacting with the world is the more
## frequent, lower-friction action.
func _update_challenge_proximity() -> void:
	if _challenge_btn == null or not is_instance_valid(_challenge_btn):
		return
	if _world_hud != null and _world_hud.is_interact_visible():
		_challenge_btn.hide()
		if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
			_ranked_toggle_btn.hide()
		return
	# Suppress while a challenge is pending or we're not in the world.
	if _pending_challenge_from != -1 or SceneManager._state != SceneManager.State.WORLD:
		_challenge_btn.hide()
		if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
			_ranked_toggle_btn.hide()
		return
	if _player == null:
		_challenge_btn.hide()
		if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
			_ranked_toggle_btn.hide()
		return
	var range_world: float = _CHALLENGE_RANGE * IsoConst.TILE_SIZE
	var nearest_pid: int = -1
	var nearest_d: float = range_world
	for pid in _remote_player_nodes.keys():
		var rp: Node3D = _valid_node3d(_remote_player_nodes[pid])
		if not is_instance_valid(rp):
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(
			Vector2(_player.position.x, _player.position.z))
		if d <= nearest_d:
			nearest_d = d
			nearest_pid = int(pid)
	_challenge_target_peer = nearest_pid
	_challenge_btn.visible = nearest_pid != -1
	if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
		_ranked_toggle_btn.visible = nearest_pid != -1

## Local deck as a plain Array of Dictionaries for RPC transmission.
func _local_deck_for_net() -> Array:
	var out: Array = []
	for inst in SceneManager.save_manager.get_deck_instances():
		out.append(inst)
	return out

## Send a challenge to the nearby peer.
func _request_challenge() -> void:
	if _challenge_target_peer == -1 or _net_sync == null:
		return
	var my_deck: Array = _local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_show_tip("Your deck is too small to duel — add at least %d cards." % IsoConst.DECK_MIN)
		return
	if _session_dedicated:
		# Dedicated server: route through the server referee (peer_id 1). Ranked toggle
		# is not threaded through the dedicated-server relay path in this task — out of
		# scope (see TID-373 task file); always casual on a dedicated server for now.
		_net_sync.rpc_id(1, "relay_pvp_request", _challenge_target_peer, my_deck)
	else:
		_net_sync.rpc_id(_challenge_target_peer, "request_battle", my_deck, _ranked_toggle_on)
	_show_tip("Ranked challenge sent…" if _ranked_toggle_on else "Challenge sent…")

# ── Team PvP duels (GID-102 / TID-371) ────────────────────────────────────────
# GID-107 (TID-395): Team Duel is now a Party-panel action (see _open_party_panel's
# show_team_duel, computed fresh on open) instead of its own standalone HUD button.

## Host-only: resolves a connected peer's current deck as instances for the team duel.
## The host's own deck comes straight from SaveManager; a client's deck is read from
## its already-synced GID-095 session character record — no extra RPC round-trip needed.
func _team_deck_for_peer(pid: int) -> Array:
	if pid == multiplayer.get_unique_id():
		return _local_deck_for_net()
	var token: String = str(_session_token_by_peer.get(pid, ""))
	if token == "" or not SessionStore.is_open():
		return []
	var st = SessionStore.get_state()
	if st == null:
		return []
	var rec: Dictionary = st.get_member(token)
	if rec.is_empty():
		return []
	var by_uid: Dictionary = {}
	for inst in rec.get("owned_cards", []):
		if inst is Dictionary:
			by_uid[str(inst.get("uid", ""))] = inst
	var out: Array = []
	for uid in rec.get("player_deck", []):
		if by_uid.has(str(uid)):
			out.append(by_uid[str(uid)])
	return out

## Host: assigns teams from the connected 4-peer session and starts a 2v2 duel for
## everyone immediately — no individual accept/decline (keeps team-formation UI
## minimal, per the task notes). Host + the first-sorted client form team 0; the other
## two clients form team 1. Absolute GameState indices: [host, client_b, host's
## partner, client_c] so the interleaved [teamA_0,teamB_0,teamA_1,teamB_1] layout in
## GameState.setup_team_battle puts the host's chosen partner on the host's team.
func _start_team_duel() -> void:
	if not NetworkManager.is_host() or _net_sync == null:
		return
	var clients: Array = multiplayer.get_peers()
	if clients.size() < 3:
		_show_tip("Need 4 players for a team duel.")
		return
	clients.sort()
	var host_id: int = multiplayer.get_unique_id()
	var abs_peer_ids: Array[int] = [host_id, int(clients[1]), int(clients[0]), int(clients[2])]
	var team_assignments: Array = [0, 1, 0, 1]
	var all_decks: Array = []
	for pid in abs_peer_ids:
		all_decks.append(_team_deck_for_peer(pid))
	for i in range(abs_peer_ids.size()):
		var pid: int = abs_peer_ids[i]
		if pid != host_id:
			_net_sync.rpc_id(pid, "notify_team_duel_start", i, team_assignments, all_decks)
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	_active_team_duel_peer_ids = abs_peer_ids
	_active_team_duel_teams = team_assignments
	SceneManager.enter_team_battle(0, team_assignments, all_decks)

## Client: the host started a team duel — enter it with the assigned absolute index.
func _on_notify_team_duel_start(my_idx: int, team_assignments: Array, all_decks: Array) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	SceneManager.enter_team_battle(my_idx, team_assignments, all_decks)

## Incoming challenge — show an Accept/Decline prompt.
func _on_battle_requested(from_id: int, challenger_deck: Array, ranked: bool = false) -> void:
	if _pending_challenge_from != -1:
		return  # already handling one
	_pending_challenge_from = from_id
	_pending_challenge_deck = challenger_deck
	_pending_challenge_ranked = ranked
	_show_challenge_accept_panel(from_id, ranked)

## Challenger learns the response.
func _on_battle_responded(_from_id: int, accepted: bool, responder_deck: Array, ranked: bool = false) -> void:
	if not accepted:
		_show_tip("Challenge declined.")
		return
	_enter_pvp(responder_deck, ranked)

# ── Dedicated-server PvP routing (GID-097 / TID-353) ──────────────────────────

## Client handler: server told us we're in a dedicated-server session.
func _on_session_flags(flags: Dictionary) -> void:
	_session_dedicated = bool(flags.get("dedicated", false))

## Server handler: client A wants to challenge client B.
## Stores the pending challenge and relays the request to B as a normal request_battle.
func _on_relay_pvp_request(sender_id: int, target_peer_id: int, challenger_deck: Array) -> void:
	if not NetworkManager.is_dedicated_server():
		return
	if _pvp_relay_challenger_id != -1:
		return  # a challenge is already pending
	_pvp_relay_challenger_id = sender_id
	_pvp_relay_challenger_deck = challenger_deck
	_pvp_relay_target_id = target_peer_id
	if _net_sync != null:
		_net_sync.rpc_id(target_peer_id, "request_battle", challenger_deck)

## Server handler: the challenged peer accepted or declined.
## On accept: launch a headless referee BattleScene and notify both clients.
func _on_relay_pvp_response(sender_id: int, challenger_id: int, accepted: bool, responder_deck: Array) -> void:
	if not NetworkManager.is_dedicated_server():
		return
	if _pvp_relay_challenger_id != challenger_id or _pvp_relay_target_id != sender_id:
		return  # stale or mismatched response
	var challenger: int = _pvp_relay_challenger_id
	var target: int = _pvp_relay_target_id
	var deck_a: Array = _pvp_relay_challenger_deck.duplicate()
	_pvp_relay_challenger_id = -1
	_pvp_relay_challenger_deck = []
	_pvp_relay_target_id = -1
	if not accepted:
		if _net_sync != null:
			_net_sync.rpc_id(challenger, "respond_battle", false, [])
		return
	# Notify both clients: each will call enter_pvp_battle with their role.
	if _net_sync != null:
		_net_sync.rpc_id(challenger, "notify_pvp_start", 0, responder_deck)
		_net_sync.rpc_id(target, "notify_pvp_start", 1, deck_a)
	# Launch the headless referee on the server itself. Tokens (GID-102 / TID-372) let
	# the referee verify a later reconnect from either combatant.
	var token_a: String = str(_session_token_by_peer.get(challenger, ""))
	var token_b: String = str(_session_token_by_peer.get(target, ""))
	SceneManager.enter_pvp_referee(deck_a, responder_deck, challenger, target, token_a, token_b)

## Client handler: server assigned us a player index; start the PvP battle.
func _on_notify_pvp_start(my_player_idx: int, opponent_deck: Array) -> void:
	if NetworkManager.is_dedicated_server():
		return
	SceneManager.enter_pvp_battle(my_player_idx, opponent_deck)

func _show_challenge_accept_panel(from_id: int, ranked: bool = false) -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 180
	add_child(layer)
	_challenge_accept_panel = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vp.y * 0.025))
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "A player challenges you to a RANKED card battle!" if ranked \
		else "A player challenges you to a card battle!"
	lbl.add_theme_font_size_override("font_size", int(vp.y * 0.03))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ranked:
		lbl.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vp.y * 0.03))
	vbox.add_child(row)

	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(vp.y * 0.2, vp.y * 0.07)
	accept_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	accept_btn.pressed.connect(_accept_challenge.bind(from_id))
	row.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vp.y * 0.2, vp.y * 0.07)
	decline_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	decline_btn.pressed.connect(_decline_challenge.bind(from_id))
	row.add_child(decline_btn)

func _dismiss_challenge_panel() -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	_challenge_accept_panel = null

func _accept_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	var my_deck: Array = _local_deck_for_net()
	var ranked: bool = _pending_challenge_ranked
	if my_deck.size() < IsoConst.DECK_MIN:
		_show_tip("Your deck is too small to duel.")
		if _net_sync != null:
			if _session_dedicated:
				_net_sync.rpc_id(1, "relay_pvp_response", from_id, false, [])
			else:
				_net_sync.rpc_id(from_id, "respond_battle", false, [])
		_pending_challenge_from = -1
		_pending_challenge_ranked = false
		return
	var opp_deck: Array = _pending_challenge_deck
	_pending_challenge_from = -1
	_pending_challenge_deck = []
	_pending_challenge_ranked = false
	if _net_sync != null:
		if _session_dedicated:
			# Server will send notify_pvp_start to both peers — don't call _enter_pvp here.
			_net_sync.rpc_id(1, "relay_pvp_response", from_id, true, my_deck)
			return
		_net_sync.rpc_id(from_id, "respond_battle", true, my_deck, ranked)
	# Record the opponent peer so the host's spectator + rating (TID-370) paths know
	# who it dueled when accepting an incoming challenge (not just when challenging).
	_challenge_target_peer = from_id
	_enter_pvp(opp_deck, ranked)

func _decline_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	_pending_challenge_ranked = false
	if _net_sync != null:
		if _session_dedicated:
			_net_sync.rpc_id(1, "relay_pvp_response", from_id, false, [])
		else:
			_net_sync.rpc_id(from_id, "respond_battle", false, [])
	_pending_challenge_from = -1
	_pending_challenge_deck = []

## Both peers route into SceneManager. The co-op host is always the battle
## authority (canonical player 0); the client is player 1.
## ranked (GID-102 / TID-373): agreed by both peers via the request_battle/respond_battle
## handshake before either calls this, so both pass the same value into enter_pvp_battle.
func _enter_pvp(opponent_deck: Array, ranked: bool = false) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
		_ranked_toggle_btn.hide()
	_pvp_ranked = ranked
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	# GID-101 (TID-367): host broadcasts duel-start to spectators
	if NetworkManager.is_host() and _net_sync != null:
		var my_id: int = multiplayer.get_unique_id()
		_pvp_ante_peer0 = my_id
		_pvp_ante_peer1 = _challenge_target_peer
		for pid in multiplayer.get_peers():
			var p: int = int(pid)
			if p != _challenge_target_peer:
				_net_sync.rpc_id(p, "recv_pvp_active", true, my_id, _challenge_target_peer)
	# GID-102 (TID-372): opponent's identity token, so the host can verify a later
	# reconnect. Only meaningful on the host's own call (_session_token_by_peer is
	# host-side only); harmless empty string on the client's own call.
	var opp_token: String = str(_session_token_by_peer.get(_challenge_target_peer, ""))
	SceneManager.enter_pvp_battle(local_idx, opponent_deck, 0, opp_token, ranked)

## Returns the biome and time context at the moment of engagement (GID-059).
## Called by SceneManager._on_enemy_engaged() to stamp context into enemy_data.
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

func _refresh_xp_bar() -> void:
	_world_hud.refresh_xp_bar()

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

func _get_height_global(wtx: int, wtz: int) -> int:
	return _csm.get_height_global(wtx, wtz)

# Compute terrain height at a world position using the shared smoothstep algorithm.
func get_terrain_height(wx: float, wz: float) -> float:
	if _is_infinite:
		return TerrainMath.get_height_at(wx, wz, get_tile_global, _get_height_global,
				IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
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

func _find_nearby_scroll(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for s in _scroll_nodes:
		if not is_instance_valid(s):
			continue
		var ddx: float = s.position.x - px
		var ddz: float = s.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return s
	return null

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
	if not is_instance_valid(_wilderness_camp_node):
		return null
	var ddx: float = _wilderness_camp_node.position.x - px
	var ddz: float = _wilderness_camp_node.position.z - pz
	if ddx * ddx + ddz * ddz <= range_dist * range_dist:
		return _wilderness_camp_node
	return null

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
	if not is_instance_valid(_scout_ambush_node):
		return null
	var ddx: float = _scout_ambush_node.position.x - px
	var ddz: float = _scout_ambush_node.position.z - pz
	if ddx * ddx + ddz * ddz <= range_dist * range_dist:
		return _scout_ambush_node
	return null

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
		_maiteln_node = node

func _find_nearby_maiteln(px: float, pz: float, range_dist: float) -> Node3D:
	if not is_instance_valid(_maiteln_node):
		return null
	var ddx: float = _maiteln_node.position.x - px
	var ddz: float = _maiteln_node.position.z - pz
	if ddx * ddx + ddz * ddz <= range_dist * range_dist:
		return _maiteln_node
	return null

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
	var range_sq: float = range_dist * range_dist
	for sh in _shrine_nodes:
		if not is_instance_valid(sh):
			continue
		var ddx: float = sh.position.x - px
		var ddz: float = sh.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return sh
	return null

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

func _spawn_named_map_mailboxes() -> void:
	if world_map == null:
		return
	if not _NAMED_MAP_MAILBOX_LOCATIONS.has(map_name):
		return
	if map_name == "player_home" and not SceneManager.save_manager.home_owned:
		return
	var tx: int = world_map.player_spawn_x + 5 if world_map.has_player_spawn() else 10
	var tz: int = world_map.player_spawn_z if world_map.has_player_spawn() else 8
	tx = clamp(tx, 1, WorldMap.MAP_WIDTH - 2)
	tz = clamp(tz, 1, WorldMap.MAP_HEIGHT - 2)
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
	var range_sq: float = range_dist * range_dist
	for mid in _active_mailbox_data:
		var m: Dictionary = _active_mailbox_data[mid]
		var ddx: float = float(m.get("x", 0.0)) - px
		var ddz: float = float(m.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return m
	return {}

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
	_siege_banner = Label.new()
	_siege_banner.text = "%s Under Attack!" % p_map_name.capitalize().replace("_", " ")
	_siege_banner.add_theme_font_size_override("font_size", int(vh * 0.03))
	_siege_banner.modulate = Color(1.0, 0.3, 0.1)
	_siege_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_siege_banner.position = Vector2((vw - vh * 0.6) * 0.5, vh * 0.005)
	_siege_banner.custom_minimum_size = Vector2(vh * 0.6, int(vh * 0.04))
	_hud.add_child(_siege_banner)

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
	var range_sq: float = range_dist * range_dist
	for wid: String in _mana_well_nodes:
		var wnode: Node3D = _valid_node3d(_mana_well_nodes[wid])
		if not is_instance_valid(wnode):
			continue
		var ddx: float = wnode.position.x - px
		var ddz: float = wnode.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return wnode
	return null

func _find_nearby_blight_heart(px: float, pz: float, range_dist: float) -> Node3D:
	var range_sq: float = range_dist * range_dist
	for hid: String in _blight_heart_nodes:
		var hnode: Node3D = _valid_node3d(_blight_heart_nodes[hid])
		if not is_instance_valid(hnode):
			continue
		var ddx: float = hnode.position.x - px
		var ddz: float = hnode.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return hnode
	return null

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
	var range_sq: float = range_dist * range_dist
	for mid in _burial_mound_nodes:
		var mnode: Node3D = _valid_node3d(_burial_mound_nodes[mid])
		if not is_instance_valid(mnode) or not mnode.visible:
			continue
		var ddx: float = mnode.position.x - px
		var ddz: float = mnode.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return mnode
	return null

func _find_nearby_waystone(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for wid in _active_waystone_data:
		var w: Dictionary = _active_waystone_data[wid]
		var ddx: float = float(w.get("x", 0.0)) - px
		var ddz: float = float(w.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return w
	return {}

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

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)
	_fast_travel_layer = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.55
	var panel_h: float = vh * 0.62
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.10, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.018))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Fast Travel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.035))
	title.add_theme_color_override("font_color", Color(0.40, 0.90, 1.00))
	vbox.add_child(title)

	var is_blocked: bool = SceneManager.current_map.begins_with("dungeon_")
	var activated: Array[String] = SceneManager.save_manager.activated_waystones
	if activated.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No waystones activated yet.\nFind and interact with a waystone pillar to unlock fast travel."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty_lbl)
	elif is_blocked:
		var block_lbl := Label.new()
		block_lbl.text = "Fast travel is unavailable inside dungeons."
		block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
		block_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		block_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(block_lbl)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, panel_h * 0.62)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var btn_vbox := VBoxContainer.new()
		btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_vbox.add_theme_constant_override("separation", int(vh * 0.010))
		scroll.add_child(btn_vbox)

		var btn_h: float = vh * 0.060
		for wid: String in activated:
			var btn := Button.new()
			btn.text = _waystone_friendly_label(wid)
			btn.custom_minimum_size = Vector2(0, btn_h)
			btn.add_theme_font_size_override("font_size", int(vh * 0.024))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_id: String = wid
			btn.pressed.connect(func() -> void:
				_fast_travel_layer = null
				layer.queue_free()
				SceneManager.teleport_to_waystone(captured_id)
			)
			btn_vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]" if not OS.has_feature("android") else "Close"
	close_btn.custom_minimum_size = Vector2(vh * 0.20, vh * 0.06)
	close_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
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
	if _digspot_node == null or not is_instance_valid(_digspot_node):
		_digspot_node = null
		return null
	var ddx: float = _digspot_node.position.x - px
	var ddz: float = _digspot_node.position.z - pz
	if ddx * ddx + ddz * ddz <= range_dist * range_dist:
		return _digspot_node
	return null

func _break_cracked_wall(tx: int, tz: int) -> void:
	world_map.set_tile(tx, tz, IsoConst.TILE_GRASS)
	AudioManager.play_sfx("chest_open")
	SceneManager.show_toast("Secret passage!", "A hidden room is revealed.")
	_rebuild_terrain_around_tile(tx, tz)
	world_map.save_to_file(SceneManager.save_manager.current_map)

func _rebuild_terrain_around_tile(tx: int, tz: int) -> void:
	_csm.rebuild_terrain_around_tile(tx, tz)

func _find_nearby_npc(px: float, pz: float, range_dist: float) -> Dictionary:
	var range_sq: float = range_dist * range_dist
	for nid in _active_npc_data:
		var n: Dictionary = _active_npc_data[nid]
		var ddx: float = float(n.get("x", 0.0)) - px
		var ddz: float = float(n.get("z", 0.0)) - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return n
	return {}

func _make_terrain_material(_seed: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _TerrainShader
	mat.set_shader_parameter("grass_texture",     _TexGrass)
	mat.set_shader_parameter("hill_side_texture", _TexHillSide)
	mat.set_shader_parameter("hill_texture",      _TexHillTop)
	mat.set_shader_parameter("wall_side_texture", _TexWallSide)
	mat.set_shader_parameter("wall_top_texture",  _TexWallTop)
	mat.set_shader_parameter("path_texture",      TextureGen.path())
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
		_broadcast_local_avatar(delta)
		_update_challenge_proximity()
		_update_draft_duel_proximity()
		_update_tournament_button_visibility()
		_tick_tournament(delta)
		_tick_session_persist(delta)
		# World-object sync (GID-096): host streams enemy positions; clients smooth.
		_broadcast_enemy_positions(delta)
		_interp_synced_enemies(delta)
		# GID-101: social features tick
		_tick_emote_self(delta)
		_tick_ping_markers(delta)
		_update_social_proximity()
		# Party loot rolls (GID-102 / TID-381): authority-only timeout ticker; inert
		# unless a roll is actually in flight (need/greed mode opted in).
		_tick_loot_rolls(delta)
		# Downed & rescue (GID-105 / TID-389): live countdown on the local banner.
		if _coop_downed and _downed_banner != null and is_instance_valid(_downed_banner):
			var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _downed_started_at
			var remaining: float = _DownedSync.remaining_time(elapsed)
			_downed_banner.text = "Downed — waiting for rescue… (%ds)" % int(ceil(remaining))
		# Shared world life (GID-103): synced clock/weather, party night hunts, and
		# the co-op siege wave watcher. Map-scoped and host/authority gated
		# internally; single-player never reaches these.
		_tick_env_sync(delta)
		_coop_update_night_hunts(delta)
		_coop_tick_siege(delta)
	if _dnc:
		_dnc.tick(delta, _weather_tint)

	if _player == null:
		return
	# Software floor: snap player back to terrain surface if physics misses it.
	var rx: float = _player.position.x
	var rz: float = _player.position.z
	var floor_y: float = get_terrain_height(rx, rz)
	if _player.position.y < floor_y:
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

func _check_interactions() -> void:
	var px: float = _player.position.x
	var pz: float = _player.position.z
	# Downed & rescue (GID-105 / TID-389): a downed player is frozen and cannot
	# interact with anything (chests/NPCs/doors/enemies are all unreachable anyway
	# since they can't move, but this is a defensive guard for whatever happened
	# to be in range at the moment of defeat).
	if _coop_downed:
		_world_hud.show_interact_prompt(false, "USE")
		return
	var downed_pid: int = _find_nearby_downed_peer(px, pz, IsoConst.INTERACT_RANGE)
	var enemy := _find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
	var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	var door := _find_nearby_door(px, pz, IsoConst.INTERACT_RANGE * 2.0)
	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	var scroll := _find_nearby_scroll(px, pz, IsoConst.INTERACT_RANGE)
	var wilderness_camp := _find_nearby_wilderness_camp(px, pz, IsoConst.INTERACT_RANGE)
	var scout_ambush := _find_nearby_scout_ambush(px, pz, IsoConst.INTERACT_RANGE)
	var maiteln := _find_nearby_maiteln(px, pz, IsoConst.INTERACT_RANGE)
	var shrine := _find_nearby_shrine(px, pz, IsoConst.INTERACT_RANGE)
	var digspot := _find_nearby_digspot(px, pz, IsoConst.INTERACT_RANGE)
	var waystone := _find_nearby_waystone(px, pz, IsoConst.INTERACT_RANGE)
	var mailbox := _find_nearby_mailbox(px, pz, IsoConst.INTERACT_RANGE)
	var garden_plot := _find_nearby_garden_plot(px, pz, IsoConst.INTERACT_RANGE)
	var burial_mound := _find_nearby_burial_mound(px, pz, IsoConst.INTERACT_RANGE)
	var blight_heart := _find_nearby_blight_heart(px, pz, IsoConst.INTERACT_RANGE)
	# Landmarks auto-trigger on approach (no button press needed)
	_check_nearby_landmark(px, pz)
	var mana_well := _find_nearby_mana_well(px, pz, IsoConst.INTERACT_RANGE)
	var has_entity: bool = downed_pid != -1 or enemy != null or not chest.is_empty() or not door.is_empty() or not npc.is_empty() or scroll != null or wilderness_camp != null or scout_ambush != null or maiteln != null or shrine != null or digspot != null or not waystone.is_empty() or not mailbox.is_empty() or garden_plot != null or burial_mound != null or blight_heart != null or mana_well != null
	var interact_label: String = "USE"
	if downed_pid != -1:
		interact_label = "REVIVE"
	elif enemy != null:
		interact_label = "ATTACK"
	elif not chest.is_empty():
		interact_label = "OPEN"
	elif not door.is_empty():
		interact_label = "ENTER"
	elif wilderness_camp != null:
		interact_label = "CAMP"
	elif scout_ambush != null:
		interact_label = "ATTACK"
	elif maiteln != null:
		interact_label = "TALK"
	elif not npc.is_empty():
		match str(npc.get("npc_type", "")):
			"merchant", "traveling_merchant": interact_label = "SHOP"
			"blacksmith": interact_label = "FORGE"
			"bounty_board": interact_label = "BOARD"
			"stable": interact_label = "STABLE"
			"duelist": interact_label = "DUEL"
			"rest_site", "bed": interact_label = "REST"
			_: interact_label = "TALK"
	elif scroll != null:
		interact_label = "READ"
	elif shrine != null:
		interact_label = "PRAY"
	elif digspot != null:
		interact_label = "DIG"
	elif not waystone.is_empty():
		interact_label = "WARP"
	elif not mailbox.is_empty():
		interact_label = "MAIL"
	elif garden_plot != null:
		interact_label = "TEND"
	elif burial_mound != null:
		interact_label = "DIG"
	elif blight_heart != null:
		interact_label = "CLEANSE"
	elif mana_well != null:
		interact_label = "FILL"
	_world_hud.show_interact_prompt(has_entity and not SceneManager.has_open_overlay(), interact_label)

	var is_android: bool = OS.has_feature("android")
	if not npc.is_empty() and not SceneManager.save_manager.get_story_flag("tutorial_npc_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_npc_tip")
		_show_tip("Tap to talk" if is_android else "Press E to talk to NPCs")
	elif not chest.is_empty() and not SceneManager.save_manager.get_story_flag("tutorial_chest_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_chest_tip")
		_show_tip("Tap to open chests" if is_android else "Press E to open chests")
	elif enemy != null and not SceneManager.save_manager.get_story_flag("tutorial_enemy_tip"):
		SceneManager.save_manager.set_story_flag("tutorial_enemy_tip")
		var interact_key: String = "Tap" if OS.has_feature("android") else "Press E"
		_show_tip("Some enemies attack on sight — others wait. %s to challenge any enemy." % interact_key)

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
		_build_rally_targets())
	_map_overlay.closed.connect(func() -> void: _map_overlay = null)
	_map_overlay.rally_requested.connect(_rally_to_peer)

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

func _handle_interact() -> void:
	if _player == null:
		return
	# Downed & rescue (GID-105 / TID-389): frozen — cannot interact with anything.
	if _coop_downed:
		return
	var px: float = _player.position.x
	var pz: float = _player.position.z

	var downed_pid: int = _find_nearby_downed_peer(px, pz, IsoConst.INTERACT_RANGE)
	if downed_pid != -1:
		_request_revive(downed_pid)
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

	var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
	if not chest.is_empty() and not chest.get("opened", false):
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
		_on_chest_opened_coop(cid)
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
		if _coop_active and _coop_loot_mode_is_need_greed():
			_start_loot_roll(cid, chest_tier)
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

	if not _is_infinite and world_map != null:
		var cracked := world_map.find_nearby_cracked_wall(px, pz, IsoConst.INTERACT_RANGE)
		if cracked != Vector2i(-1, -1):
			_break_cracked_wall(cracked.x, cracked.y)
			return

	var npc := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
	if not npc.is_empty():
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

	var scroll := _find_nearby_scroll(px, pz, IsoConst.INTERACT_RANGE)
	if scroll != null and scroll.has_method("interact"):
		scroll.interact()
		return

	var wilderness_camp := _find_nearby_wilderness_camp(px, pz, IsoConst.INTERACT_RANGE)
	if wilderness_camp != null and wilderness_camp.has_method("interact"):
		wilderness_camp.interact()
		return

	var scout_ambush := _find_nearby_scout_ambush(px, pz, IsoConst.INTERACT_RANGE)
	if scout_ambush != null and scout_ambush.has_method("interact"):
		scout_ambush.interact()
		return

	var maiteln := _find_nearby_maiteln(px, pz, IsoConst.INTERACT_RANGE)
	if maiteln != null and maiteln.has_method("interact"):
		maiteln.interact()
		return

	var shrine := _find_nearby_shrine(px, pz, IsoConst.INTERACT_RANGE)
	if shrine != null and shrine.has_method("interact"):
		shrine.interact()
		return

	var digspot := _find_nearby_digspot(px, pz, IsoConst.INTERACT_RANGE)
	if digspot != null and digspot.has_method("dig"):
		digspot.dig()
		return

	var burial_mound_node := _find_nearby_burial_mound(px, pz, IsoConst.INTERACT_RANGE)
	if burial_mound_node != null and burial_mound_node.has_method("interact"):
		burial_mound_node.interact()
		return

	var blight_heart_node := _find_nearby_blight_heart(px, pz, IsoConst.INTERACT_RANGE)
	if blight_heart_node != null and blight_heart_node.has_method("engage"):
		blight_heart_node.engage()
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

func _show_spire_entrance_panel() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var is_active: bool = SceneManager.save_manager.is_spire_active()
	var curr_floor: int = 1
	if is_active:
		curr_floor = int(SceneManager.save_manager.get_spire_run().get("floor", 1))

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.64
	var panel_h: float = vh * 0.40
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(vh * 0.022))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "The Endless Spire"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.038))
	title.modulate = Color(0.85, 0.50, 1.0)
	vbox.add_child(title)

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

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.03))
	vbox.add_child(row)

	var enter_btn := Button.new()
	enter_btn.text = "Resume (Floor %d)" % curr_floor if is_active else "Enter"
	enter_btn.custom_minimum_size = Vector2(vh * 0.20, vh * 0.07)
	enter_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	enter_btn.modulate = Color(0.85, 0.50, 1.0)
	enter_btn.pressed.connect(func() -> void:
		layer.queue_free()
		SceneManager.enter_spire()
	)
	row.add_child(enter_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.07)
	leave_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	leave_btn.pressed.connect(func() -> void: layer.queue_free())
	row.add_child(leave_btn)

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

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.60
	var panel_h: float = vh * 0.32
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.02))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.02))
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.015))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "House For Sale"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.035))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Purchase this cozy home for %d coins.\nCurrent balance: %d coins." % [_HOUSE_PRICE, sm.coins]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", int(vh * 0.027))
	vbox.add_child(desc)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", int(vh * 0.02))
	vbox.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d coins)" % _HOUSE_PRICE
	buy_btn.custom_minimum_size = Vector2(vh * 0.26, vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	buy_btn.disabled = sm.coins < _HOUSE_PRICE
	hbox.add_child(buy_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.065)
	cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	hbox.add_child(cancel_btn)

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

func _on_battle_won(_result: Dictionary) -> void:
	# Co-op (GID-096): a victory over a shared enemy persists its defeat into the
	# session file (stays gone after reconnect). A loss isn't persisted, so the
	# enemy returns on reconnect — matching single-player. Inert single-player.
	_coop_persist_enemy_defeat()
	if _is_infinite and _current_biome >= 0:
		AudioManager.play_music(_BIOME_MUSIC[_current_biome])
		AudioManager.set_ambience(_current_biome)
		const BountyGen_cls = preload("res://game_logic/BountyGen.gd")
		if _current_biome < BountyGen_cls.BIOME_NAMES.size():
			var biome_name: String = BountyGen_cls.BIOME_NAMES[_current_biome]
			SceneManager.save_manager.increment_bounty_progress("defeat_in_biome", {"biome_name": biome_name})
	else:
		AudioManager.play_music("res://assets/audio/music/dungeon.ogg")
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

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.60
	var panel_h: float = vh * 0.36
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.14, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.02))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.02))
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.015))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Madrian Stables"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.035))
	vbox.add_child(title)

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

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", int(vh * 0.02))
	vbox.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d coins)" % MOUNT_PRICE
	buy_btn.custom_minimum_size = Vector2(vh * 0.28, vh * 0.065)
	buy_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	buy_btn.disabled = not level_ok or not coins_ok
	hbox.add_child(buy_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.065)
	cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.027))
	hbox.add_child(cancel_btn)

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

	var lbl := Label3D.new()
	lbl.text = display_name if earned else "???"
	lbl.font_size = 28
	lbl.pixel_size = 0.022
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 1.4, 0.0)
	lbl.modulate = Color(1.0, 0.9, 0.3) if earned else Color(0.5, 0.5, 0.5)
	root.add_child(lbl)

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
	var range_sq: float = range_dist * range_dist
	for plot in _garden_plot_nodes:
		if not is_instance_valid(plot):
			continue
		var ddx: float = plot.position.x - px
		var ddz: float = plot.position.z - pz
		if ddx * ddx + ddz * ddz <= range_sq:
			return plot
	return null

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

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.012))
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Garden Plot %d" % (int(plot.plot_idx) + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.045))
	vbox.add_child(title)

	var plot_data: Dictionary = plot.get_plot_data()
	var stage: int = plot.get_growth_stage() if not plot_data.is_empty() else 0

	if plot_data.is_empty():
		# Empty plot — seed picker
		var info := Label.new()
		info.text = "Choose a seed to plant:"
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(info)

		var has_any_seed: bool = false
		for seed_id in GardenDefs.SEEDS:
			var seed_count: int = int(sm.seeds.get(seed_id, 0))
			var sdata: Dictionary = GardenDefs.SEEDS[seed_id]
			var sname: String = str(sdata.get("display_name", seed_id))
			var days: int = int(sdata.get("growth_days", 2))
			var row := HBoxContainer.new()
			vbox.add_child(row)
			var lbl := Label.new()
			lbl.text = "%s — %d days  (owned: %d)" % [sname, days, seed_count]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", font_size)
			row.add_child(lbl)
			var plant_btn := Button.new()
			plant_btn.text = "Plant"
			plant_btn.custom_minimum_size = Vector2(vh * 0.14, btn_h)
			plant_btn.add_theme_font_size_override("font_size", font_size)
			plant_btn.disabled = seed_count <= 0
			var captured_seed_id: String = seed_id
			var captured_sname: String = sname
			plant_btn.pressed.connect(func() -> void:
				if sm.remove_seeds(captured_seed_id, 1):
					sm.set_plot(plot.plot_idx, captured_seed_id, sm.days_elapsed)
					plot.refresh_visual()
					SceneManager.show_toast("Planted!", captured_sname + " planted.")
					panel.queue_free()
			)
			row.add_child(plant_btn)
			if seed_count > 0:
				has_any_seed = true

		if not has_any_seed:
			var hint := Label.new()
			hint.text = "No seeds — buy some from a merchant."
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.add_theme_font_size_override("font_size", font_size)
			vbox.add_child(hint)

	elif stage < 3:
		# Growing — show info
		var seed_id: String = str(plot_data.get("seed_id", ""))
		var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
		var sname: String = str(sdata.get("display_name", seed_id))
		var growth_days: int = int(sdata.get("growth_days", 2))
		var planted_day: int = int(plot_data.get("planted_day", 0))
		var days_left: int = max(0, planted_day + growth_days - sm.days_elapsed)
		var info := Label.new()
		info.text = "%s growing — ready in %d day(s)" % [sname, days_left]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(info)

	else:
		# Mature — show harvest button
		var seed_id: String = str(plot_data.get("seed_id", ""))
		var sdata: Dictionary = GardenDefs.SEEDS.get(seed_id, {})
		var sname: String = str(sdata.get("display_name", seed_id))
		var plant_id: String = str(sdata.get("plant_id", ""))
		var yield_count: int = int(sdata.get("yield", 1))
		var info := Label.new()
		info.text = "%s is ready to harvest!" % sname
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", font_size)
		vbox.add_child(info)

		var harvest_btn := Button.new()
		harvest_btn.text = "Harvest (%d× %s)" % [yield_count, sname]
		harvest_btn.custom_minimum_size = Vector2(0, btn_h)
		harvest_btn.add_theme_font_size_override("font_size", font_size)
		harvest_btn.pressed.connect(func() -> void:
			sm.add_plants(plant_id, yield_count)
			sm.clear_plot(plot.plot_idx)
			GameBus.plant_harvested.emit(plot.plot_idx, yield_count)
			SceneManager.show_toast("Harvested!", "%d× %s" % [yield_count, sname])
			panel.queue_free()
		)
		vbox.add_child(harvest_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Close"
	cancel_btn.custom_minimum_size = Vector2(0, btn_h)
	cancel_btn.add_theme_font_size_override("font_size", font_size)
	cancel_btn.pressed.connect(func() -> void: panel.queue_free())
	vbox.add_child(cancel_btn)

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
	var overlay := _ChapterEndingOverlay.new()
	overlay.setup(pages)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 999
	get_tree().root.add_child(layer)
	layer.add_child(overlay)
	overlay.closed.connect(func() -> void: layer.queue_free())

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

	var layer := CanvasLayer.new()
	layer.layer = 50
	_hud.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.6
	var panel_h: float = vh * 0.38
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.96)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(vh * 0.022))
	margin.add_child(vbox)

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

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.03))
	vbox.add_child(row)

	if gate_remaining == 0 and player_coins >= wager:
		var duel_btn := Button.new()
		duel_btn.text = "Duel!"
		duel_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.07)
		duel_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
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

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.07)
	decline_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	decline_btn.pressed.connect(func() -> void: layer.queue_free())
	row.add_child(decline_btn)

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
		_handle_ping_tap(screen_pos)
		return
	var tile: Vector2i = _screen_to_tile(screen_pos)
	var tile_type: int = get_tile_global(tile.x, tile.y)
	var is_walkable: bool = (tile_type == IsoConst.TILE_GRASS
		or tile_type == IsoConst.TILE_HILL
		or tile_type == IsoConst.TILE_PATH)
	if not is_walkable:
		_show_tip("Can't go there")
		return
	var player_tile: Vector2i = IsoConst.world_to_tile(_player.position.x, _player.position.z)
	var path: Array[Vector2i] = Pathfinder.find_path(
		Callable(self, "get_tile_global"), player_tile, tile, 64)
	if path.is_empty():
		_show_tip("Can't reach that tile")
		return
	_place_dest_marker(tile)
	if _player.has_method("set_destination_path"):
		_player.call("set_destination_path", path)

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
		_dest_marker = _make_dest_marker()
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

func _make_dest_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "DestMarker"
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.72
	torus.rings = 12
	torus.ring_segments = 16
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 1.0, 0.55, 0.90)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 1.0, 0.55)
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	return root

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

func _ensure_social_buttons() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	# Social strip (GID-107 / TID-397): Emote / Ping / Chat share one compact,
	# registry-backed cluster (WorldHUD.ZONE_SOCIAL) instead of three buttons that
	# happen to share a y-coordinate by hand-picked position.
	if _emote_btn == null or not is_instance_valid(_emote_btn):
		_emote_btn = _world_hud.register_action("emote", ":)", WorldHUD.ZONE_SOCIAL,
			_toggle_emote_wheel, Callable(), Vector2(vh * 0.08, vh * 0.06))
		_emote_btn.tooltip_text = "Emote"
		_emote_btn.add_theme_font_size_override("font_size", int(vh * 0.026))
	if _ping_btn == null or not is_instance_valid(_ping_btn):
		# Built directly (not via register_action) since it needs a `.toggled`
		# connection, not a simple `.pressed` callback — same reasoning as the
		# Ranked toggle in _ensure_challenge_button().
		_ping_btn = Button.new()
		_ping_btn.text = "Ping"
		_ping_btn.tooltip_text = "Toggle ping mode — tap the world to place a ping"
		_ping_btn.toggle_mode = true
		_ping_btn.custom_minimum_size = Vector2(vh * 0.10, vh * 0.06)
		_ping_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
		_ping_btn.toggled.connect(func(on: bool) -> void: _ping_mode_active = on)
		var social_zone: Container = _world_hud.get_zone_container(WorldHUD.ZONE_SOCIAL)
		if social_zone != null:
			social_zone.add_child(_ping_btn)
		else:
			_hud.add_child(_ping_btn)
	# Trade / Spectate (GID-107 / TID-396): registered into WorldHUD.ZONE_CONTEXT —
	# the shared contextual bar — instead of each computing its own raw position.
	if _trade_window_mine == null or not is_instance_valid(_trade_window_mine):
		_trade_window_mine = _world_hud.register_action("trade", "Trade", WorldHUD.ZONE_CONTEXT,
			_open_trade_offer, Callable(), Vector2(vh * 0.22, vh * 0.06))
		_trade_window_mine.hide()
	if _spectate_btn == null or not is_instance_valid(_spectate_btn):
		_spectate_btn = _world_hud.register_action("spectate", "Spectate Duel", WorldHUD.ZONE_CONTEXT,
			_request_spectate, Callable(), Vector2(vh * 0.28, vh * 0.06))
		_spectate_btn.hide()
	# Leaderboard and Stash (GID-102 / TID-373, TID-376): now Party-panel actions
	# (GID-107 / TID-395) instead of their own standalone always-visible buttons.
	# Auction house button (GID-102 / TID-378): always visible while co-op is active
	# (global to the session, same as Stash). Placed on the next row down since the
	# Stash/Ghost-Duels row is already occupied at vh * 0.078.
	if _auction_btn == null or not is_instance_valid(_auction_btn):
		_auction_btn = Button.new()
		_auction_btn.text = "Auction"
		_auction_btn.tooltip_text = "Buy and sell cards asynchronously with the party"
		_auction_btn.custom_minimum_size = Vector2(vh * 0.16, vh * 0.055)
		_auction_btn.add_theme_font_size_override("font_size", int(vh * 0.020))
		_auction_btn.position = Vector2(vp.x * 0.012, vh * 0.144)
		_auction_btn.pressed.connect(_toggle_auction_overlay)
		_hud.add_child(_auction_btn)


## Ghost Duels (GID-102 / TID-377). Host-only: gated on SessionStore.is_open()
## rather than NetworkManager.is_active() — a client never opens SessionStore
## locally (see WorldScene._setup_session). Now a Party-panel action (GID-107 /
## TID-395) whose show_ghost_duels condition reproduces this same gate on open.

## Builds the {token, name, rating} row list from the host's own SessionState and
## opens (or closes) the GhostDuelOverlay. The local host's own token is excluded
## — dueling your own live snapshot is a no-op curiosity, not the intended use.
func _toggle_ghost_duel_overlay() -> void:
	if _ghost_duel_overlay != null and is_instance_valid(_ghost_duel_overlay):
		_ghost_duel_overlay.queue_free()
		_ghost_duel_overlay = null
		return
	if not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var local_token: String = MpProfile.get_token()
	var rows: Array = []
	for token in st.members.keys():
		var t: String = str(token)
		if t == local_token:
			continue
		var rec: Dictionary = st.get_member(t)
		if rec.is_empty():
			continue
		rows.append({
			"token": t,
			"name": str(rec.get("display_name", "Player")),
			"rating": int(rec.get("pvp_rating", 1000)),
		})
	var overlay := _GhostDuelOverlay.new()
	overlay.set_rows(rows)
	overlay.on_duel_requested = func(token: String) -> void:
		var snapshot: Dictionary = st.get_ghost_snapshot(token)
		if snapshot.is_empty():
			GameBus.hud_message_requested.emit("That ghost's deck couldn't be resolved.")
			return
		SceneManager.enter_ghost_duel(snapshot)
	overlay.closed.connect(func() -> void:
		_ghost_duel_overlay = null
		overlay.queue_free())
	_hud.add_child(overlay)
	_ghost_duel_overlay = overlay


## GID-107 / TID-396 priority rule: the world-interact prompt always wins the shared
## contextual slot over Trade/Spectate, same as it does over Challenge above.
func _update_social_proximity() -> void:
	if _player == null:
		return
	if _world_hud != null and _world_hud.is_interact_visible():
		if _trade_window_mine != null and is_instance_valid(_trade_window_mine):
			_trade_window_mine.hide()
		if _spectate_btn != null and is_instance_valid(_spectate_btn):
			_spectate_btn.hide()
		return
	var range_world: float = _CHALLENGE_RANGE * IsoConst.TILE_SIZE
	var nearest_pid: int = -1
	var nearest_d: float = range_world
	for pid in _remote_player_nodes.keys():
		var rp: Node3D = _valid_node3d(_remote_player_nodes[pid])
		if not is_instance_valid(rp) or not rp.visible:
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(
			Vector2(_player.position.x, _player.position.z))
		if d < nearest_d:
			nearest_d = d
			nearest_pid = int(pid)
	_trade_target_peer = nearest_pid
	if _trade_window_mine != null and is_instance_valid(_trade_window_mine):
		_trade_window_mine.visible = nearest_pid != -1 and _pending_challenge_from == -1 \
			and _pending_wager_from == -1
	if _spectate_btn != null and is_instance_valid(_spectate_btn):
		_spectate_btn.visible = _pvp_active_peers.size() >= 2


# ── TID-365: Emotes ────────────────────────────────────────────────────────────

func _toggle_emote_wheel() -> void:
	if _emote_wheel_panel != null and is_instance_valid(_emote_wheel_panel):
		_emote_wheel_panel.queue_free()
		_emote_wheel_panel = null
		return
	_show_emote_wheel()


func _show_emote_wheel() -> void:
	if _emote_wheel_panel != null and is_instance_valid(_emote_wheel_panel):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.90)
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(vp.x - vh * 0.52, vh * 0.66)
	_hud.add_child(panel)
	_emote_wheel_panel = panel
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(vh * 0.010))
	grid.add_theme_constant_override("v_separation", int(vh * 0.010))
	panel.add_child(grid)
	var emote_ids: Array[String] = _SocialSync.EMOTE_IDS
	for eid: String in emote_ids:
		var label: String = str(_SocialSync.EMOTE_LABELS.get(eid, eid))
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(vh * 0.14, vh * 0.055)
		btn.add_theme_font_size_override("font_size", int(vh * 0.020))
		var captured: String = eid
		btn.pressed.connect(func() -> void:
			if _emote_wheel_panel != null and is_instance_valid(_emote_wheel_panel):
				_emote_wheel_panel.queue_free()
				_emote_wheel_panel = null
			_send_emote(captured)
		)
		grid.add_child(btn)


func _send_emote(emote_id: String) -> void:
	if _net_sync == null or not _coop_active:
		return
	var payload: Array = _SocialSync.encode_emote(emote_id, map_name)
	_net_sync.rpc("recv_emote", payload)
	var label_text: String = str(_SocialSync.EMOTE_LABELS.get(emote_id, emote_id))
	_show_emote_self(label_text)


func _show_emote_self(text: String) -> void:
	if _emote_label_self == null or not is_instance_valid(_emote_label_self):
		_emote_label_self = Label3D.new()
		_emote_label_self.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_emote_label_self.font_size = 28
		_emote_label_self.modulate = Color(1.0, 1.0, 0.8)
		if _player != null:
			_player.add_child(_emote_label_self)
			_emote_label_self.position = Vector3(0.0, 2.0, 0.0)
	if _emote_label_self != null and is_instance_valid(_emote_label_self):
		_emote_label_self.text = text
		_emote_label_self.visible = true
	_emote_timer_self = _SocialSync.EMOTE_DURATION


func _tick_emote_self(delta: float) -> void:
	if _emote_timer_self > 0.0:
		_emote_timer_self -= delta
		if _emote_timer_self <= 0.0 and _emote_label_self != null \
				and is_instance_valid(_emote_label_self):
			_emote_label_self.visible = false


func _on_emote_received(sender: int, payload: Array) -> void:
	var d: Dictionary = _SocialSync.decode_emote(payload)
	var sender_map: String = str(d.get("map", ""))
	if sender_map != "" and sender_map != map_name:
		return
	var rp: Node = _valid_node(_remote_player_nodes.get(sender))
	if not is_instance_valid(rp):
		return
	var emote_id: String = str(d.get("emote_id", ""))
	var label_text: String = str(_SocialSync.EMOTE_LABELS.get(emote_id, emote_id))
	if rp.has_method("show_emote"):
		rp.call("show_emote", label_text)


# ── TID-365: World-space pings ─────────────────────────────────────────────────

func _handle_ping_tap(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if abs(ray_dir.y) < 0.0001:
		return
	var t: float = -ray_origin.y / ray_dir.y
	var world_pos: Vector3 = ray_origin + t * ray_dir
	var my_col: Color = MpProfile.get_color()
	var hex: String = "#%02x%02x%02x" % [
		int(my_col.r * 255), int(my_col.g * 255), int(my_col.b * 255)]
	_send_ping(world_pos.x, world_pos.z, _SocialSync.PING_PLACE, hex)


func _send_ping(wx: float, wz: float, kind: String, color_hex: String) -> void:
	if _net_sync == null or not _coop_active:
		return
	var payload: Array = _SocialSync.encode_ping(wx, wz, kind, color_hex, map_name)
	_net_sync.rpc("recv_ping", payload)
	_spawn_ping_marker(wx, wz, kind, color_hex)


func _on_ping_received(sender: int, payload: Array) -> void:
	var d: Dictionary = _SocialSync.decode_ping(payload)
	var sender_map: String = str(d.get("map", ""))
	if sender_map != "" and sender_map != map_name:
		return
	var wx: float = float(d.get("x", 0.0))
	var wz: float = float(d.get("z", 0.0))
	var kind: String = str(d.get("kind", _SocialSync.PING_PLACE))
	var col_hex: String = str(d.get("color_hex", "#ffffff"))
	_spawn_ping_marker(wx, wz, kind, col_hex)


func _spawn_ping_marker(wx: float, wz: float, _kind: String, color_hex: String) -> Node3D:
	var wy: float = get_terrain_height(wx, wz) + 0.3
	var root := Node3D.new()
	root.position = Vector3(wx, wy, wz)
	_entity_root.add_child(root)
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.45
	torus.rings = 10
	torus.ring_segments = 12
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var c: Color = Color.html(color_hex)
	mat.albedo_color = Color(c.r, c.g, c.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(c.r, c.g, c.b)
	mat.emission_energy_multiplier = 1.5
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	var tw: Tween = create_tween().set_loops(3)
	tw.tween_property(root, "scale", Vector3(1.4, 1.0, 1.4), 0.4)
	tw.tween_property(root, "scale", Vector3(0.8, 1.0, 0.8), 0.4)
	root.set_meta("ping_timer", _SocialSync.PING_DURATION)
	_ping_markers.append(root)
	return root


func _tick_ping_markers(delta: float) -> void:
	var to_remove: Array[Node3D] = []
	for m: Node3D in _ping_markers:
		if not is_instance_valid(m):
			to_remove.append(m)
			continue
		var t: float = float(m.get_meta("ping_timer", 0.0)) - delta
		m.set_meta("ping_timer", t)
		if t <= 0.0:
			m.queue_free()
			to_remove.append(m)
	for m: Node3D in to_remove:
		_ping_markers.erase(m)


# ── TID-374: Party chat ──────────────────────────────────────────────────────
# Quick-chat presets (reuses the emote-wheel GridContainer pattern) plus an
# optional free-text LineEdit, with a scrolling log panel. The log panel stays
# always-visible while in co-op (simplest option, matches the always-visible
# party bounty panel) rather than auto-fading — no extra show/hide state to
# manage, and chat is low-frequency enough that it won't clutter the screen.

func _ensure_chat_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	# Scrolling log panel, upper-left-ish (clear of the party bounty panel which
	# sits at vp.y * 0.50; chat log sits above it).
	if _chat_log_panel == null or not is_instance_valid(_chat_log_panel):
		var outer := PanelContainer.new()
		outer.name = "ChatLogPanel"
		outer.position = Vector2(vp.x * 0.012, vh * 0.16)
		outer.custom_minimum_size = Vector2(vp.x * 0.26, vh * 0.30)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.08, 0.78)
		style.corner_radius_top_left    = 6
		style.corner_radius_top_right   = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		outer.add_theme_stylebox_override("panel", style)
		_hud.add_child(outer)
		_chat_log_panel = outer
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(vp.x * 0.26, vh * 0.30)
		outer.add_child(scroll)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(vh * 0.004))
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		_chat_log_vbox = vbox

	# HUD toggle button: opens the quick-chat row and reveals the free-text input
	# (mobile parity — desktop also has the Enter-key shortcut below). Part of the
	# social strip (GID-107 / TID-397) alongside Emote/Ping — see _ensure_social_buttons().
	if _chat_toggle_btn == null or not is_instance_valid(_chat_toggle_btn):
		_chat_toggle_btn = _world_hud.register_action("chat", "Chat", WorldHUD.ZONE_SOCIAL,
			_toggle_chat_quick_panel, Callable(), Vector2(vh * 0.10, vh * 0.06))
		_chat_toggle_btn.tooltip_text = "Open chat (or press Enter)"
		_chat_toggle_btn.add_theme_font_size_override("font_size", int(vh * 0.024))

	# Free-text input + send button. Visible by default on desktop; mobile
	# users reveal it via the Chat HUD button (parity is satisfied either way
	# since both platforms can always tap "Chat" — desktop additionally gets
	# the Enter-key shortcut to focus it directly).
	if _chat_input == null or not is_instance_valid(_chat_input):
		_chat_input = LineEdit.new()
		_chat_input.placeholder_text = "Say something…"
		_chat_input.custom_minimum_size = Vector2(vp.x * 0.30, vh * 0.05)
		_chat_input.position = Vector2(vp.x * 0.012, vh * 0.93)
		_chat_input.add_theme_font_size_override("font_size", int(vh * 0.020))
		_chat_input.text_submitted.connect(func(_t: String) -> void: _submit_chat_input())
		_hud.add_child(_chat_input)
	if _chat_send_btn == null or not is_instance_valid(_chat_send_btn):
		_chat_send_btn = Button.new()
		_chat_send_btn.text = "Send"
		_chat_send_btn.custom_minimum_size = Vector2(vh * 0.10, vh * 0.05)
		_chat_send_btn.position = Vector2(vp.x * 0.32, vh * 0.93)
		_chat_send_btn.add_theme_font_size_override("font_size", int(vh * 0.020))
		_chat_send_btn.pressed.connect(_submit_chat_input)
		_hud.add_child(_chat_send_btn)


func _toggle_chat_quick_panel() -> void:
	if _chat_quick_panel != null and is_instance_valid(_chat_quick_panel):
		_chat_quick_panel.queue_free()
		_chat_quick_panel = null
		return
	_show_chat_quick_panel()


func _show_chat_quick_panel() -> void:
	if _chat_quick_panel != null and is_instance_valid(_chat_quick_panel):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.90)
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(vp.x - vh * 0.40, vh * 0.66)
	_hud.add_child(panel)
	_chat_quick_panel = panel
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(vh * 0.010))
	grid.add_theme_constant_override("v_separation", int(vh * 0.010))
	panel.add_child(grid)
	var presets: Array[String] = _ChatSync.QUICK_PRESETS
	for preset: String in presets:
		var btn := Button.new()
		btn.text = preset
		btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.055)
		btn.add_theme_font_size_override("font_size", int(vh * 0.018))
		var captured: String = preset
		btn.pressed.connect(func() -> void:
			if _chat_quick_panel != null and is_instance_valid(_chat_quick_panel):
				_chat_quick_panel.queue_free()
				_chat_quick_panel = null
			_send_chat_quick(captured)
		)
		grid.add_child(btn)
	# Mobile parity: opening the quick-chat row also surfaces the free-text
	# entry point, so a touch-only user can reach both from one "Chat" tap.
	if _chat_input != null and is_instance_valid(_chat_input):
		_chat_input.grab_focus()


func _submit_chat_input() -> void:
	if _chat_input == null or not is_instance_valid(_chat_input):
		return
	var raw: String = _chat_input.text
	_chat_input.text = ""
	if raw.strip_edges() == "":
		return
	_send_chat_text(raw)


func _send_chat_quick(preset: String) -> void:
	if _net_sync == null or not _coop_active:
		return
	var payload: Array = _ChatSync.encode_quick(preset, map_name)
	_net_sync.rpc("recv_chat", payload)
	var d: Dictionary = _ChatSync.decode(payload)
	_append_chat_line(MpProfile.get_display_name(), MpProfile.get_color(), str(d.get("text", preset)))


func _send_chat_text(raw_text: String) -> void:
	if _net_sync == null or not _coop_active:
		return
	var payload: Array = _ChatSync.encode_text(raw_text, map_name)
	_net_sync.rpc("recv_chat", payload)
	var d: Dictionary = _ChatSync.decode(payload)
	_append_chat_line(MpProfile.get_display_name(), MpProfile.get_color(), str(d.get("text", "")))


## Same-map filter mirrors `_on_emote_received`: a message from a peer on a
## different map is dropped rather than shown-but-tagged, for HUD consistency
## with how emotes already behave (an off-map peer's expression never appears).
func _on_chat_received(sender: int, payload: Array) -> void:
	var d: Dictionary = _ChatSync.decode(payload)
	var sender_map: String = str(d.get("map", ""))
	if sender_map != "" and sender_map != map_name:
		return
	var id: Dictionary = _remote_identities.get(sender, {})
	var nm: String = str(id.get("name", "Player"))
	var col: Color = id.get("color", Color(0.7, 0.85, 1.0))
	_append_chat_line(nm, col, str(d.get("text", "")))


func _append_chat_line(sender_name: String, color: Color, text: String) -> void:
	if text == "":
		return
	if _chat_log_vbox == null or not is_instance_valid(_chat_log_vbox):
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	var lbl := Label.new()
	lbl.text = "[%s] %s: %s" % [Time.get_time_string_from_system().substr(0, 5), sender_name, text]
	lbl.add_theme_font_size_override("font_size", int(vh * 0.016))
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log_vbox.add_child(lbl)
	_chat_lines.append({"name": sender_name, "color": color, "text": text})
	while _chat_lines.size() > _ChatSync.LOG_MAX_LINES:
		_chat_lines.pop_front()
		if _chat_log_vbox.get_child_count() > 0:
			_chat_log_vbox.get_child(0).queue_free()


# ── TID-366: Card trading & gifting ─────────────────────────────────────────────

func _open_trade_offer() -> void:
	if _trade_target_peer == -1 or _net_sync == null:
		return
	var deck: Array = _local_deck_for_net()
	if deck.is_empty():
		_show_tip("No cards in deck to trade.")
		return
	var top_card: Variant = deck[0]
	if not (top_card is Dictionary):
		_show_tip("No valid card to gift.")
		return
	var card_uid: String = str((top_card as Dictionary).get("uid", ""))
	if card_uid == "":
		_show_tip("No valid card UID.")
		return
	var trade_id: String = "%d_%d_%d" % [
		multiplayer.get_unique_id(), _trade_target_peer, Time.get_ticks_msec()]
	var payload: Dictionary = _TradeSync.encode_offer(
		trade_id,
		multiplayer.get_unique_id(),
		_trade_target_peer,
		card_uid,
		0, 0)
	if NetworkManager.is_host():
		_on_trade_offer_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_trade_offer", payload)
	_show_tip("Trade offer sent…")


func _on_trade_offer_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var offer: Dictionary = _TradeSync.decode_offer(payload)
	if offer.is_empty():
		return
	var trade_id: String = str(offer.get("trade_id", ""))
	var target_peer: int = int(offer.get("target_peer", -1))
	var initiator_peer: int = int(offer.get("initiator_peer", sender))
	var card_uid: String = str(offer.get("card_uid", ""))
	var token_init: String = str(_session_token_by_peer.get(initiator_peer,
		MpProfile.get_token() if initiator_peer == multiplayer.get_unique_id() else ""))
	var st = SessionStore.get_state()
	var valid: bool = false
	if st != null and token_init != "":
		var rec: Dictionary = st.get_member(token_init)
		var owned: Array = rec.get("owned_cards", []) as Array
		for card: Variant in owned:
			if card is Dictionary and str((card as Dictionary).get("uid", "")) == card_uid:
				valid = true
				break
	if not valid:
		var cancel: Dictionary = _TradeSync.encode_update(
			trade_id, _TradeSync.STATUS_CANCELLED, {})
		if _net_sync != null:
			_net_sync.rpc_id(initiator_peer, "recv_trade_update", cancel)
		return
	_pending_trade = offer
	var update: Dictionary = _TradeSync.encode_update(
		trade_id, _TradeSync.STATUS_PROPOSED, offer)
	if target_peer == multiplayer.get_unique_id():
		_on_trade_update_received(update)
	elif _net_sync != null:
		_net_sync.rpc_id(target_peer, "recv_trade_update", update)


func _on_trade_confirm_submitted(sender: int, trade_id: String, confirmed: bool) -> void:
	if not NetworkManager.is_host():
		return
	if str(_pending_trade.get("trade_id", "")) != trade_id:
		return
	var offer: Dictionary = _pending_trade.duplicate(true)
	_pending_trade = {}
	var init_p: int = int(offer.get("initiator_peer", -1))
	var tgt_p: int = int(offer.get("target_peer", -1))
	if not confirmed:
		var cancel: Dictionary = _TradeSync.encode_update(
			trade_id, _TradeSync.STATUS_CANCELLED, {})
		if init_p == multiplayer.get_unique_id():
			_on_trade_update_received(cancel)
		elif _net_sync != null:
			_net_sync.rpc_id(init_p, "recv_trade_update", cancel)
		return
	var card_uid: String = str(offer.get("card_uid", ""))
	var st = SessionStore.get_state()
	if st != null:
		var token_i: String = str(_session_token_by_peer.get(init_p,
			MpProfile.get_token() if init_p == multiplayer.get_unique_id() else ""))
		var token_t: String = str(_session_token_by_peer.get(tgt_p,
			MpProfile.get_token() if tgt_p == multiplayer.get_unique_id() else ""))
		_transfer_card_in_session(st, token_i, token_t, card_uid)
	var complete: Dictionary = _TradeSync.encode_update(
		trade_id, _TradeSync.STATUS_COMPLETED, offer)
	if init_p == multiplayer.get_unique_id():
		_on_trade_update_received(complete)
	elif _net_sync != null:
		_net_sync.rpc_id(init_p, "recv_trade_update", complete)
	if tgt_p == multiplayer.get_unique_id():
		_on_trade_update_received(complete)
	elif _net_sync != null:
		_net_sync.rpc_id(tgt_p, "recv_trade_update", complete)


func _transfer_card_in_session(st: RefCounted, giver_token: String, target_token: String, card_uid: String) -> void:
	if giver_token == "" or target_token == "":
		return
	var g_rec: Dictionary = st.get_member(giver_token)
	var t_rec: Dictionary = st.get_member(target_token)
	if g_rec.is_empty() or t_rec.is_empty():
		return
	var g_owned: Array = g_rec.get("owned_cards", []) as Array
	var g_deck: Array = g_rec.get("player_deck", []) as Array
	var card_inst: Dictionary = {}
	for i: int in range(g_owned.size() - 1, -1, -1):
		var c: Variant = g_owned[i]
		if c is Dictionary and str((c as Dictionary).get("uid", "")) == card_uid:
			card_inst = (c as Dictionary).duplicate(true)
			g_owned.remove_at(i)
			break
	if card_inst.is_empty():
		return
	g_deck.erase(card_uid)
	g_rec["owned_cards"] = g_owned
	g_rec["player_deck"] = g_deck
	var new_uid: String = card_uid + "_gift_" + target_token.substr(0, 4)
	card_inst["uid"] = new_uid
	var t_owned: Array = t_rec.get("owned_cards", []) as Array
	t_owned.append(card_inst)
	t_rec["owned_cards"] = t_owned
	st.update_member(giver_token, g_rec)
	st.update_member(target_token, t_rec)
	SessionStore.mark_dirty()


func _on_trade_update_received(payload: Dictionary) -> void:
	var update: Dictionary = _TradeSync.decode_update(payload)
	var status: String = str(update.get("status", ""))
	var trade_id: String = str(update.get("trade_id", ""))
	match status:
		_TradeSync.STATUS_PROPOSED:
			var detail: Dictionary = update.get("detail", {}) as Dictionary
			_show_trade_accept_panel(trade_id, detail)
		_TradeSync.STATUS_COMPLETED:
			SceneManager.show_toast("Trade Complete", "Card transferred successfully!")
		_TradeSync.STATUS_CANCELLED:
			_show_tip("Trade cancelled.")


func _show_trade_accept_panel(trade_id: String, offer: Dictionary) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var layer := CanvasLayer.new()
	layer.layer = 182
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.02))
	panel.add_child(vbox)
	var lbl := Label.new()
	var card_uid: String = str(offer.get("card_uid", "unknown"))
	lbl.text = "Trade offer received!\nCard: %s\nAccept?" % card_uid
	lbl.add_theme_font_size_override("font_size", int(vh * 0.026))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.03))
	vbox.add_child(row)
	var captured_id: String = trade_id
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.06)
	accept_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	accept_btn.pressed.connect(func() -> void:
		layer.queue_free()
		if NetworkManager.is_host():
			_on_trade_confirm_submitted(multiplayer.get_unique_id(), captured_id, true)
		elif _net_sync != null:
			_net_sync.rpc_id(1, "submit_trade_confirm", captured_id, true)
	)
	row.add_child(accept_btn)
	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.06)
	decline_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	decline_btn.pressed.connect(func() -> void:
		layer.queue_free()
		if NetworkManager.is_host():
			_on_trade_confirm_submitted(multiplayer.get_unique_id(), captured_id, false)
		elif _net_sync != null:
			_net_sync.rpc_id(1, "submit_trade_confirm", captured_id, false)
	)
	row.add_child(decline_btn)


# ── GID-102 / TID-376: Shared party stash ───────────────────────────────────────
# A session-owned chest any member can deposit into / withdraw from — unlike trading,
# this is global to the session (no proximity gate). Transfer logic delegates to the
# pure, unit-tested StashTransfer helper; only the authority mutates SessionState.

## Resolve the local token for `peer_id` — the identity token map for remote peers,
## or our own MpProfile token when the sender is us (host acting on its own behalf).
func _stash_token_for_peer(peer_id: int) -> String:
	return str(_session_token_by_peer.get(peer_id,
		MpProfile.get_token() if peer_id == multiplayer.get_unique_id() else ""))


func _on_stash_deposit_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = _stash_token_for_peer(sender)
	if token == "" or not st.has_member(token):
		return
	var member_rec: Dictionary = st.get_member(token)
	var kind: String = str(payload.get("kind", "card"))
	var result: Dictionary
	if kind == "coins":
		result = _StashTransfer.deposit_coins(st.stash, member_rec, int(payload.get("amount", 0)))
	else:
		result = _StashTransfer.deposit_card(st.stash, member_rec, str(payload.get("card_uid", "")))
	if not bool(result.get("ok", false)):
		if kind != "coins":
			_show_tip("Could not deposit that card.")
		return
	st.stash = result.get("stash", st.stash)
	var updated_member: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member)
	_broadcast_stash_update()


func _on_stash_withdraw_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = _stash_token_for_peer(sender)
	if token == "" or not st.has_member(token):
		return
	var member_rec: Dictionary = st.get_member(token)
	var kind: String = str(payload.get("kind", "card"))
	var result: Dictionary
	if kind == "coins":
		result = _StashTransfer.withdraw_coins(st.stash, member_rec, int(payload.get("amount", 0)))
	else:
		result = _StashTransfer.withdraw_card(st.stash, member_rec, str(payload.get("card_uid", "")), token)
	if not bool(result.get("ok", false)):
		if kind != "coins":
			_show_tip("Could not withdraw that card.")
		return
	st.stash = result.get("stash", st.stash)
	var updated_member2: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member2)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member2)
	_broadcast_stash_update()


## Keeps the acting peer's in-memory character (SaveManager fields / adopted session
## character) in sync with the record `StashTransfer` just mutated, so the next
## periodic persist-back tick (`_tick_session_persist`) doesn't clobber the stash
## change with stale in-memory data — the host re-adopts directly; a remote client
## gets an updated `recv_character` mirror (resume flag false: this isn't a reconnect,
## just a refresh, so no position restore).
func _apply_updated_member_to_actor(sender: int, updated_member: Dictionary) -> void:
	if sender == multiplayer.get_unique_id():
		SceneManager.save_manager.adopt_session_character(updated_member)
	elif _net_sync != null:
		_net_sync.rpc_id(sender, "recv_character", updated_member, false)


## Host: push the current stash snapshot to one peer (target_peer == 0 broadcasts to all).
func _broadcast_stash_update(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	_stash_cache = st.stash
	if target_peer == 0:
		_net_sync.rpc("recv_stash_update", st.stash)
	else:
		_net_sync.rpc_id(target_peer, "recv_stash_update", st.stash)
	if NetworkManager.is_host():
		_refresh_stash_overlay()


## Any peer: receive a stash snapshot (initial push, post-transfer update, or the
## late-join send) and refresh the overlay if it's open.
func _on_stash_update_received(snapshot: Dictionary) -> void:
	_stash_cache = snapshot
	_refresh_stash_overlay()


func _refresh_stash_overlay() -> void:
	if _stash_overlay != null and is_instance_valid(_stash_overlay) \
			and _stash_overlay.has_method("refresh"):
		_stash_overlay.refresh(_my_collection_for_stash_ui(), _stash_cache)


## My current owned-card collection for the stash UI's "deposit" column.
func _my_collection_for_stash_ui() -> Array:
	var out: Array = []
	for inst in SceneManager.save_manager.owned_cards:
		out.append(inst)
	return out


## Opens (or closes, if already open) the party stash overlay. HUD button, always
## visible while co-op is active — global to the session (mobile/desktop parity).
func _toggle_stash_overlay() -> void:
	if _stash_overlay != null and is_instance_valid(_stash_overlay):
		_stash_overlay.queue_free()
		_stash_overlay = null
		return
	_stash_overlay = _PartyStashOverlay.new()
	_stash_overlay.world_scene = self
	add_child(_stash_overlay)
	_stash_overlay.closed.connect(func() -> void: _stash_overlay = null)
	_stash_overlay.refresh(_my_collection_for_stash_ui(), _stash_cache)


## Called by PartyStashOverlay when the player presses "Deposit" on a card.
func request_stash_deposit_card(card_uid: String) -> void:
	if _net_sync == null:
		return
	var payload: Dictionary = {"kind": "card", "card_uid": card_uid, "amount": 0}
	if NetworkManager.is_host():
		_on_stash_deposit_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_stash_deposit", payload)


## Called by PartyStashOverlay when the player presses "Withdraw" on a stash card.
func request_stash_withdraw_card(stash_uid: String) -> void:
	if _net_sync == null:
		return
	var payload: Dictionary = {"kind": "card", "card_uid": stash_uid, "amount": 0}
	if NetworkManager.is_host():
		_on_stash_withdraw_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_stash_withdraw", payload)


## Called by PartyStashOverlay's coin deposit stepper.
func request_stash_deposit_coins(amount: int) -> void:
	if _net_sync == null or amount <= 0:
		return
	var payload: Dictionary = {"kind": "coins", "card_uid": "", "amount": amount}
	if NetworkManager.is_host():
		_on_stash_deposit_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_stash_deposit", payload)


## Called by PartyStashOverlay's coin withdraw stepper.
func request_stash_withdraw_coins(amount: int) -> void:
	if _net_sync == null or amount <= 0:
		return
	var payload: Dictionary = {"kind": "coins", "card_uid": "", "amount": amount}
	if NetworkManager.is_host():
		_on_stash_withdraw_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_stash_withdraw", payload)


# ── GID-102 / TID-378: Async card auction house ──────────────────────────────────
# Global to the session, same as the stash — no proximity gate. Transfer logic
# delegates to the pure, unit-tested AuctionTransfer helper; only the authority
# mutates SessionState. Reuses _stash_token_for_peer for sender -> token lookup.

func _on_auction_list_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = _stash_token_for_peer(sender)
	if token == "" or not st.has_member(token):
		return
	var intent: Dictionary = _AuctionSync.decode_list_intent(payload)
	var member_rec: Dictionary = st.get_member(token)
	var expires_day: int = st.days_elapsed + _AuctionSync.LISTING_DURATION_DAYS
	var list_card_uid: String = str(intent.get("card_uid", ""))
	var list_buyout: int = int(intent.get("buyout", 0))
	var result: Dictionary = _AuctionTransfer.list_card(
		st.auctions, member_rec, token, list_card_uid, list_buyout, expires_day)
	if not bool(result.get("ok", false)):
		_show_tip("Could not list that card.")
		return
	st.auctions = result.get("auctions", st.auctions)
	var updated_member: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member)
	_broadcast_auction_update()


func _on_auction_bid_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = _stash_token_for_peer(sender)
	if token == "" or not st.has_member(token):
		return
	var intent: Dictionary = _AuctionSync.decode_bid_intent(payload)
	var member_rec: Dictionary = st.get_member(token)
	var bid_auction_id: String = str(intent.get("auction_id", ""))
	var bid_amount: int = int(intent.get("amount", 0))
	var result: Dictionary = _AuctionTransfer.place_bid(
		st.auctions, member_rec, token, bid_auction_id, bid_amount)
	if not bool(result.get("ok", false)):
		_show_tip("Could not place that bid.")
		return
	st.auctions = result.get("auctions", st.auctions)
	SessionStore.mark_dirty()
	_broadcast_auction_update()


func _on_auction_buyout_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var buyer_token: String = _stash_token_for_peer(sender)
	if buyer_token == "" or not st.has_member(buyer_token):
		return
	var intent: Dictionary = _AuctionSync.decode_id_intent(payload)
	var buyout_auction_id: String = str(intent.get("auction_id", ""))
	var listing: Dictionary = _find_auction(st.auctions, buyout_auction_id)
	var seller_token: String = str(listing.get("seller_token", ""))
	if seller_token == "" or not st.has_member(seller_token):
		_show_tip("Could not buy that listing.")
		return
	var buyer_rec: Dictionary = st.get_member(buyer_token)
	var seller_rec: Dictionary = st.get_member(seller_token)
	var result: Dictionary = _AuctionTransfer.buyout(
		st.auctions, buyer_rec, buyer_token, seller_rec, buyout_auction_id)
	if not bool(result.get("ok", false)):
		_show_tip("Could not buy that listing.")
		return
	st.auctions = result.get("auctions", st.auctions)
	var updated_buyer: Dictionary = result.get("buyer", buyer_rec)
	var updated_seller: Dictionary = result.get("seller", seller_rec)
	st.update_member(buyer_token, updated_buyer)
	st.update_member(seller_token, updated_seller)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_buyer)
	_apply_updated_member_to_peer_by_token(seller_token, updated_seller)
	_broadcast_auction_update()


func _on_auction_cancel_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = _stash_token_for_peer(sender)
	if token == "" or not st.has_member(token):
		return
	var intent: Dictionary = _AuctionSync.decode_id_intent(payload)
	var member_rec: Dictionary = st.get_member(token)
	var cancel_auction_id: String = str(intent.get("auction_id", ""))
	var result: Dictionary = _AuctionTransfer.cancel(st.auctions, member_rec, token, cancel_auction_id)
	if not bool(result.get("ok", false)):
		_show_tip("Could not cancel that listing.")
		return
	st.auctions = result.get("auctions", st.auctions)
	var updated_member: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member)
	_broadcast_auction_update()


## Host-tick sweep (called from _tick_session_persist): settle any active listing
## whose expires_day has passed. See AuctionTransfer.settle_expired — a listing
## with a standing bid the bidder can still afford sells to them, otherwise the
## card returns to the seller. Silently updates any member whose actor is
## currently connected so their local collection stays in sync.
func _sweep_expired_auctions() -> void:
	var st = SessionStore.get_state()
	if st == null or (st.auctions as Array).is_empty():
		return
	var result: Dictionary = _AuctionTransfer.settle_expired(st.auctions, st.members, st.days_elapsed)
	var new_auctions: Array = result.get("auctions", st.auctions)
	if new_auctions == st.auctions:
		return
	var new_members: Dictionary = result.get("members", st.members)
	st.auctions = new_auctions
	for token in new_members.keys():
		var rec: Variant = new_members[token]
		if rec is Dictionary:
			st.update_member(str(token), rec as Dictionary)
			_apply_updated_member_to_peer_by_token(str(token), rec as Dictionary)
	SessionStore.mark_dirty()
	_broadcast_auction_update()


## Resolve the connected peer id for `token` (reverse of _stash_token_for_peer),
## or -1 if that member isn't a currently-connected peer.
func _peer_for_token(token: String) -> int:
	if token == MpProfile.get_token():
		return multiplayer.get_unique_id()
	for peer_id in _session_token_by_peer.keys():
		if str(_session_token_by_peer[peer_id]) == token:
			return int(peer_id)
	return -1


## Like _apply_updated_member_to_actor, but resolved from a token rather than a
## sender peer id — used when the auction settlement touches a member who isn't
## the RPC sender (the seller on a buyout, any party on an expiry sweep).
func _apply_updated_member_to_peer_by_token(token: String, updated_member: Dictionary) -> void:
	var peer_id: int = _peer_for_token(token)
	if peer_id == -1:
		return  # not currently connected — their next reconnect adopts the persisted record
	_apply_updated_member_to_actor(peer_id, updated_member)


func _find_auction(auctions: Array, auction_id: String) -> Dictionary:
	for a: Variant in auctions:
		if a is Dictionary and str((a as Dictionary).get("id", "")) == auction_id:
			return a as Dictionary
	return {}


## Host: push the current listings snapshot to one peer (target_peer == 0 broadcasts to all).
func _broadcast_auction_update(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	_auction_cache = _AuctionSync.decode_snapshot(st.auctions)
	if target_peer == 0:
		_net_sync.rpc("recv_auction_update", st.auctions)
	else:
		_net_sync.rpc_id(target_peer, "recv_auction_update", st.auctions)
	if NetworkManager.is_host():
		_refresh_auction_overlay()


## Any peer: receive a listings snapshot (initial push, post-transfer update, or
## the late-join send) and refresh the overlay if it's open.
func _on_auction_update_received(snapshot: Array) -> void:
	_auction_cache = _AuctionSync.decode_snapshot(snapshot)
	_refresh_auction_overlay()


func _refresh_auction_overlay() -> void:
	if _auction_overlay != null and is_instance_valid(_auction_overlay) \
			and _auction_overlay.has_method("refresh"):
		_auction_overlay.refresh(_my_collection_for_stash_ui(), _auction_cache, MpProfile.get_token())


## Opens (or closes, if already open) the auction house overlay. HUD button,
## always visible while co-op is active — global to the session.
func _toggle_auction_overlay() -> void:
	if _auction_overlay != null and is_instance_valid(_auction_overlay):
		_auction_overlay.queue_free()
		_auction_overlay = null
		return
	_auction_overlay = _AuctionHouseOverlay.new()
	_auction_overlay.world_scene = self
	add_child(_auction_overlay)
	_auction_overlay.closed.connect(func() -> void: _auction_overlay = null)
	_auction_overlay.refresh(_my_collection_for_stash_ui(), _auction_cache, MpProfile.get_token())


## Called by AuctionHouseOverlay when the player presses "List" on a card.
func request_auction_list(card_uid: String, buyout: int) -> void:
	if _net_sync == null or buyout <= 0:
		return
	var payload: Dictionary = _AuctionSync.encode_list_intent(card_uid, buyout)
	if NetworkManager.is_host():
		_on_auction_list_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_auction_list", payload)


## Called by AuctionHouseOverlay's bid stepper.
func request_auction_bid(auction_id: String, amount: int) -> void:
	if _net_sync == null or amount <= 0:
		return
	var payload: Dictionary = _AuctionSync.encode_bid_intent(auction_id, amount)
	if NetworkManager.is_host():
		_on_auction_bid_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_auction_bid", payload)


## Called by AuctionHouseOverlay's "Buyout" button.
func request_auction_buyout(auction_id: String) -> void:
	if _net_sync == null:
		return
	var payload: Dictionary = _AuctionSync.encode_id_intent(auction_id)
	if NetworkManager.is_host():
		_on_auction_buyout_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_auction_buyout", payload)


## Called by AuctionHouseOverlay's "Cancel" button (My Listings tab).
func request_auction_cancel(auction_id: String) -> void:
	if _net_sync == null:
		return
	var payload: Dictionary = _AuctionSync.encode_id_intent(auction_id)
	if NetworkManager.is_host():
		_on_auction_cancel_submitted(multiplayer.get_unique_id(), payload)
	else:
		_net_sync.rpc_id(1, "submit_auction_cancel", payload)


# ── TID-367: PvP spectating ────────────────────────────────────────────────────

func _on_pvp_active_received(in_battle: bool, peer_a: int, peer_b: int) -> void:
	if in_battle:
		if not _pvp_active_peers.has(peer_a):
			_pvp_active_peers.append(peer_a)
		if not _pvp_active_peers.has(peer_b):
			_pvp_active_peers.append(peer_b)
	else:
		_pvp_active_peers.erase(peer_a)
		_pvp_active_peers.erase(peer_b)
	if _spectate_btn != null and is_instance_valid(_spectate_btn):
		_spectate_btn.visible = _pvp_active_peers.size() >= 2


func _request_spectate() -> void:
	if _net_sync == null:
		return
	if NetworkManager.is_host():
		_show_tip("You are in the duel — cannot spectate.")
		return
	_net_sync.rpc_id(1, "request_spectate_pvp")


func _on_spectate_pvp_requested(sender: int) -> void:
	if not NetworkManager.is_host():
		return
	if _pvp_active_peers.size() < 2:
		return
	if _net_sync != null:
		_net_sync.rpc_id(sender, "recv_spectate_approved")


func _on_spectate_approved() -> void:
	SceneManager.enter_pvp_spectator()


# ── TID-368: Wagered duels & champion record ──────────────────────────────────

func _request_wager_challenge(ante_coins: int) -> void:
	if _challenge_target_peer == -1 or _net_sync == null:
		return
	if SceneManager.save_manager.coins < ante_coins:
		_show_tip("Not enough coins to wager (need %d)." % ante_coins)
		return
	var my_deck: Array = _local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_show_tip("Your deck is too small to duel.")
		return
	_net_sync.rpc_id(_challenge_target_peer, "request_battle_wager", my_deck, ante_coins)
	_show_tip("Wagered challenge sent…")


func _on_battle_wager_requested(sender: int, challenger_deck: Array, ante_coins: int) -> void:
	if _pending_challenge_from != -1 or _pending_wager_from != -1:
		return
	_pending_wager_from = sender
	_pending_wager_deck = challenger_deck
	_pending_wager_coins = ante_coins
	_show_wager_accept_panel(sender, ante_coins)


func _show_wager_accept_panel(from_id: int, ante_coins: int) -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var layer := CanvasLayer.new()
	layer.layer = 181
	add_child(layer)
	_challenge_accept_panel = layer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.025))
	panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Wagered duel challenge!\nAnte: %d coins each. Accept?" % ante_coins
	lbl.add_theme_font_size_override("font_size", int(vh * 0.03))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.03))
	vbox.add_child(row)
	var accept_btn := Button.new()
	accept_btn.text = "Accept (%d coins)" % ante_coins
	accept_btn.custom_minimum_size = Vector2(vh * 0.26, vh * 0.07)
	accept_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	accept_btn.pressed.connect(_accept_wager_challenge.bind(from_id, ante_coins))
	row.add_child(accept_btn)
	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.07)
	decline_btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	decline_btn.pressed.connect(_decline_wager_challenge.bind(from_id))
	row.add_child(decline_btn)


func _accept_wager_challenge(from_id: int, ante_coins: int) -> void:
	_dismiss_challenge_panel()
	if SceneManager.save_manager.coins < ante_coins:
		_show_tip("Not enough coins for the wager.")
		if _net_sync != null:
			_net_sync.rpc_id(from_id, "respond_battle_wager", false, [], 0)
		_pending_wager_from = -1
		_pending_wager_deck = []
		_pending_wager_coins = 0
		return
	var my_deck: Array = _local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_show_tip("Your deck is too small to duel.")
		if _net_sync != null:
			_net_sync.rpc_id(from_id, "respond_battle_wager", false, [], 0)
		_pending_wager_from = -1
		_pending_wager_deck = []
		_pending_wager_coins = 0
		return
	var opp_deck: Array = _pending_wager_deck
	_pending_wager_from = -1
	_pending_wager_deck = []
	_pending_wager_coins = 0
	if _net_sync != null:
		_net_sync.rpc_id(from_id, "respond_battle_wager", true, my_deck, ante_coins)
	_enter_pvp_wagered(ante_coins, opp_deck)


func _decline_wager_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	if _net_sync != null:
		_net_sync.rpc_id(from_id, "respond_battle_wager", false, [], 0)
	_pending_wager_from = -1
	_pending_wager_deck = []
	_pending_wager_coins = 0


func _on_battle_wager_responded(_sender: int, accepted: bool, responder_deck: Array, ante_coins: int) -> void:
	if not accepted:
		_show_tip("Wagered challenge declined.")
		return
	_enter_pvp_wagered(ante_coins, responder_deck)


func _enter_pvp_wagered(ante: int, opp_deck: Array) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	SceneManager.save_manager.add_coins(-ante)
	_pvp_ante_coins = ante
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	if NetworkManager.is_host() and _net_sync != null:
		var my_id: int = multiplayer.get_unique_id()
		_pvp_ante_peer0 = my_id
		_pvp_ante_peer1 = _challenge_target_peer
		for pid in multiplayer.get_peers():
			var p: int = int(pid)
			if p != _challenge_target_peer:
				_net_sync.rpc_id(p, "recv_pvp_active", true, my_id, _challenge_target_peer)
	var opp_token: String = str(_session_token_by_peer.get(_challenge_target_peer, ""))
	SceneManager.enter_pvp_battle(local_idx, opp_deck, ante, opp_token)


func _on_pvp_battle_ended_coop(did_win: bool) -> void:
	if not _coop_active:
		return
	# GID-104 (TID-386): tournament matches have their own bracket-scoped payout
	# and never touch the champion-record/rating/ante-wager systems below — a
	# tournament match is never wagered/ranked through the normal challenge flow.
	if _tournament_active:
		_on_tournament_pvp_ended(did_win)
		return
	# Wager payout (TID-368): winner gets both antes back.
	if _pvp_ante_coins > 0:
		if did_win:
			SceneManager.save_manager.add_coins(_pvp_ante_coins * 2)
		_pvp_ante_coins = 0
	# Champion record (TID-368): update pvp stats in session record (host only).
	if NetworkManager.is_host() and SessionStore.is_open():
		var token: String = MpProfile.get_token()
		var st = SessionStore.get_state()
		if st != null:
			var rec: Dictionary = st.get_member(token)
			if not rec.is_empty():
				var wins: int = int(rec.get("pvp_wins", 0))
				var losses: int = int(rec.get("pvp_losses", 0))
				var streak: int = int(rec.get("pvp_streak", 0))
				var best: int = int(rec.get("pvp_best_streak", 0))
				if did_win:
					wins += 1
					streak += 1
					if streak > best:
						best = streak
				else:
					losses += 1
					streak = 0
				rec["pvp_wins"] = wins
				rec["pvp_losses"] = losses
				rec["pvp_streak"] = streak
				rec["pvp_best_streak"] = best
				st.update_member(token, rec)
				SessionStore.mark_dirty()
			# Ranked rating (TID-370) — gated on the duel's ranked opt-in (GID-102 / TID-373):
			# the authority owns both records, so it computes both combatants' ELO deltas and
			# writes both. The host is one combatant; the opponent is the duel peer captured
			# at battle-start (_pvp_ante_peer1). Casual (non-ranked) duels never touch rating.
			if _pvp_ranked:
				_update_pvp_ratings(st, token, did_win)
				# Broadcast a fresh leaderboard snapshot now that ratings changed.
				_broadcast_leaderboard()
	_pvp_ranked = false
	# Signal spectators to return to world when WorldScene re-enters the tree.
	_pvp_ended_pending_broadcast = true


## Host-authority ranked rating update for a finished duel (GID-102 / TID-370).
## `host_token` is the host's own member; `_pvp_ante_peer1` identifies the opponent peer
## (set in `_enter_pvp` / `_enter_pvp_wagered`). Both ratings move zero-sum-ish via ELO;
## a client never rates itself, so this only runs on the host (caller already guards that).
## Only called for ranked duels (see _on_pvp_battle_ended_coop).
##
## Rating-delta display (GID-102 / TID-373): BattleResultUI.show_pvp_result() is shown by
## BattleScene._finish_pvp BEFORE GameBus.pvp_battle_ended fires, but this update only runs
## AFTER that signal, here in WorldScene once the battle has ended — so the result screen
## cannot know the delta at the moment it is shown without restructuring the host-authoritative
## battle-end sequencing (out of scope / risky, see task file). Instead each combatant gets a
## toast once back in the world: the host shows its own delta locally; the opponent's delta is
## unicast via a tiny dedicated RPC (recv_rating_delta) right after this update, reusing the
## existing low-risk end-of-action toast pattern (hud_message_requested).
func _update_pvp_ratings(st, host_token: String, host_won: bool) -> void:
	var opp_peer: int = _pvp_ante_peer1
	if opp_peer <= 0:
		return
	var opp_token: String = str(_session_token_by_peer.get(opp_peer, ""))
	if host_token == "" or opp_token == "" or host_token == opp_token:
		return
	var host_rec: Dictionary = st.get_member(host_token)
	var opp_rec: Dictionary = st.get_member(opp_token)
	if host_rec.is_empty() or opp_rec.is_empty():
		return
	var r_host: int = int(host_rec.get("pvp_rating", _RatingMath.START_RATING))
	var r_opp: int = int(opp_rec.get("pvp_rating", _RatingMath.START_RATING))
	var g_host: int = int(host_rec.get("pvp_games", 0))
	var g_opp: int = int(opp_rec.get("pvp_games", 0))
	var host_score: float = 1.0 if host_won else 0.0
	var new_host_rating: int = _RatingMath.updated(r_host, r_opp, host_score, g_host)
	var new_opp_rating: int = _RatingMath.updated(r_opp, r_host, 1.0 - host_score, g_opp)
	var host_delta: int = new_host_rating - r_host
	var opp_delta: int = new_opp_rating - r_opp
	host_rec["pvp_rating"] = new_host_rating
	host_rec["pvp_games"] = g_host + 1
	opp_rec["pvp_rating"] = new_opp_rating
	opp_rec["pvp_games"] = g_opp + 1
	st.update_member(host_token, host_rec)
	st.update_member(opp_token, opp_rec)
	SessionStore.mark_dirty()
	# Toast both combatants with their rating delta (TID-373). The host shows its own
	# locally; the opponent's is unicast since only the host computed it.
	GameBus.hud_message_requested.emit(_format_rating_delta(host_delta))
	if _net_sync != null:
		_net_sync.rpc_id(opp_peer, "recv_rating_delta", opp_delta)


## "+N rating" (gold) / "-N rating" formatted as plain text for hud_message_requested
## (that signal carries text only, no color — color is the toast UI's own styling).
func _format_rating_delta(delta: int) -> String:
	return "+%d rating" % delta if delta >= 0 else "%d rating" % delta


## Client: receive our own rating delta toast from the host after a ranked duel.
func _on_rating_delta_received(delta: int) -> void:
	GameBus.hud_message_requested.emit(_format_rating_delta(delta))


## Host-only: ranked rating update for a finished 2v2 team duel (GID-102 / TID-371).
## did_win is the host's own perspective (team_assignments[0]'s result). Uses the
## formation _start_team_duel recorded to resolve all 4 tokens, then applies a
## "team-average expected score" ELO update per the task notes: each player's rating
## moves against the *average* rating of the opposing team, scored 1.0/0.0 for their
## team's win/loss (not pairwise per-opponent). A client never rates itself — this is
## a no-op when _active_team_duel_peer_ids is empty (every non-host peer, and the host
## itself once the formation has been consumed/cleared).
func _on_team_battle_ended_coop(did_win: bool) -> void:
	if not NetworkManager.is_host() or _active_team_duel_peer_ids.is_empty():
		return
	var peer_ids: Array[int] = _active_team_duel_peer_ids
	var teams: Array = _active_team_duel_teams
	_active_team_duel_peer_ids = []
	_active_team_duel_teams = []
	if not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var host_id: int = multiplayer.get_unique_id()
	var tokens: Array[String] = []
	for pid in peer_ids:
		var token: String = MpProfile.get_token() if pid == host_id else str(_session_token_by_peer.get(pid, ""))
		tokens.append(token)
	if tokens.has(""):
		return  # an unresolved token means a peer left mid-duel — skip the rating update
	var recs: Array[Dictionary] = []
	for token in tokens:
		var rec: Dictionary = st.get_member(token)
		if rec.is_empty():
			return
		recs.append(rec)
	var team0_idxs: Array[int] = []
	var team1_idxs: Array[int] = []
	for i in range(teams.size()):
		if int(teams[i]) == 0:
			team0_idxs.append(i)
		else:
			team1_idxs.append(i)
	var avg_rating := func(idxs: Array[int]) -> float:
		var sum: int = 0
		for i in idxs:
			sum += int(recs[i].get("pvp_rating", _RatingMath.START_RATING))
		return float(sum) / float(idxs.size())
	var avg0: float = avg_rating.call(team0_idxs)
	var avg1: float = avg_rating.call(team1_idxs)
	var team0_won: bool = did_win  # team_assignments[0] is the host's team
	for i in team0_idxs:
		var r: int = int(recs[i].get("pvp_rating", _RatingMath.START_RATING))
		var g: int = int(recs[i].get("pvp_games", 0))
		recs[i]["pvp_rating"] = _RatingMath.updated(r, int(round(avg1)), 1.0 if team0_won else 0.0, g)
		recs[i]["pvp_games"] = g + 1
	for i in team1_idxs:
		var r: int = int(recs[i].get("pvp_rating", _RatingMath.START_RATING))
		var g: int = int(recs[i].get("pvp_games", 0))
		recs[i]["pvp_rating"] = _RatingMath.updated(r, int(round(avg0)), 0.0 if team0_won else 1.0, g)
		recs[i]["pvp_games"] = g + 1
	for i in range(tokens.size()):
		st.update_member(tokens[i], recs[i])
	SessionStore.mark_dirty()


# ── GID-102 (TID-373): Ranked UI & leaderboard ────────────────────────────────

## Host: push the current leaderboard to one peer (target_peer == 0 broadcasts to all).
func _broadcast_leaderboard(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var rows: Array = st.get_leaderboard(20)
	# Update the host's own cache too so its roster badge + overlay stay in sync.
	_leaderboard_rows = rows
	if target_peer == 0:
		_net_sync.rpc("recv_leaderboard", rows)
	else:
		_net_sync.rpc_id(target_peer, "recv_leaderboard", rows)
	_refresh_coop_roster()
	if _leaderboard_overlay != null and is_instance_valid(_leaderboard_overlay) \
			and _leaderboard_overlay.has_method("refresh_rows"):
		_leaderboard_overlay.refresh_rows(_leaderboard_rows)


## Any peer: receive a leaderboard snapshot (initial push, post-duel update, or an
## on-demand refresh reply) and refresh the roster badges + open overlay if any.
func _on_leaderboard_received(rows: Array) -> void:
	_leaderboard_rows = rows
	_refresh_coop_roster()
	if _leaderboard_overlay != null and is_instance_valid(_leaderboard_overlay) \
			and _leaderboard_overlay.has_method("refresh_rows"):
		_leaderboard_overlay.refresh_rows(_leaderboard_rows)


## Host: a client asked for a fresh leaderboard snapshot (e.g. opening the panel).
func _on_leaderboard_request_submitted(sender: int) -> void:
	_broadcast_leaderboard(sender)


## token -> row lookup derived from the cache, for the roster badge + overlay.
func _leaderboard_lookup_by_token() -> Dictionary:
	var out: Dictionary = {}
	for row in _leaderboard_rows:
		if row is Dictionary:
			out[str((row as Dictionary).get("token", ""))] = row
	return out


## Returns "1234" for a cached rating or "—" if the token isn't in the cache yet
## (e.g. before the first leaderboard snapshot arrives).
func _rating_badge_for_token(token: String) -> String:
	if token == "":
		return "—"
	var lookup: Dictionary = _leaderboard_lookup_by_token()
	if not lookup.has(token):
		return "—"
	return str(int((lookup[token] as Dictionary).get("rating", _RatingMath.START_RATING)))


## Opens (or closes, if already open) the leaderboard overlay. Requests a fresh
## snapshot from the host on open. HUD button + mobile/desktop parity (TID-373).
func _toggle_leaderboard_overlay() -> void:
	if _leaderboard_overlay != null and is_instance_valid(_leaderboard_overlay):
		_leaderboard_overlay.queue_free()
		_leaderboard_overlay = null
		return
	_leaderboard_overlay = _LeaderboardOverlay.new()
	add_child(_leaderboard_overlay)
	_leaderboard_overlay.closed.connect(func() -> void: _leaderboard_overlay = null)
	_leaderboard_overlay.refresh_rows(_leaderboard_rows)
	if NetworkManager.is_host():
		_broadcast_leaderboard()
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_leaderboard_request")
	if _leaderboard_overlay.has_method("refresh_pve_rows"):
		_leaderboard_overlay.refresh_pve_rows(_pve_leaderboards)
	if NetworkManager.is_host():
		_broadcast_pve_leaderboards()
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_pve_leaderboard_request")


# ── GID-102 (TID-379): PvE leaderboards — Spire + co-op boss clears ──────────
# Distinct symbol/RPC names from the TID-373 ranked-rating board above
# (recv_leaderboard/submit_leaderboard_request/_broadcast_leaderboard/etc.) —
# these never touch pvp_rating. Reuses the LeaderboardOverlay's tabs (extended
# by this task) rather than a second panel, per the task's "unified Rankings"
# guidance.

## Endless Spire is single-player; only submit a session-scoped board entry when a
## co-op session is actually active (per task notes — a Spire run can happen with no
## co-op session running at all, in which case this is purely a local result).
## Offline/no-session best is intentionally NOT duplicated into MpProfile: the
## fully-offline case is already covered by SaveManager.spire_best_floor (the "New
## Record!" badge on RunSummaryScene reads that field already) — adding a second
## local-best store here would just be a second source of truth for the same fact.
func _on_spire_run_ended_leaderboard(stats: Dictionary) -> void:
	if not NetworkManager.is_active():
		return
	var floors_cleared: int = int(stats.get("floors_cleared", 0))
	if floors_cleared <= 0:
		return
	_submit_pve_score("spire", floors_cleared)

## Co-op boss clear: submit on a party win while a co-op session is active. The
## "value" recorded is the party size at the moment the battle ended (peers + self) —
## a v1 simplification. Neither fastest-clear timing nor the scaled boss tier are
## threaded from BattleScene back to WorldScene today (see BID-027), so party size is
## the only robust, always-available proxy of "how tough a clear this was" without
## inventing new cross-battle plumbing for this task.
func _on_coop_pve_battle_ended_leaderboard(did_win: bool) -> void:
	if not did_win or not NetworkManager.is_active():
		return
	var party_size: int = multiplayer.get_peers().size() + 1
	_submit_pve_score("coop_clears", party_size)

## Route a PvE score to the authority: host records directly via SessionStore; a
## client sends the new submit RPC. board is "spire" or "coop_clears".
func _submit_pve_score(board: String, value: int) -> void:
	if NetworkManager.is_host():
		if not SessionStore.is_open():
			return
		var st = SessionStore.get_state()
		if st == null:
			return
		var token: String = MpProfile.get_token()
		st.record_pve_score(board, token, MpProfile.get_display_name(), value,
			SceneManager.save_manager.days_elapsed)
		SessionStore.mark_dirty()
		_broadcast_pve_leaderboards()
	elif _net_sync != null:
		_net_sync.rpc_id(1, "submit_pve_leaderboard_score", board, value)

## Host: a client submitted a PvE score — record it (using the sender's already-known
## session token) and broadcast the refreshed snapshot to everyone.
func _on_pve_leaderboard_score_submitted(sender: int, board: String, value: int) -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var token: String = str(_session_token_by_peer.get(sender, ""))
	if token == "":
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var rec: Dictionary = st.get_member(token)
	var member_name: String = str(rec.get("display_name", "Player"))
	st.record_pve_score(board, token, member_name, value, SceneManager.save_manager.days_elapsed)
	SessionStore.mark_dirty()
	_broadcast_pve_leaderboards()

## Host: push the current {spire, coop_clears} PvE snapshot to one peer (0 = all).
func _broadcast_pve_leaderboards(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var snapshot: Dictionary = st.get_pve_leaderboards_snapshot()
	_pve_leaderboards = snapshot
	if target_peer == 0:
		_net_sync.rpc("recv_pve_leaderboards", snapshot)
	else:
		_net_sync.rpc_id(target_peer, "recv_pve_leaderboards", snapshot)
	if _leaderboard_overlay != null and is_instance_valid(_leaderboard_overlay) \
			and _leaderboard_overlay.has_method("refresh_pve_rows"):
		_leaderboard_overlay.refresh_pve_rows(_pve_leaderboards)

## Any peer: receive a PvE leaderboard snapshot (late-join, post-update, or an
## on-demand refresh reply) and refresh the overlay if open.
func _on_pve_leaderboards_received(snapshot: Dictionary) -> void:
	_pve_leaderboards = snapshot
	if _leaderboard_overlay != null and is_instance_valid(_leaderboard_overlay) \
			and _leaderboard_overlay.has_method("refresh_pve_rows"):
		_leaderboard_overlay.refresh_pve_rows(_pve_leaderboards)

## Host: a client asked for a fresh PvE leaderboard snapshot (e.g. switching tabs).
func _on_pve_leaderboard_request_submitted(sender: int) -> void:
	_broadcast_pve_leaderboards(sender)


# ── TID-369: Shared party bounties ────────────────────────────────────────────

func _setup_party_bounties() -> void:
	if not NetworkManager.is_host():
		return
	if not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	const _BountyGen = preload("res://game_logic/BountyGen.gd")
	if (st.party_bounties as Array).is_empty():
		var day_idx: int = SceneManager.save_manager.days_elapsed
		var raw: Array[Dictionary] = _BountyGen.generate_daily(WORLD_SEED, day_idx)
		var bounties: Array = []
		for b: Dictionary in raw:
			var pb: Dictionary = b.duplicate(true)
			pb["progress"] = 0
			pb["contributors"] = []
			pb["completed"] = false
			bounties.append(pb)
		st.party_bounties = bounties
		SessionStore.mark_dirty()


func _build_party_bounty_panel() -> void:
	if _party_bounty_panel != null and is_instance_valid(_party_bounty_panel):
		_refresh_party_bounty_panel()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var outer := PanelContainer.new()
	outer.name = "PartyBountyPanel"
	outer.position = Vector2(vp.x * 0.012, vp.y * 0.50)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.88)
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	outer.add_theme_stylebox_override("panel", style)
	_hud.add_child(outer)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.006))
	outer.add_child(vbox)
	_party_bounty_panel = vbox
	_refresh_party_bounty_panel()


func _refresh_party_bounty_panel() -> void:
	if _party_bounty_panel == null or not is_instance_valid(_party_bounty_panel):
		return
	for c in _party_bounty_panel.get_children():
		c.queue_free()
	var vh: float = get_viewport().get_visible_rect().size.y
	var title := Label.new()
	title.text = "Party Bounties"
	title.add_theme_font_size_override("font_size", int(vh * 0.020))
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_party_bounty_panel.add_child(title)
	if NetworkManager.is_host() and SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null:
			for b: Variant in (st.party_bounties as Array):
				if b is Dictionary:
					_add_bounty_row(b as Dictionary)


func _add_bounty_row(bd: Dictionary) -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	var lbl := Label.new()
	var cnt: int = int(bd.get("count", 1))
	var prog: int = int(bd.get("progress", 0))
	var done: bool = bool(bd.get("completed", false))
	lbl.text = "%s: %d/%d%s" % [
		str(bd.get("type", "?")), prog, cnt,
		" [done]" if done else ""]
	lbl.add_theme_font_size_override("font_size", int(vh * 0.016))
	if done:
		lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_party_bounty_panel.add_child(lbl)


## Public: called by other WorldScene subsystems (battle won, chest opened) to
## contribute party bounty progress in co-op. Works like
## SaveManager.increment_bounty_progress but for the shared party list.
func submit_party_bounty_progress(bounty_type: String, match_data: Dictionary) -> void:
	if not _coop_active or _net_sync == null:
		return
	if NetworkManager.is_host():
		_on_party_bounty_progress_submitted(multiplayer.get_unique_id(), bounty_type, match_data)
	else:
		_net_sync.rpc_id(1, "submit_party_bounty_progress", bounty_type, match_data)


func _on_party_bounty_progress_submitted(sender: int, bounty_type: String, match_data: Dictionary) -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var token: String = str(_session_token_by_peer.get(sender,
		MpProfile.get_token() if sender == multiplayer.get_unique_id() else ""))
	for i: int in range((st.party_bounties as Array).size()):
		var b: Variant = (st.party_bounties as Array)[i]
		if not (b is Dictionary):
			continue
		var bd: Dictionary = b as Dictionary
		if bool(bd.get("completed", false)):
			continue
		if str(bd.get("type", "")) != bounty_type:
			continue
		var target: String = str(bd.get("target", ""))
		var matches: bool = false
		match bounty_type:
			"defeat_enemy_type":
				matches = str(match_data.get("enemy_type", "")) == target
			"defeat_in_biome":
				matches = str(match_data.get("biome", "")) == target
			"open_chests":
				matches = true
		if not matches:
			continue
		var progress: int = int(bd.get("progress", 0))
		progress += 1
		bd["progress"] = progress
		var contributors: Array = bd.get("contributors", []) as Array
		if not contributors.has(token):
			contributors.append(token)
		bd["contributors"] = contributors
		var count: int = int(bd.get("count", 1))
		if progress >= count:
			bd["completed"] = true
			SceneManager.save_manager.add_coins(int(bd.get("reward", 0)))
		(st.party_bounties as Array)[i] = bd
		SessionStore.mark_dirty()
		var update_payload: Dictionary = {
			"bounty_id": str(bd.get("id", "")),
			"progress": progress,
			"count": count,
			"completed": bool(bd.get("completed", false)),
		}
		if _net_sync != null:
			_net_sync.rpc("recv_party_bounty_update", update_payload)
		_refresh_party_bounty_panel()
		break


func _on_party_bounty_update_received(payload: Dictionary) -> void:
	# Clients update their local HUD row. The snapshot drives initial state;
	# incremental updates patch one row at a time.
	_refresh_party_bounty_panel()


func _on_party_bounties_snapshot_received(bounties: Array) -> void:
	# Client: received full party bounty list from host on join.
	if _party_bounty_panel == null or not is_instance_valid(_party_bounty_panel):
		# Build panel first time
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var vh: float = vp.y
		var outer := PanelContainer.new()
		outer.name = "PartyBountyPanel"
		outer.position = Vector2(vp.x * 0.012, vp.y * 0.50)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.08, 0.88)
		style.corner_radius_top_left    = 6
		style.corner_radius_top_right   = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		outer.add_theme_stylebox_override("panel", style)
		_hud.add_child(outer)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(vh * 0.006))
		outer.add_child(vbox)
		_party_bounty_panel = vbox
	# Populate from snapshot
	for c in _party_bounty_panel.get_children():
		c.queue_free()
	var vh: float = get_viewport().get_visible_rect().size.y
	var title := Label.new()
	title.text = "Party Bounties"
	title.add_theme_font_size_override("font_size", int(vh * 0.020))
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_party_bounty_panel.add_child(title)
	for b: Variant in bounties:
		if b is Dictionary:
			_add_bounty_row(b as Dictionary)


# ── Draft duels — sealed-deck PvP (GID-104 / TID-385) ─────────────────────────
# Deterministic shared-seed model: the challenger generates one seed; both peers
# derive the IDENTICAL 1-of-3 pick rounds locally (DraftDuelGen.generate_rounds),
# so no per-pick relay is needed — each side picks independently and only the two
# finished TRANSIENT decks cross the wire (submit_draft_duel_deck), once each.
# Drafted decks live only in the resulting duel's GameState; they are never
# written to owned_cards, SaveManager, or SessionState. Always casual: never
# ranked (fair-format ratings would need their own ladder), never wagered.
# Everything here is guarded by the co-op HUD entry points (_setup_coop), so
# single-player never reaches any of it.

## Creates the hidden "Draft Duel" HUD button (mobile + desktop parity — a
## Button.pressed tap/click target, no keybind). Sits below the ranked toggle.
func _ensure_draft_duel_button() -> void:
	if _draft_duel_btn != null and is_instance_valid(_draft_duel_btn):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_draft_duel_btn = Button.new()
	_draft_duel_btn.text = "Draft Duel"
	_draft_duel_btn.tooltip_text = "Sealed-deck duel: both players draft %d cards from identical seeded packs. No collection advantage; drafted cards last one duel." % _DraftDuelGen.NUM_ROUNDS
	_draft_duel_btn.custom_minimum_size = Vector2(vp.y * 0.20, vp.y * 0.05)
	_draft_duel_btn.add_theme_font_size_override("font_size", int(vp.y * 0.020))
	_draft_duel_btn.position = Vector2((vp.x - vp.y * 0.20) * 0.5, vp.y * 0.935)
	_draft_duel_btn.hide()
	_draft_duel_btn.pressed.connect(_request_draft_duel)
	_hud.add_child(_draft_duel_btn)

## Shows/hides the draft-duel button. Piggybacks on the proximity result
## (_challenge_target_peer) computed by _update_challenge_proximity, which runs
## immediately before this in _process. Hidden while any challenge/draft is
## pending, and on dedicated servers (draft routing is listen-server only in v1).
func _update_draft_duel_proximity() -> void:
	if _draft_duel_btn == null or not is_instance_valid(_draft_duel_btn):
		return
	if _draft_peer != -1 or _pending_draft_from != -1 or _pending_challenge_from != -1 \
			or _session_dedicated or SceneManager._state != SceneManager.State.WORLD:
		_draft_duel_btn.hide()
		return
	_draft_duel_btn.visible = _challenge_target_peer != -1

## Send a draft-duel challenge to the nearby peer, carrying a freshly rolled seed.
## No DECK_MIN gate — a draft duel needs no collection at all (that's the point).
func _request_draft_duel() -> void:
	if _challenge_target_peer == -1 or _net_sync == null or _draft_peer != -1:
		return
	if _session_dedicated:
		_show_tip("Draft duels aren't available on dedicated servers yet.")
		return
	var seed_val: int = randi()
	_draft_peer = _challenge_target_peer
	_draft_seed = seed_val
	_net_sync.rpc_id(_draft_peer, "request_draft_duel", _DraftDuelGen.encode_seed(seed_val))
	_show_tip("Draft duel challenge sent…")

## Incoming draft challenge — show an Accept/Decline prompt (auto-decline if busy
## so the challenger isn't left hanging on a peer already in another handshake).
func _on_draft_duel_requested(from_id: int, payload: Dictionary) -> void:
	if _pending_challenge_from != -1 or _pending_draft_from != -1 or _draft_peer != -1:
		if _net_sync != null:
			_net_sync.rpc_id(from_id, "respond_draft_duel", false, {})
		return
	var decoded: Dictionary = _DraftDuelGen.decode_seed(payload)
	if not bool(decoded["valid"]):
		return
	_pending_draft_from = from_id
	_pending_draft_seed = int(decoded["seed"])
	_show_draft_accept_panel(from_id)

## Challenger learns the response. On accept, the echoed seed payload is used
## (defensively falling back to the seed we sent) and both peers start drafting.
func _on_draft_duel_responded(from_id: int, accepted: bool, payload: Dictionary) -> void:
	if from_id != _draft_peer or _draft_picking:
		return
	if not accepted:
		_show_tip("Draft duel declined.")
		_draft_peer = -1
		_draft_seed = 0
		return
	var decoded: Dictionary = _DraftDuelGen.decode_seed(payload)
	var seed_val: int = int(decoded["seed"]) if bool(decoded["valid"]) else _draft_seed
	_start_draft(from_id, seed_val)

func _show_draft_accept_panel(from_id: int) -> void:
	if _draft_accept_panel != null and is_instance_valid(_draft_accept_panel):
		_draft_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 180
	add_child(layer)
	_draft_accept_panel = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vp.y * 0.025))
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "A player challenges you to a DRAFT DUEL!\nBoth of you draft %d cards from identical sealed packs." % _DraftDuelGen.NUM_ROUNDS
	lbl.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.6, 0.9, 1.0)
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vp.y * 0.03))
	vbox.add_child(row)

	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(vp.y * 0.2, vp.y * 0.07)
	accept_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	accept_btn.pressed.connect(_accept_draft_duel.bind(from_id))
	row.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(vp.y * 0.2, vp.y * 0.07)
	decline_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	decline_btn.pressed.connect(_decline_draft_duel.bind(from_id))
	row.add_child(decline_btn)

func _dismiss_draft_panel() -> void:
	if _draft_accept_panel != null and is_instance_valid(_draft_accept_panel):
		_draft_accept_panel.queue_free()
	_draft_accept_panel = null

func _accept_draft_duel(from_id: int) -> void:
	_dismiss_draft_panel()
	var seed_val: int = _pending_draft_seed
	_pending_draft_from = -1
	_pending_draft_seed = 0
	if _net_sync != null:
		_net_sync.rpc_id(from_id, "respond_draft_duel", true, _DraftDuelGen.encode_seed(seed_val))
	_start_draft(from_id, seed_val)

func _decline_draft_duel(from_id: int) -> void:
	_dismiss_draft_panel()
	_pending_draft_from = -1
	_pending_draft_seed = 0
	if _net_sync != null:
		_net_sync.rpc_id(from_id, "respond_draft_duel", false, {})

## Both peers: open the local pick overlay with the agreed shared seed. From here
## on there is zero network traffic until a peer finishes its last pick.
func _start_draft(peer_id: int, seed_val: int) -> void:
	_draft_peer = peer_id
	_draft_seed = seed_val
	_draft_picking = true
	_draft_local_deck = []
	_draft_opp_deck = []
	_draft_local_done = false
	_draft_opp_done = false
	# Shared bookkeeping with the normal challenge path: the host's battle-end
	# champion-record path resolves the opponent via _challenge_target_peer.
	_challenge_target_peer = peer_id
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
		_ranked_toggle_btn.hide()
	if _draft_duel_btn != null and is_instance_valid(_draft_duel_btn):
		_draft_duel_btn.hide()
	var layer := CanvasLayer.new()
	layer.layer = 190
	add_child(layer)
	_draft_picker_layer = layer
	var picker := _DraftDuelPickScene.new()
	layer.add_child(picker)
	picker.draft_finished.connect(_on_local_draft_finished)
	_draft_picker = picker
	# setup() can finish synchronously (empty card registry edge) and cascade into
	# _maybe_enter_draft_duel → _free_draft_picker, so it must run after the
	# member references above are in place.
	picker.setup(seed_val, MpProfile.get_token())

func _free_draft_picker() -> void:
	if _draft_picker_layer != null and is_instance_valid(_draft_picker_layer):
		_draft_picker_layer.queue_free()
	_draft_picker_layer = null
	_draft_picker = null

## Local draft complete: send my transient deck to the opponent, then start the
## duel if theirs already arrived (whichever peer finishes second triggers entry).
func _on_local_draft_finished(deck: Array) -> void:
	_draft_local_deck = deck
	_draft_local_done = true
	if _net_sync != null and _draft_peer != -1:
		_net_sync.rpc_id(_draft_peer, "submit_draft_duel_deck", deck)
	_maybe_enter_draft_duel()

func _on_draft_duel_deck_submitted(from_id: int, deck: Array) -> void:
	if from_id != _draft_peer:
		return
	_draft_opp_deck = deck
	_draft_opp_done = true
	_maybe_enter_draft_duel()

## Both decks ready → enter the duel. Mirrors _enter_pvp (spectator broadcast +
## opponent token), but passes the local drafted deck as the override so the
## battle never reads the host's persisted collection. Never ranked, no ante.
func _maybe_enter_draft_duel() -> void:
	if not (_draft_local_done and _draft_opp_done):
		return
	_free_draft_picker()
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	_pvp_ranked = false
	if NetworkManager.is_host() and _net_sync != null:
		var my_id: int = multiplayer.get_unique_id()
		_pvp_ante_peer0 = my_id
		_pvp_ante_peer1 = _draft_peer
		for pid in multiplayer.get_peers():
			var p: int = int(pid)
			if p != _draft_peer:
				_net_sync.rpc_id(p, "recv_pvp_active", true, my_id, _draft_peer)
	var opp_token: String = str(_session_token_by_peer.get(_draft_peer, ""))
	var opp_deck: Array = _draft_opp_deck
	var my_deck: Array = _draft_local_deck
	_reset_draft_state()
	SceneManager.enter_pvp_battle(local_idx, opp_deck, 0, opp_token, false, my_deck)

func _reset_draft_state() -> void:
	_draft_peer = -1
	_draft_seed = 0
	_draft_picking = false
	_draft_local_deck = []
	_draft_opp_deck = []
	_draft_local_done = false
	_draft_opp_done = false

## Abort hooks: called from _on_coop_peer_disconnected / _on_coop_session_ended.
func _abort_draft_duel_for_peer(pid: int) -> void:
	if _draft_peer != -1 and pid == _draft_peer:
		_abort_draft_duel("Draft duel cancelled — opponent disconnected.")
	elif _pending_draft_from != -1 and pid == _pending_draft_from:
		_dismiss_draft_panel()
		_pending_draft_from = -1
		_pending_draft_seed = 0

func _abort_draft_duel(reason: String = "") -> void:
	if _draft_peer == -1 and _pending_draft_from == -1 and _draft_picker == null:
		return
	_free_draft_picker()
	_dismiss_draft_panel()
	_pending_draft_from = -1
	_pending_draft_seed = 0
	_reset_draft_state()
	if reason != "":
		_show_tip(reason)
# ── Session tournaments (GID-104 / TID-386) ───────────────────────────────────
# Host-run round-robin bracket for 3-4 session players. The host is the
# authority: it schedules matches one at a time, plays its own matches through
# the normal enter_pvp_battle flow, referees client-vs-client matches through
# the GID-097 enter_pvp_referee flow, auto-spectates every non-combatant, and
# pays the pot to the bracket winner. Pure scheduling/wire logic lives in
# game_logic/net/TournamentSync.gd; everything here is guarded end-to-end by
# _tournament_active / NetworkManager.is_active() so single-player and normal
# co-op PvP are untouched.

func _ensure_tournament_button() -> void:
	if _tournament_btn != null and is_instance_valid(_tournament_btn):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_tournament_btn = Button.new()
	_tournament_btn.text = "Tournament"
	_tournament_btn.custom_minimum_size = Vector2(vp.y * 0.28, vp.y * 0.07)
	_tournament_btn.add_theme_font_size_override("font_size", int(vp.y * 0.026))
	_tournament_btn.position = Vector2((vp.x - vp.y * 0.28) * 0.5, vp.y * 0.63)
	_tournament_btn.hide()
	_tournament_btn.pressed.connect(_start_tournament)
	_hud.add_child(_tournament_btn)


## Shows the tournament button only for the host with 2-3 connected clients
## (3-4 total players). Mirrors _update_team_duel_button_visibility.
func _update_tournament_button_visibility() -> void:
	if _tournament_btn == null or not is_instance_valid(_tournament_btn):
		return
	if not NetworkManager.is_host() or NetworkManager.is_dedicated_server() \
			or SceneManager._state != SceneManager.State.WORLD or _tournament_active:
		_tournament_btn.hide()
		return
	_tournament_btn.visible = multiplayer.get_peers().size() >= 2 and _pending_challenge_from == -1


## Host: builds the bracket from every connected peer (host + all clients),
## deducts the flat ante from every participant (host locally; clients via
## notify_tournament_start doing the same on their side — the existing
## ante-wager precedent), broadcasts the bracket, and schedules match 1.
func _start_tournament() -> void:
	if not NetworkManager.is_host() or _net_sync == null or _tournament_active:
		return
	var clients: Array = multiplayer.get_peers()
	if clients.size() < 2:
		_show_tip("Need 3-4 players for a tournament.")
		return
	clients.sort()
	var host_id: int = multiplayer.get_unique_id()
	var peer_ids: Array[int] = [host_id]
	for pid in clients:
		peer_ids.append(int(pid))
	var tokens: Array = []
	var names: Array = []
	var decks: Array = []
	for pid in peer_ids:
		var token: String = MpProfile.get_token() if pid == host_id \
				else str(_session_token_by_peer.get(pid, ""))
		if token == "":
			_show_tip("A player's identity isn't synced yet — try again shortly.")
			return
		var deck: Array = _team_deck_for_peer(pid)
		if deck.size() < IsoConst.DECK_MIN:
			_show_tip("%s's deck is too small to duel." % _display_name_for_token(token))
			return
		tokens.append(token)
		names.append(_display_name_for_token(token))
		decks.append(deck)
	if SceneManager.save_manager.coins < TOURNAMENT_ANTE_COINS:
		_show_tip("Not enough coins for the ante (%d)." % TOURNAMENT_ANTE_COINS)
		return
	var bracket: Dictionary = _TournamentSync.new_bracket(tokens, names, TOURNAMENT_ANTE_COINS)
	if bracket.is_empty():
		_show_tip("Tournaments support 3-4 players.")
		return
	SceneManager.save_manager.add_coins(-TOURNAMENT_ANTE_COINS)
	_tournament_active = true
	_tournament_bracket = bracket
	_tournament_peer_ids = peer_ids
	_tournament_tokens.assign(tokens)
	_tournament_decks = decks
	_tournament_ante = TOURNAMENT_ANTE_COINS
	_tournament_pending_result = {}
	if _tournament_btn != null and is_instance_valid(_tournament_btn):
		_tournament_btn.hide()
	for pid in peer_ids:
		if pid != host_id:
			_net_sync.rpc_id(pid, "notify_tournament_start",
				_TournamentSync.encode_bracket(bracket), TOURNAMENT_ANTE_COINS)
	_build_tournament_panel()
	GameBus.hud_message_requested.emit("Tournament started — %d matches. Pot: %d coins." % [
		(bracket.get("matches", []) as Array).size(), int(bracket.get("pot", 0))])
	# Brief pause before match 1 so everyone can read the bracket panel first.
	_tournament_match_countdown = 3.0


## Host: launches the bracket's current match. The host plays its own matches
## (canonical GameState idx 0, the enter_pvp_battle host path); a match between
## two clients runs through the GID-097 referee path with the host arbitrating.
## Every peer not in the match is told to auto-spectate.
func _start_current_tournament_match() -> void:
	if not NetworkManager.is_host() or _net_sync == null or not _tournament_active:
		return
	var m: Dictionary = _TournamentSync.get_current_match(_tournament_bracket)
	if m.is_empty():
		return
	var pa: int = int(m.get("a", -1))
	var pb: int = int(m.get("b", -1))
	if pa < 0 or pb < 0 or pa >= _tournament_peer_ids.size() or pb >= _tournament_peer_ids.size():
		return
	var host_id: int = multiplayer.get_unique_id()
	var peer_a: int = _tournament_peer_ids[pa]
	var peer_b: int = _tournament_peer_ids[pb]
	var deck_a: Array = _tournament_decks[pa]
	var deck_b: Array = _tournament_decks[pb]
	_net_sync.rpc("recv_tournament_update", _TournamentSync.encode_bracket(_tournament_bracket))
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	if _tournament_btn != null and is_instance_valid(_tournament_btn):
		_tournament_btn.hide()
	# Duel-active + auto-spectate broadcasts to everyone not in this match
	# (reuses the TID-367 spectate plumbing; _enter_tree clears it after the match
	# via the _pvp_ended_pending_broadcast pattern).
	_pvp_ante_peer0 = peer_a
	_pvp_ante_peer1 = peer_b
	for pid in multiplayer.get_peers():
		var p: int = int(pid)
		if p == peer_a or p == peer_b:
			continue
		_net_sync.rpc_id(p, "recv_pvp_active", true, peer_a, peer_b)
		_net_sync.rpc_id(p, "notify_tournament_spectate")
	var names: Array = _tournament_bracket.get("names", [])
	if pa < names.size() and pb < names.size():
		GameBus.hud_message_requested.emit("Tournament match: %s vs %s" % [str(names[pa]), str(names[pb])])
	if peer_a == host_id or peer_b == host_id:
		# The host is a combatant — canonical idx 0 is always the host on this path.
		_tournament_current_is_host_match = true
		var host_participant: int = pa if peer_a == host_id else pb
		var opp_participant: int = pb if peer_a == host_id else pa
		var opp_peer: int = _tournament_peer_ids[opp_participant]
		var opp_deck: Array = _tournament_decks[opp_participant]
		var host_deck: Array = _tournament_decks[host_participant]
		_tournament_canonical_to_participant = {0: host_participant, 1: opp_participant}
		_net_sync.rpc_id(opp_peer, "notify_pvp_start", 1, host_deck)
		var opp_token: String = str(_session_token_by_peer.get(opp_peer, ""))
		SceneManager.enter_pvp_battle(0, opp_deck, 0, opp_token, false)
	else:
		# Two clients play; the listen-server host referees (GID-097 path,
		# _local_player_idx = -1) — the winner arrives via pvp_referee_match_ended.
		_tournament_current_is_host_match = false
		_tournament_canonical_to_participant = {0: pa, 1: pb}
		_net_sync.rpc_id(peer_a, "notify_pvp_start", 0, deck_b)
		_net_sync.rpc_id(peer_b, "notify_pvp_start", 1, deck_a)
		SceneManager.enter_pvp_referee(deck_a, deck_b, peer_a, peer_b,
			str(_session_token_by_peer.get(peer_a, "")),
			str(_session_token_by_peer.get(peer_b, "")))


## All peers (routed from _on_pvp_battle_ended_coop's _tournament_active guard):
## a tournament match this peer FOUGHT in just ended. The host captures the
## winner for the bracket advance; every peer re-arms the duel-clear broadcast
## exactly like the normal PvP path it replaced.
func _on_tournament_pvp_ended(did_win: bool) -> void:
	_pvp_ranked = false
	_pvp_ended_pending_broadcast = true
	if not NetworkManager.is_host():
		return
	if _tournament_current_is_host_match:
		var canonical: int = 0 if did_win else 1
		var participant: int = int(_tournament_canonical_to_participant.get(canonical, -1))
		if participant >= 0:
			_tournament_pending_result = {"winner_participant_idx": participant}


## Host: a referee'd (client-vs-client) tournament match ended — the winner's
## canonical GameState index arrives via the dedicated GID-104 signal because
## pvp_battle_ended's bool can't express it for a non-participant. The GID-097
## dedicated-server relay also fires this signal, but _tournament_active is
## never true there, so it stays inert outside tournaments.
func _on_pvp_referee_match_ended(winner_idx: int) -> void:
	if not _tournament_active or not NetworkManager.is_host() or _tournament_current_is_host_match:
		return
	var participant: int = int(_tournament_canonical_to_participant.get(winner_idx, -1))
	if participant >= 0:
		_tournament_pending_result = {"winner_participant_idx": participant}


## Host, from _process once WorldScene is back in the tree (a match result can
## only be applied here — during the battle this scene is detached and _net_sync
## is freed): drains the pending result, advances + broadcasts the bracket, and
## either schedules the next match (short countdown so peers get back to the
## world and read the panel) or finishes the tournament.
func _tick_tournament(delta: float) -> void:
	if not _tournament_active or not NetworkManager.is_host():
		return
	if not _tournament_pending_result.is_empty():
		var w: int = int(_tournament_pending_result.get("winner_participant_idx", -1))
		_tournament_pending_result = {}
		if w >= 0:
			_tournament_bracket = _TournamentSync.record_match_result(_tournament_bracket, w)
			if _net_sync != null:
				_net_sync.rpc("recv_tournament_update", _TournamentSync.encode_bracket(_tournament_bracket))
			_refresh_tournament_panel()
			if _TournamentSync.is_finished(_tournament_bracket):
				_finish_tournament()
				return
			var names: Array = _tournament_bracket.get("names", [])
			if w < names.size():
				GameBus.hud_message_requested.emit("%s wins the match!" % str(names[w]))
			_tournament_match_countdown = 4.0
		return
	if _tournament_match_countdown > 0.0:
		_tournament_match_countdown -= delta
		if _tournament_match_countdown <= 0.0:
			_start_current_tournament_match()


## Host: pays the pot to the bracket winner — locally for the host itself,
## otherwise straight into the winner's session member record (the
## _grant_chest_loot_to_token direct-write pattern). Clients learn the outcome
## from the finished bracket broadcast in _tick_tournament.
func _finish_tournament() -> void:
	var w: int = int(_tournament_bracket.get("winner_idx", -1))
	var players: Array = _tournament_bracket.get("players", [])
	var names: Array = _tournament_bracket.get("names", [])
	var pot: int = int(_tournament_bracket.get("pot", 0))
	if w >= 0 and w < players.size():
		var token: String = str(players[w])
		var wname: String = str(names[w]) if w < names.size() else "?"
		if token == MpProfile.get_token():
			SceneManager.save_manager.add_coins(pot)
		elif SessionStore.is_open():
			var st = SessionStore.get_state()
			if st != null:
				var rec: Dictionary = st.get_member(token)
				if not rec.is_empty():
					rec["coins"] = int(rec.get("coins", 0)) + pot
					st.update_member(token, rec)
					SessionStore.mark_dirty()
		GameBus.hud_message_requested.emit("%s wins the tournament (+%d coins)!" % [wname, pot])
	_reset_tournament_state()
	_refresh_tournament_panel()


## Clears every host-side orchestration field. Keeps _tournament_bracket so the
## final standings stay on the panel — callers that need a blank panel (abort,
## session end) clear the bracket themselves.
func _reset_tournament_state() -> void:
	_tournament_active = false
	_tournament_peer_ids = []
	_tournament_tokens = []
	_tournament_decks = []
	_tournament_ante = 0
	_tournament_pending_result = {}
	_tournament_current_is_host_match = false
	_tournament_canonical_to_participant = {}
	_tournament_match_countdown = 0.0


## Client (notify_tournament_start): the host started a tournament that
## includes us — deduct our ante locally (existing ante-wager precedent) and
## build the bracket panel.
func _on_tournament_started(bracket: Dictionary, ante: int) -> void:
	if NetworkManager.is_host():
		return
	var b: Dictionary = _TournamentSync.decode_bracket(bracket)
	if (b.get("players", []) as Array).is_empty():
		return
	_tournament_active = true
	_tournament_bracket = b
	if ante > 0:
		SceneManager.save_manager.add_coins(-ante)
	_build_tournament_panel()
	GameBus.hud_message_requested.emit("Tournament started — ante %d coins. Pot: %d." % [
		ante, int(b.get("pot", 0))])


## Client (recv_tournament_update): bracket changed. An empty bracket means the
## host aborted (participant disconnect); a finished one carries the winner.
func _on_tournament_update_received(payload: Dictionary) -> void:
	if NetworkManager.is_host():
		return
	var b: Dictionary = _TournamentSync.decode_bracket(payload)
	if (b.get("players", []) as Array).is_empty():
		if _tournament_active:
			GameBus.hud_message_requested.emit("Tournament aborted.")
		_tournament_active = false
		_tournament_bracket = {}
		_refresh_tournament_panel()
		return
	_tournament_bracket = b
	if _TournamentSync.is_finished(b):
		_tournament_active = false
		var w: int = int(b.get("winner_idx", -1))
		var names: Array = b.get("names", [])
		if w >= 0 and w < names.size():
			GameBus.hud_message_requested.emit("%s wins the tournament (+%d coins)!" % [
				str(names[w]), int(b.get("pot", 0))])
	_build_tournament_panel()


## Client (notify_tournament_spectate): the host scheduled a match we're not in —
## auto-enter the spectator view (no manual Spectate press, unlike TID-367).
func _on_tournament_spectate_notified() -> void:
	if not _tournament_active or NetworkManager.is_dedicated_server():
		return
	SceneManager.enter_pvp_spectator()


## Bracket HUD panel (all peers) — mirrors _build_party_bounty_panel
## structurally; right side of the screen (bounties/roster/chat own the left).
func _build_tournament_panel() -> void:
	if _tournament_panel != null and is_instance_valid(_tournament_panel):
		_refresh_tournament_panel()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var outer := PanelContainer.new()
	outer.name = "TournamentPanel"
	outer.position = Vector2(vp.x * 0.76, vp.y * 0.34)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.88)
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	outer.add_theme_stylebox_override("panel", style)
	_hud.add_child(outer)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vp.y * 0.006))
	outer.add_child(vbox)
	_tournament_panel_outer = outer
	_tournament_panel = vbox
	_refresh_tournament_panel()


func _refresh_tournament_panel() -> void:
	if _tournament_panel == null or not is_instance_valid(_tournament_panel):
		return
	if (_tournament_bracket.get("players", []) as Array).is_empty():
		if _tournament_panel_outer != null and is_instance_valid(_tournament_panel_outer):
			_tournament_panel_outer.hide()
		return
	if _tournament_panel_outer != null and is_instance_valid(_tournament_panel_outer):
		_tournament_panel_outer.show()
	for c in _tournament_panel.get_children():
		c.queue_free()
	var vh: float = get_viewport().get_visible_rect().size.y
	var title := Label.new()
	title.text = "Tournament — Pot: %d" % int(_tournament_bracket.get("pot", 0))
	title.add_theme_font_size_override("font_size", int(vh * 0.020))
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_tournament_panel.add_child(title)
	var names: Array = _tournament_bracket.get("names", [])
	var matches: Array = _tournament_bracket.get("matches", [])
	var cur: int = int(_tournament_bracket.get("current_match", 0))
	var finished: bool = bool(_tournament_bracket.get("finished", false))
	for i in range(matches.size()):
		var mv: Variant = matches[i]
		if not (mv is Dictionary):
			continue
		var md: Dictionary = mv
		var a: int = int(md.get("a", -1))
		var b: int = int(md.get("b", -1))
		var name_a: String = str(names[a]) if a >= 0 and a < names.size() else "?"
		var name_b: String = str(names[b]) if b >= 0 and b < names.size() else "?"
		var lbl := Label.new()
		if bool(md.get("done", false)):
			var w: int = int(md.get("winner", -1))
			var wname: String = str(names[w]) if w >= 0 and w < names.size() else "?"
			lbl.text = "%s def. %s" % [wname, name_b if w == a else name_a]
			lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			lbl.text = "%s vs %s" % [name_a, name_b]
			if i == cur and not finished:
				lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		lbl.add_theme_font_size_override("font_size", int(vh * 0.016))
		_tournament_panel.add_child(lbl)
	if finished:
		var wi: int = int(_tournament_bracket.get("winner_idx", -1))
		if wi >= 0 and wi < names.size():
			var win_lbl := Label.new()
			win_lbl.text = "Winner: %s" % str(names[wi])
			win_lbl.add_theme_font_size_override("font_size", int(vh * 0.018))
			win_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			_tournament_panel.add_child(win_lbl)
