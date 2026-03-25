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
const HILL_FACE_H: float = 1.2    # world-unit height per hill level
const WALL_FACE_TEX_H: int = 36

# Tile type constants
const TILE_GRASS: int = 0
const TILE_WALL: int = 1
const TILE_HILL: int = 2

# Camera settings for isometric view
const CAM_ELEVATION_DEG: float = -35.264  # arcsin(tan(30°))
const CAM_AZIMUTH_DEG: float = -45.0
const CAM_ORTHO_SIZE: float = 15.0  # viewport height in world units

# Entity interaction ranges (in Godot world units)
const AUTO_BATTLE_RANGE: float = 1.5   # enemy engages player at this distance
const INTERACT_RANGE: float = 1.5      # E key interaction range
const TRACKING_SPEED: float = 2.5      # enemy movement speed (world units/sec)

# Player physics
const PLAYER_SPEED: float = 6.0        # world units/sec
const PLAYER_RADIUS: float = 0.25      # collision radius

func tile_to_world(tx: int, tz: int) -> Vector3:
	return Vector3(tx * TILE_SIZE, 0.0, tz * TILE_SIZE)

func world_to_tile(wx: float, wz: float) -> Vector2i:
	return Vector2i(int(wx / TILE_SIZE), int(wz / TILE_SIZE))
