extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## "passive" (a card modifier) or "active" (grants a technique card) — GID-179.
@export var skill_type: String = "passive"
## Card modifiers (real-time fights only, SkillMods): "mod_recycle", "mod_cost",
## "mod_cast", "mod_power", "mod_crit", "on_crit_instant", "on_crit_refund";
## or "grant_technique". See combat-model.md → "Skill tree modifies cards".
@export var effect_type: String = ""
## % for recycle / cast / power / crit, mana units for cost / refund.
@export var effect_value: int = 0
## Which cards a modifier touches: a branch, "spell", "technique", "ally",
## "damage", "heal", "any", or a card id (SkillMods.matches). For school_* nodes: the school.
@export var filter: String = ""
## grant_technique: the technique card id the node owns (TechniqueDefs).
## GID-181 / TID-754: "school_power" (outgoing % for hits of the school in `filter`) and
## "school_resist" (% of that school's damage soaked); both apply in every fight mode.
@export var grants_card: String = ""
@export var prerequisites: Array[String] = []
@export var tree_row: int = 0
@export var tree_col: int = 0
## One of the eight branches in MagicTypes.TYPES: "ember"/"dawn" (Light),
## "dusk"/"ash" (Dark), "bloom"/"thorn" (Verdant), "flux"/"fracture" (Rift).
@export var magic_branch: String = ""
## 0 = not cross-purchasable. >0 = costs this many corruption/redemption points.
@export var alt_cost: int = 0
