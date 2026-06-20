extends Node

# Chunk size for infinite world streaming
const CHUNK_SIZE: int = 16

# Tile size
const TILE_SIZE: float = 2.0  # Godot world units per tile (was 32px in Java)

# Isometric display constants (kept for reference / editor use)
const ISO_TW: int = 64
const ISO_TH: int = 32
const ISO_HALF_W: int = 32
const ISO_HALF_H: int = 16
const WALL_FACE_H: float = 1.0    # world-unit height per wall level
const HILL_FACE_H: float = 1.0    # world-unit height per hill level
const WALL_FACE_TEX_H: int = 36

# Tile type constants
const TILE_GRASS: int = 0
const TILE_WALL: int = 1
const TILE_HILL: int = 2
const TILE_PATH: int = 3
const TILE_CRACKED: int = 4  # breakable wall used for dungeon secret room entrances

# Camera settings for isometric view
const CAM_ELEVATION_DEG: float = -35.264  # arcsin(tan(30°))
const CAM_AZIMUTH_DEG: float = -45.0
const CAM_ORTHO_SIZE: float = 15.0  # viewport height in world units

# Terrain rendering constants (shared by WorldScene named-map path and ChunkRenderer infinite-chunk path)
const HILL_PEAK_H: float = 1.5        # peak height for hill tiles (world units)
const HILL_CURVE_R: float = 3.5       # hill smoothstep radius (world units)
const TERRAIN_VDENSITY: int = 2       # mesh vertices per tile side
const ENTITY_VISIBILITY_END: float = 50.0  # LOD visibility range for world entities

# Entity interaction ranges (in Godot world units)
const AUTO_BATTLE_RANGE: float = 1.5   # enemy engages player at this distance
const INTERACT_RANGE: float = 1.5      # E key interaction range
const TRACKING_SPEED: float = 2.5      # enemy movement speed (world units/sec)

# Player physics
const PLAYER_SPEED: float = 6.0        # world units/sec
const PLAYER_RADIUS: float = 0.25      # collision radius

# Deck builder constraints
const DECK_MIN: int = 8
const DECK_MAX: int = 20

# Bag (inventory) starting capacity. Common cards stack (1 slot per type); rare+ each take 1 slot.
const BAG_SIZE_DEFAULT: int = 12

# Enemy respawn
const ENEMY_RESPAWN_DAYS: int = 3      # procedural enemies respawn after this many in-game days

# Card rarity tiers: stat_multiplier scales base attack/health; variance is the ± fraction applied as a random roll.
# rolled_stat = round(base_stat * multiplier * uniform(1 - variance, 1 + variance))
# Cost is never randomised regardless of rarity.
const RARITY_CONFIG: Dictionary = {
	"common":    {"multiplier": 1.0, "variance": 0.0,  "sell_gold": 5,   "scrap_essence": 5,  "craft_essence": 10},
	"rare":      {"multiplier": 1.3, "variance": 0.08, "sell_gold": 15,  "scrap_essence": 15, "craft_essence": 30},
	"epic":      {"multiplier": 1.7, "variance": 0.06, "sell_gold": 40,  "scrap_essence": 40, "craft_essence": 80},
	"legendary": {"multiplier": 2.4, "variance": 0.05, "sell_gold": 100, "scrap_essence": 80, "craft_essence": 200},
}
const RARITY_ORDER: Array[String] = ["common", "rare", "epic", "legendary"]

# Veterancy rank thresholds. Index 0 = rank 1, index 1 = rank 2, index 2 = rank 3.
# Rank is OR-based: earned when kills >= kills_threshold OR battles_survived >= battles_threshold.
# hp_bonus and atk_bonus are cumulative totals granted at that rank (not per-rank increments).
const VETERANCY_RANKS: Array = [
	{"kills_threshold": 5,  "battles_threshold": 10, "hp_bonus": 1, "atk_bonus": 0, "title": "the Seasoned"},
	{"kills_threshold": 15, "battles_threshold": 25, "hp_bonus": 2, "atk_bonus": 1, "title": "the Veteran"},
	{"kills_threshold": 40, "battles_threshold": 60, "hp_bonus": 3, "atk_bonus": 2, "title": "the Legendary"},
]

func tile_to_world(tx: int, tz: int) -> Vector3:
	return Vector3(tx * TILE_SIZE, 0.0, tz * TILE_SIZE)

func world_to_tile(wx: float, wz: float) -> Vector2i:
	return Vector2i(int(wx / TILE_SIZE), int(wz / TILE_SIZE))
