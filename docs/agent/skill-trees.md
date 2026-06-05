# Skill Trees

## Key Features

- Four branch-specific skill trees: **Ember**, **Dawn** (light magic), **Dusk**, **Ash** (dark magic)
- Player chooses a home magic type (light or dark) once — that choice gates their two accessible home trees
- **Skill points** (earned every level-up) spent on home-branch skills
- **Corruption points** (earned via dark dialogue choices) spent by light players to access select dark-branch skills
- **Redemption points** (earned via light dialogue choices) spent by dark players to access select light-branch skills
- Cross-magic earn logic is stubbed — `SaveManager.add_corruption_points()` / `add_redemption_points()` methods exist; wiring to dialogue choices is deferred to a future goal

---

## How It Works

### SkillData Resource (`data/SkillData.gd`)

Each skill is a `Resource` instance with these fields:

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique identifier, prefixed with branch name (e.g. `ember_pyroblast`) |
| `display_name` | `String` | Human-readable name |
| `description` | `String` | Flavour + mechanical description |
| `skill_type` | `String` | `"passive"` or `"active"` |
| `effect_type` | `String` | One of the passive/active effect types below |
| `effect_value` | `int` | Magnitude of the effect |
| `prerequisites` | `Array[String]` | IDs that must be unlocked first (home-branch only; ignored for cross-magic purchases) |
| `tree_row` | `int` | Row in the 3×5 branch grid (0 = entry, 2 = capstone) |
| `tree_col` | `int` | Column in the 3×5 branch grid |
| `magic_branch` | `String` | `"ember"`, `"dawn"`, `"dusk"`, or `"ash"` |
| `alt_cost` | `int` | 0 = not cross-purchasable; >0 = costs this many corruption/redemption points |

**Passive effect types:** `passive_hp`, `passive_mana`, `passive_atk`, `passive_draw`  
**Active effect types:** `active_damage_all`, `active_heal`, `active_draw`, `active_mana`

### Skill Roster (24 skills, 6 per branch)

| Branch | Magic | Skills |
|---|---|---|
| Ember | light | Searing Focus (+1 atk), Torch Bearer (+1 mana), Inferno Surge (+2 atk), Flame Tempo (+1 draw), **Pyroblast** (AoE 3, cross★), Blazing Draw (draw 3) |
| Dawn | light | Inner Light (+8 hp), Wellspring (+1 mana), Radiant Shield (+15 hp), Clarity (+1 draw), **Restoration** (heal 8, cross★), **Arcane Clarity** (draw 2, cross★) |
| Dusk | dark | Dark Pact (+1 atk), Shadow Well (+1 mana), Lifetap (+10 hp), Void Tempo (+1 draw), **Soul Siphon** (heal 6, cross★), Mana Drain (steal 3 mana) |
| Ash | dark | Cinderheart (+8 hp), Entropy (+1 atk), Bone Armour (+15 hp), Brittle Edge (+2 atk), **Brittle Curse** (AoE 2, cross★), Grave Call (draw 2) |

★ = cross-magic accessible (`alt_cost = 2`)

### SkillRegistry (`autoloads/SkillRegistry.gd`)

Loads all `.tres` files from `res://data/skills/` at first access. Key methods:

```gdscript
SkillRegistry.get_skill(id: String) -> SkillData
SkillRegistry.get_all_ids() -> Array[String]
SkillRegistry.get_by_branch(branch: String) -> Array[String]
SkillRegistry.get_by_type(skill_type: String) -> Array[String]
```

### SkillTreeScene (`scenes/ui/SkillTreeScene.gd`)

Opened via S key or HUD button. Flow:

1. **First open:** if `SaveManager.magic_type == ""`, shows a one-time "Choose Your Path" modal (Light vs. Dark). Choice is saved immediately.
2. **Normal view:** 3-tab layout:
   - Tab 0 / Tab 1: the player's two home branches (e.g. Ember + Dawn for light players)
   - Tab 2: "Cross-Magic" — shows only opposing-type skills with `alt_cost > 0`
3. **Header** shows all three currency balances: `SP: X  |  CP: X  |  RP: X`
4. **Home-branch unlock:** costs 1 skill point; prerequisite chain enforced
5. **Cross-magic unlock:** costs `alt_cost` corruption/redemption points; no prerequisites required

**Home-branch layout (tree view):**

Each home-branch tab renders skills in a top-down tree layout using absolute positioning inside a plain `Control` (stored as `_skill_container`) inside a `ScrollContainer`. The layout places skills at coordinates derived from `(tree_row, tree_col)`:
- Two visible columns: `tree_col = 0` on the left, `tree_col = 3` on the right
- `node_w = (_vw * 0.90 - _vw * 0.04) / 2.0`; `node_h = _vh * 0.19`
- Row gap (connector space): `_vh * 0.06`; column gap: `_vw * 0.04`

Between each vertically-linked pair (parent → child in same column), a `ColorRect` connector bar is drawn:
- Width: `_vw * 0.012`; height: `row_gap`; centred horizontally on the column
- Color: full branch color if the parent is unlocked; 25% alpha if locked

**Cross-magic tab:** wraps a 2-column `GridContainer` child inside `_skill_container`. No connector bars — cross-magic skills have no prerequisite relationships in this view.

**Constants in SkillTreeScene:**
```gdscript
const MAGIC_BRANCHES: Dictionary = {
    "light": ["ember", "dawn"],
    "dark":  ["dusk",  "ash"],
}
const _ROWS: int = 3
```

**Cross-currency mapping:**
- Light player buying dark skills → spends `corruption_points` (labelled "CP")
- Dark player buying light skills → spends `redemption_points` (labelled "RP")

### SaveManager Fields

| Field | Type | Default | Added |
|---|---|---|---|
| `skill_points` | `int` | 0 | v12 |
| `unlocked_skills` | `Array[String]` | `[]` | v12 |
| `magic_type` | `String` | `""` | v13 |
| `corruption_points` | `int` | 0 | v13 |
| `redemption_points` | `int` | 0 | v13 |

**Key mutators:**
```gdscript
SaveManager.set_magic_type(t: String)           # one-time choice
SaveManager.unlock_skill(id: String)            # costs 1 skill_point
SaveManager.unlock_cross_skill(id, cost, currency)  # costs corruption/redemption
SaveManager.add_corruption_points(amount: int)  # call at dark dialogue choices
SaveManager.add_redemption_points(amount: int)  # call at light dialogue choices
```

### Battle Integration

Passive and active skill application is **unchanged** — still keyed by skill ID string in `unlocked_skills`:

- **Passives** (`passive_hp`, `passive_mana`, etc.) — applied to `PlayerState` at battle start alongside weapon effects
- **Active hero power** — the first active skill in `unlocked_skills` shows a once-per-battle button in BattleScene

No branch-awareness is needed in the battle system; skills are identified purely by ID.

---

## Integrations with Other Features

| System | Integration |
|---|---|
| **SaveManager** | Stores `magic_type`, `skill_points`, `corruption_points`, `redemption_points`, `unlocked_skills` |
| **GameBus** | `level_up` → `skill_points += 1` in SaveManager; `corruption_points_changed` / `redemption_points_changed` emitted on earn |
| **BattleScene** | Reads `unlocked_skills` at battle start to apply passive bonuses and wire the active hero power button |
| **Dialogue system** (future) | Will call `add_corruption_points()` / `add_redemption_points()` at morally-aligned choice points |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Skill resources | `data/skills/*.tres` | 24 files, 6 per branch; each needs a `.tres.uid` sidecar |
| SkillData script | `data/SkillData.gd` | Resource class definition |
| SkillRegistry | `autoloads/SkillRegistry.gd` | Not an autoload singleton — static methods only, loaded via `preload` |
| SkillTreeScene | `scenes/ui/SkillTreeScene.gd` | Instantiated and added to scene tree by SceneManager |
