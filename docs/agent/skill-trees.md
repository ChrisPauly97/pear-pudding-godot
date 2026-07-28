# Skill Trees

## Key Features

- **Eight branch-specific skill trees**, two per magic type:
  **Ember** / **Dawn** (Light), **Dusk** / **Ash** (Dark),
  **Bloom** / **Thorn** (Verdant), **Flux** / **Fracture** (Rift)
- Player chooses a home magic type once, from four — that choice gates their two accessible home trees
- **Skill points** (earned every level-up) spent on home-branch skills
- **Cross-magic points** let a player reach into *any* of the three non-home types. Which
  currency they spend is set by their own type's alignment (see the table below)
- The type → branch → colour → currency mapping lives in `game_logic/MagicTypes.gd`;
  `SkillTreeScene` holds no copy of it

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
| `magic_branch` | `String` | One of the eight branches in `MagicTypes.TYPES` |
| `alt_cost` | `int` | 0 = not cross-purchasable; >0 = costs this many corruption/redemption points |

**Passive effect types:** `passive_hp`, `passive_mana`, `passive_atk`, `passive_draw`  
**Active effect types:** `active_damage_all`, `active_heal`, `active_draw`, `active_mana`

### Skill Roster (48 skills, 6 per branch)

| Branch | Magic | Skills |
|---|---|---|
| Ember | light | Searing Focus (+1 atk), Torch Bearer (+1 mana), Inferno Surge (+2 atk), Flame Tempo (+1 draw), **Pyroblast** (AoE 3, cross★), Blazing Draw (draw 3) |
| Dawn | light | Inner Light (+8 hp), Wellspring (+1 mana), Radiant Shield (+15 hp), Clarity (+1 draw), **Restoration** (heal 8, cross★), **Arcane Clarity** (draw 2, cross★) |
| Dusk | dark | Dark Pact (+1 atk), Shadow Well (+1 mana), Lifetap (+10 hp), Void Tempo (+1 draw), **Soul Siphon** (heal 6, cross★), Mana Drain (steal 3 mana) |
| Ash | dark | Cinderheart (+8 hp), Entropy (+1 atk), Bone Armour (+15 hp), Brittle Edge (+2 atk), **Brittle Curse** (AoE 2, cross★), Grave Call (draw 2) |
| Bloom | verdant | Seedling (+8 hp), Deep Roots (+15 hp), **Overgrowth** (heal 10, cross★), First Shoots (+1 mana), Sunward Reach (+1 draw), Bountiful Harvest (+4 mana) |
| Thorn | verdant | Barbed Growth (+1 atk), Bramble Wall (+12 hp), **Thornburst** (AoE 2, cross★), Wild Sap (+1 mana), Rampant Vines (+2 atk), Second Bloom (heal 6) |
| Flux | rift | Leyward Focus (+1 mana), Phase Shift (+1 draw), **Reweave** (draw 3, cross★), Unstable Form (+8 hp), Kinetic Charge (+2 atk), Mana Surge (+4 mana) |
| Fracture | rift | Hairline Crack (+1 atk), Splintering (+2 atk), **Shatterwave** (AoE 3, cross★), Hollow Core (+8 hp), Fault Line (+1 mana), Scavenged Shards (draw 2) |

★ = cross-magic accessible (`alt_cost = 2`)

Every branch uses the same shape: two three-deep prerequisite chains at
`tree_col` 0 and 3, with the row-2 entry of the first chain being the
cross-purchasable active. New-branch effect magnitudes were copied from the
Light/Dark skill at the same tree position, so the trees are power-neutral
against each other.

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

1. **First open:** if `SaveManager.magic_type == ""`, shows a one-time "Choose Your Path" modal listing all four types in a 2×2 grid, built by iterating `MagicTypes.all_types()`. Choice is saved immediately.
2. **Normal view:** 3-tab layout:
   - Tab 0 / Tab 1: the player's two home branches (e.g. Ember + Dawn for light players)
   - Tab 2: "Cross-Magic" — every **non-home** type's skills with `alt_cost > 0` (6 entries for any starting choice), each labelled with its source branch and tinted with that branch's colour
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

**Constants in SkillTreeScene:** only `_ROWS: int = 3`. The branch tables moved to
`MagicTypes` in GID-127 — `SkillTreeScene` calls `MagicTypes.branches_for()`,
`branch_color()`, `all_types()` and `cross_currency()` instead of holding copies.

**Cross-currency mapping** (`MagicTypes.cross_currency`) — set by the buyer's own
type, not by what they are buying:

| Home type | Alignment | Spends |
|---|---|---|
| Light | life | `corruption_points` ("CP") |
| Verdant | life | `corruption_points` ("CP") |
| Dark | entropy | `redemption_points` ("RP") |
| Rift | entropy | `redemption_points` ("RP") |

Two currencies cover four types by alignment. Light and Dark behave exactly as
they did before GID-127.

**Currency accrual** — playing a type's *signature* branch card in a won battle
earns that type's currency at `MagicTypes.POINTS_PER_CARD` each:

| Signature branch | Type | Earns |
|---|---|---|
| Dawn | Light | corruption |
| Bloom | Verdant | corruption |
| Dusk | Dark | redemption |
| Fracture | Rift | redemption |

### SaveManager Fields

| Field | Type | Default | Added |
|---|---|---|---|
| `skill_points` | `int` | 0 | v12 |
| `unlocked_skills` | `Array[String]` | `[]` | v12 |
| `magic_type` | `String` | `""` | v13 (four valid values since GID-127) |
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
| **MagicTypes** | Owns the type/branch/colour/currency tables the whole tree reads |
| **BattlefieldRules** | `BRANCH_AFFINITY` — each signature branch's −1 mana condition |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Skill resources | `data/skills/*.tres` | 48 files, 6 per branch; each needs a `.tres.uid` sidecar and a `preload` line in `SkillRegistry` |
| SkillData script | `data/SkillData.gd` | Resource class definition |
| SkillRegistry | `autoloads/SkillRegistry.gd` | Not an autoload singleton — static methods only, loaded via `preload` |
| SkillTreeScene | `scenes/ui/SkillTreeScene.gd` | Instantiated and added to scene tree by SceneManager |
| MagicTypes | `game_logic/MagicTypes.gd` | Static tables; preload, not an autoload |
