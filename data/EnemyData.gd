extends Resource

@export var id: String = ""
@export var display_name: String = ""
## Card IDs that make up this enemy's battle deck. Duplicates allowed.
@export var deck: PackedStringArray = PackedStringArray()
## Cards that may be dropped when this enemy is defeated.
## Regular enemies: one card chosen at random. Boss enemies: all cards dropped.
@export var drop_pool: PackedStringArray = PackedStringArray()
## Coins awarded to the player when this enemy is defeated.
@export var coin_reward: int = 5
## If true, this enemy uses the boss battle presentation (banner, higher HP, full drop pool) and guarantees a weapon drop.
@export var is_boss: bool = false
## Override enemy hero HP for this encounter (0 = use default 30).
@export var boss_hp: int = 0
## When non-empty and enemy HP drops to 50% or below, swap to this deck (phase 2).
@export var phase2_deck: PackedStringArray = PackedStringArray()
## Difficulty tier (1–4) used to weight rarity on card drops. Higher = rarer drops.
@export var difficulty_tier: int = 1
## Short lore blurb revealed in the Bestiary after defeating this enemy 3 times.
@export var lore_text: String = ""
## ID of the signature card that can be captured from this enemy. "" = no signature.
@export var signature_card: String = ""
## Condition key that must hold for the capture to trigger. "" = no condition.
@export var capture_condition: String = ""
## Numeric parameter for conditions like win_by_turn or hero_hp_at_most.
@export var capture_param: int = 0
