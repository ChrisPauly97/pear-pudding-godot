## Streams and ponds in the infinite world (GID-134 / TID-524).
##
## Visual, wadeable water: a stream is a thin band of low-frequency noise near
## zero (like a ley line), a pond is a blob of a second noise. The intensity is
## baked per terrain vertex into UV2.y by ChunkRenderer, so the shader draws
## exactly what the CPU side (grass, props, footstep splashes) keeps clear of.
## Water only lies on level walkable grass — the shader masks walls, hills and
## paths — and only in biomes that have it.
extends RefCounted

const STREAM_FREQUENCY: float = 0.011
const STREAM_WIDTH: float = 0.045     # |noise| below this is in the stream
const POND_FREQUENCY: float = 0.035
const POND_LEVEL: float = 0.52        # noise above this is pond
const STREAM_SEED_OFFSET: int = 771133
const POND_SEED_OFFSET: int = 193771
## Biomes with water: grasslands, forest, mountains (no desert/scorched streams).
const WATER_BIOMES: Array[int] = [0, 1, 4]
## Intensity above which a spot counts as "in the water" (grass, props, splashes).
const WET_LEVEL: float = 0.3

static var _stream: FastNoiseLite = null
static var _pond: FastNoiseLite = null
static var _seed: int = -1
static var _mutex := Mutex.new()


static func biome_has_water(biome_id: int) -> bool:
	return WATER_BIOMES.has(biome_id)


## 0 (dry) .. 1 (middle of a stream or pond) at world (wx, wz).
static func intensity(wx: float, wz: float, world_seed: int) -> float:
	_ensure(world_seed)
	var s: float = absf(_stream.get_noise_2d(wx, wz))
	var stream: float = clampf(1.0 - s / STREAM_WIDTH, 0.0, 1.0)
	var p: float = _pond.get_noise_2d(wx, wz)
	var pond: float = clampf((p - POND_LEVEL) / 0.12, 0.0, 1.0)
	return maxf(stream, pond)


static func is_wet(wx: float, wz: float, world_seed: int) -> bool:
	return intensity(wx, wz, world_seed) > WET_LEVEL


static func _ensure(world_seed: int) -> void:
	if _seed == world_seed and _stream != null:
		return
	# Chunk builds run on worker threads; build the pair once per seed.
	_mutex.lock()
	if _seed != world_seed or _stream == null:
		var st := FastNoiseLite.new()
		st.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		st.seed = world_seed + STREAM_SEED_OFFSET
		st.frequency = STREAM_FREQUENCY
		var pd := FastNoiseLite.new()
		pd.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		pd.seed = world_seed + POND_SEED_OFFSET
		pd.frequency = POND_FREQUENCY
		_stream = st
		_pond = pd
		_seed = world_seed
	_mutex.unlock()
