# Inventory and Deck Management

## Key Features

- Player owns a card collection (all cards obtained) and a separate active battle deck
- Deck builder UI: browse collection on the left, edit the active deck on the right
- Starter deck: 12 cards — 3× Ghost, 3× Skeleton, 3× Zombie, 3× Ghoul
- Cards dropped from chests: 1 random card added to the collection per chest opened
- Active battle deck is loaded into `PlayerState` at the start of every battle
- Both collection and deck are persisted to `save.json` via `SaveManager`

---

## How It Works

### Data Structures

`SaveManager` tracks two arrays:
- `owned_cards: Array[String]` — all card IDs the player has collected (duplicates allowed; one entry per copy)
- `player_deck: Array[String]` — the subset currently in the active battle deck

Each string is a card ID (e.g. `"ghost"`, `"skeleton"`) matching a `CardData` resource in `data/cards/`.

### InventoryScene UI (`scenes/ui/InventoryScene.gd`)

The scene has two panels side by side:

**Collection panel (left)**
- Iterates `SaveManager.owned_cards`
- Renders one button per unique card type showing name, cost, attack/health, and count owned
- "Add to Deck" button moves one copy from collection listing into deck listing
- UI sized relative to viewport height using the recommended fractions from CLAUDE.md

**Deck panel (right)**
- Lists cards currently in `SaveManager.player_deck` with a count per type
- "Remove" button moves one copy back to the collection listing
- Deck size is not hard-capped in the UI but `BattleScene` expects a reasonable deck (8–20 cards recommended)

Changes are written back to `SaveManager` immediately on every add/remove button press; `SaveManager` queues a disk write (batched, 2-second interval).

### Starter Deck

When `SaveManager.new_game()` is called, both arrays are initialised:

```gdscript
owned_cards  = ["ghost","ghost","ghost","skeleton","skeleton","skeleton",
                "zombie","zombie","zombie","ghoul","ghoul","ghoul"]
player_deck  = owned_cards.duplicate()
```

The player starts with all 12 cards both owned and in the deck.

### Battle Card Drops

Each `EnemyData` resource has a `drop_pool: PackedStringArray` field listing card IDs that may be awarded on defeat. `EnemyRegistry.get_drop_pool(type_id)` returns this array (falls back to `["ghost"]` for unknown types). The post-battle reward flow (TID-006) picks one card at random and calls `SaveManager.add_card(card_id)`.

| Enemy | Drop Pool |
|---|---|
| `undead_basic` | ghost, skeleton |
| `undead_horde` | skeleton, zombie |
| `ghoul_pack` | zombie, ghoul |
| `undead_elite` | ghoul |

### Chest Card Drops

When the player opens a chest (`Chest.gd` triggers `GameBus.chest_opened(card_id)`):
1. `SceneManager` (or `WorldScene`) receives the signal
2. Calls `SaveManager.add_card(card_id)` which appends one ID to `owned_cards`
3. The world entity is flagged as opened in `SaveManager.opened_chests` to prevent re-granting

The card ID is chosen randomly from the full card pool weighted by rarity (currently uniform).

### Accessing the Inventory

The player presses `I` in the world view:
1. `WorldScene` emits `GameBus.inventory_requested`
2. `SceneManager` instantiates `InventoryScene` as a full-screen overlay
3. Closing the inventory removes the overlay and resumes the world

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **SaveManager** | Read + Write | Source of truth for `owned_cards` and `player_deck`; InventoryScene reads and writes both |
| **CardRegistry** | Data source | `CardRegistry.get_card(id)` resolves name/cost/stats for display in the UI |
| **BattleScene** | Consumer | Reads `SaveManager.player_deck` at battle start to populate `PlayerState[0].draw_pile` |
| **Chest entity** | Card source | `Chest.gd` calls `SaveManager.add_card()` on open; marks chest ID in `SaveManager.opened_chests` |
| **GameBus** | Signal | `inventory_requested` opens the overlay; `chest_opened(card_id)` delivers card drops |
| **SceneManager** | Overlay router | Instantiates and removes `InventoryScene` in response to `GameBus.inventory_requested` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| InventoryScene | `scenes/ui/InventoryScene.tscn` | Root scene for the deck builder overlay |
| `InventoryScene.gd` | `scenes/ui/InventoryScene.gd` | Script driving the collection + deck panels |
| Card data resources | `data/cards/*.tres` | One `CardData` per card type; fields: id, display_name, cost, attack, health |
| Card textures (optional) | `assets/textures/` | Per-card art; falls back to coloured panel if absent |
| Save file | `user://save.json` | Written by `SaveManager`; `owned_cards` and `player_deck` arrays live here |
