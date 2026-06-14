# Card Packs & Pack Opening

## Key Features

- Two sealed pack tiers sold at the merchant shop (Standard 120 coins, Premium 300 coins)
- Each pack yields 3 cards rolled at purchase time via `CardDropUtil`
- A full-screen tap-to-flip reveal ceremony with rarity-coloured card faces
- Legendary pity counter persisted in save data: forces a legendary after 20 consecutive non-legendary packs
- Premium packs guarantee slot 1 is at least Rare

---

## How It Works

### Pack Definitions (`game_logic/PackDefs.gd`)

Static file (no `class_name`; callers preload it). Contains:

```gdscript
const PITY_THRESHOLD: int = 20

const PACKS: Dictionary = {
    "standard_pack": { "id": ..., "name": "Standard Pack", "price": 120, "card_count": 3, "tier": 1 },
    "premium_pack":  { "id": ..., "name": "Premium Pack",  "price": 300, "card_count": 3, "tier": 2,
                       "guaranteed_min_rarity": "rare" },
}

static func get_pack(pack_id: String) -> Dictionary
static func get_all_pack_ids() -> Array[String]
static func roll_pack(pack_id: String, current_pity: int) -> Array[Dictionary]
```

`roll_pack` returns an array of card dicts: `{ template_id, rarity, attack, health, cost }`.

**Roll algorithm:**
1. Build pool from `CardRegistry.get_all_ids()` filtered to `is_craftable()` cards. Fall back to all cards if pool is empty. Return `[]` if still empty (headless mode without `.tres` files).
2. For each of the 3 slots: pick a random `template_id`, call `CardDropUtil.roll_rarity(tier)` for the rarity, call `CardDropUtil.roll_stats(template_id, rarity)` for stats.
3. Apply `guaranteed_min_rarity` to slot 1 (Premium packs): if slot 1's rarity is below the guarantee, re-roll its stats at the guaranteed rarity.
4. Apply pity: if `current_pity >= PITY_THRESHOLD`, force last slot to legendary (re-roll stats at "legendary").

Tier weights are defined in `CardDropUtil.TIER_WEIGHTS`: tier 1 = [80, 18, 2, 0] (no legendary), tier 2 = [60, 30, 9, 1].

### Shop Integration (`scenes/ui/ShopScene.gd`)

A "— Packs —" section appears above the cards section in the normal merchant shop. Each pack shows its name, price, and a buy button. If `packs_since_legendary > 0`, a grey hint label shows how many more packs until the legendary guarantee fires.

On buy (`_on_buy_pack`):
1. Deduct coins.
2. Call `SaveManager.increment_pity()`.
3. Call `PackDefs.roll_pack(pack_id, sm.packs_since_legendary)` with the now-incremented counter.
4. If counter reached threshold, call `SaveManager.reset_pity()` immediately.
5. Emit `GameBus.pack_purchased(pack_id, rolled_cards)`.

### Pack Opening Ceremony (`scenes/ui/PackOpenScene.gd`)

Full-screen overlay built entirely in code (no `.tscn`). Set `_rolled_cards` property before `add_child()`. SceneManager instantiates it, sets the property, and connects the `closed` signal.

Layout: dark backdrop → VBox (title, subtitle, HBox of 3 card slots, action buttons).

**Card slot structure:**
- Wrapper `Control` (fixed vh-relative size)
- Visual `Control` (pivot at centre, scaled for flip tween)
  - Back `ColorRect` (grey, hidden after flip)
  - Face background `ColorRect` (rarity-tinted, shown after flip)
  - Face content `VBoxContainer` (name, cost, ATK/HP labels, shown after flip)
- Tap `Button` (child of wrapper, not visual — so tapping still works mid-animation)

**Flip animation (`_flip_card(idx)`):**
1. Tween `visual.scale:x` 1.0 → 0.0 (0.15 s).
2. At x=0: swap back hidden/face visible, populate face content.
3. Tween `visual.scale:x` 0.0 → 1.0 (0.15 s).
4. On complete: call `SaveManager.add_card_instance()` to persist the card; if legendary, call `SaveManager.reset_pity()`.

**Rarity colours:**
- Common: `Color(0.80, 0.80, 0.80)`
- Rare: `Color(0.20, 0.50, 1.00)`
- Epic: `Color(0.70, 0.20, 1.00)`
- Legendary: `Color(1.00, 0.75, 0.00)`

"Reveal All" button instantly reveals all unflipped cards (skips animation, populates faces immediately, persists all card instances).

"Done" button emits `closed` signal; SceneManager frees the overlay and returns to `State.WORLD`.

### Pity Counter (`autoloads/SaveManager.gd`)

New field: `var packs_since_legendary: int = 0`

New methods:
```gdscript
func increment_pity() -> void:
    packs_since_legendary += 1
    _dirty = true

func reset_pity() -> void:
    packs_since_legendary = 0
    _dirty = true
```

The counter is incremented on every pack purchase and reset to 0 whenever a legendary card appears (either from natural roll or pity force). The pity check in `roll_pack()` reads the already-incremented value — caller increments first, then passes the counter.

### Save Migration (v24 → v25)

```gdscript
static func _migrate_v24_to_v25(data: Dictionary) -> void:
    if not data.has("packs_since_legendary"):
        data["packs_since_legendary"] = 0
    data["version"] = 25
```

Called in `_apply_migrations()` when `ver < 25`. `CURRENT_SAVE_VERSION` is now 25.

### SceneManager Routing (`autoloads/SceneManager.gd`)

`State.PACK_OPEN` added to the enum. Flow:
1. `GameBus.pack_purchased` fires → `_on_pack_purchased(pack_id, rolled_cards)`.
2. Shop overlay is freed.
3. `PackOpenScene` instantiated, `_rolled_cards` set, `closed` signal connected, added to `current_scene`.
4. State → `PACK_OPEN`.
5. On `closed`: overlay freed, state → `WORLD`.

---

## Integrations with Other Features

| System | Integration |
|---|---|
| `CardDropUtil` | `roll_rarity(tier)` and `roll_stats(template_id, rarity)` provide weighted drops |
| `CardRegistry` | Pack pool is filtered to `is_craftable()` cards |
| `SaveManager` | `add_card_instance()` persists rolled cards; pity counter fields |
| `ShopScene` | "— Packs —" section added above cards; `_on_buy_pack()` triggers the flow |
| `SceneManager` | Listens to `pack_purchased`; manages `PackOpenScene` overlay lifecycle |
| `GameBus` | `pack_purchased` signal decouples shop from SceneManager |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `PackDefs.gd` | `game_logic/PackDefs.gd` | Static definitions and roll logic; no `class_name` |
| `PackOpenScene.gd` | `scenes/ui/PackOpenScene.gd` | UI overlay built in code; preloaded by `SceneManager` |
| `test_card_packs.gd` | `tests/unit/test_card_packs.gd` | 31 unit tests for all three task areas |

No `.tres`, `.tscn`, or `.uid` files needed — the scene is built entirely in GDScript.
