extends RefCounted

const GRASSLANDS: int = 0
const FOREST:     int = 1
const DESERT:     int = 2
const SCORCHED:   int = 3
const MOUNTAINS:  int = 4
const COUNT:      int = 5

# Per-biome terrain generation parameters.
# hill_thresh  — noise [0,1] above which a tile becomes TILE_HILL
# max_hill_h   — maximum hill height in levels
# freq_scale   — coordinate scale applied to noise sampling (>1 = choppier, <1 = broader)
const PARAMS: Array = [
	# GRASSLANDS — open meadows, gentle low hills
	{"hill_thresh": 0.82, "max_hill_h": 2, "freq_scale": 0.9},
	# FOREST — dense hills (tall ruins stand like trees)
	{"hill_thresh": 0.72, "max_hill_h": 3, "freq_scale": 1.1},
	# DESERT — nearly flat, rare shallow dunes
	{"hill_thresh": 0.91, "max_hill_h": 1, "freq_scale": 0.8},
	# SCORCHED — jagged, tall spires
	{"hill_thresh": 0.70, "max_hill_h": 5, "freq_scale": 1.2},
	# MOUNTAINS — very hilly, great peaks
	{"hill_thresh": 0.62, "max_hill_h": 7, "freq_scale": 1.0},
]

# Flat-ground surface tint per biome (multiplied over base grass texture).
const GRASS_TINT: Array[Color] = [
	Color(0.72, 0.94, 0.38),   # Grasslands — bright spring green
	Color(0.22, 0.50, 0.14),   # Forest      — deep pine green
	Color(0.87, 0.72, 0.38),   # Desert      — warm sand
	Color(0.22, 0.09, 0.03),   # Scorched    — charred black-brown
	Color(0.85, 0.90, 0.96),   # Mountains   — snow white-blue
]

# Hill surface tint per biome.
const HILL_TINT: Array[Color] = [
	Color(0.55, 0.76, 0.28),   # Grasslands
	Color(0.18, 0.42, 0.10),   # Forest
	Color(0.74, 0.60, 0.28),   # Desert
	Color(0.35, 0.14, 0.04),   # Scorched
	Color(0.58, 0.65, 0.72),   # Mountains
]

# Wall/ruin surface tint per biome.
const WALL_TINT: Array[Color] = [
	Color(0.60, 0.50, 0.35),   # Grasslands — mossy stone
	Color(0.28, 0.20, 0.12),   # Forest      — dark bark/stone
	Color(0.80, 0.70, 0.50),   # Desert      — pale sandstone
	Color(0.16, 0.07, 0.02),   # Scorched    — obsidian/lava rock
	Color(0.40, 0.45, 0.52),   # Mountains   — dark granite
]

# Per-biome enemy pool: [near_type, far_type] — indexed by clamp(dist/8, 0, 1).
const ENEMY_POOLS: Array = [
	["undead_basic", "undead_horde"],    # Grasslands
	["undead_horde", "ghoul_pack"],      # Forest
	["undead_basic", "ghoul_pack"],      # Desert
	["ghoul_pack",   "undead_elite"],    # Scorched
	["undead_elite", "undead_elite"],    # Mountains
]

# Per-biome Environment.adjustment scalars (brightness, contrast, saturation).
# Grasslands: vivid; Forest: cool/desaturated; Desert: bleached; Scorched: dark/muted; Mountains: crisp/cold.
const ADJ_PARAMS: Array = [
	{"brightness": 1.0,  "contrast": 1.05, "saturation": 1.1},
	{"brightness": 0.95, "contrast": 1.05, "saturation": 0.85},
	{"brightness": 1.1,  "contrast": 1.1,  "saturation": 0.9},
	{"brightness": 0.9,  "contrast": 1.15, "saturation": 0.7},
	{"brightness": 1.05, "contrast": 1.0,  "saturation": 0.8},
]

# Per-biome prop types to scatter on TILE_GRASS cells (used by ChunkRenderer).
const PROP_SETS: Array = [
	["rock", "flower"],     # Grasslands
	["mushroom", "fern"],   # Forest
	["cactus", "thorn"],    # Desert
	["ash_pile", "ember"],  # Scorched
	["boulder", "lichen"],  # Mountains
]

# NPC dialogue lines per biome.
const NPC_LINES: Array = [
	["The flowers here bloom even in winter.", "These fields stretch as far as I can see."],
	["Stay on the path — the forest has eyes.", "Ancient trees remember everything."],
	["Water is worth more than gold out here.", "The heat makes you see things."],
	["Nothing grows here anymore. Nothing good.", "The ground itself is angry."],
	["One wrong step and it's a long fall.", "The cold keeps the dead quiet. Mostly."],
]
