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
| `undead_basic` | ghost, skeleton, mend, wither |
| `undead_horde` | skeleton, zombie, dawn_acolyte, dusk_wraith |
| `ghoul_pack` | zombie, ghoul, dawn_paladin, dusk_vampire |
| `undead_elite` | ghoul, restore, drain |

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

## Equipment System

### Overview

The player can equip items across four slots: **weapon**, **armor**, **ring**, and **trinket**. Each slot holds one item ID (empty string = nothing equipped). At battle start `BattleScene._apply_equipment_effects()` loops over all four slots, resolves each item via `WeaponRegistry`, and applies its effect to `PlayerState[0]` before the opening hand is drawn. All four slot types use the same `WeaponData` resource and registry — the `slot` field distinguishes them.

Mana cap invariant: max_mana never permanently exceeds 10. The `starting_mana` effect grants a one-time turn-1 burst; `PlayerState.gain_mana_for_turn(turn)` resets `max_mana = min(10, turn)` on every subsequent turn, naturally undoing the boost.

If multiple equipped items inject cards, all injections happen first and the deck is shuffled once at the end.

### WeaponData Resource (`data/WeaponData.gd`)

All equipment types share this resource class.

| Field | Type | Purpose |
|---|---|---|
| `id` | String | Unique identifier (matches filename without `.tres`) |
| `display_name` | String | Human-readable item name |
| `description` | String | Flavour / tooltip text |
| `slot` | String | `"weapon"` \| `"armor"` \| `"ring"` \| `"trinket"` (default `"weapon"`) |
| `battle_effect_type` | String | One of the effect types below |
| `battle_effect_value` | int | Numeric bonus (unused for `deck_inject`) |
| `injected_card_id` | String | Card ID to inject (deck_inject only) |
| `injected_card_count` | int | Copies to inject (deck_inject only) |

Equipment `.tres` files live in `data/weapons/`. Each must have a companion `.uid` sidecar.

### WeaponRegistry Autoload (`autoloads/WeaponRegistry.gd`)

Scans `data/weapons/` on first access, loads every `.tres` as a `WeaponData`, and indexes by `id`. API:

```gdscript
WeaponRegistry.get_weapon(id: String) -> WeaponData      # null if not found
WeaponRegistry.has_weapon(id: String) -> bool
WeaponRegistry.get_all_ids() -> Array[String]
WeaponRegistry.get_by_slot(slot: String) -> Array[String] # filter by slot field
```

### Effect Types

| `battle_effect_type` | Behaviour |
|---|---|
| `deck_inject` | Appends `injected_card_count` copies of `injected_card_id` to the player's draw pile. Deck is shuffled once after all slots are processed. |
| `starting_mana` | Adds `battle_effect_value` to `hero.mana` and `hero.max_mana` on turn 1. Naturally reset by `gain_mana_for_turn()` on turn 2+. |
| `starting_hp` | Adds `battle_effect_value` to both `hero.health` and `hero.max_health` (permanent for the battle). |
| `passive_atk` | Adds `battle_effect_value` to `hero.attack` (permanent for the battle). |

### SaveManager Equipment Fields

| Field | Type | Description |
|---|---|---|
| `equipped_weapon` | String | ID of currently equipped weapon (`""` = none) |
| `equipped_armor` | String | ID of currently equipped armor |
| `equipped_ring` | String | ID of currently equipped ring |
| `equipped_trinket` | String | ID of currently equipped trinket |
| `owned_weapons` | Array[String] | All weapon IDs owned |
| `owned_armor` | Array[String] | All armor IDs owned |
| `owned_rings` | Array[String] | All ring IDs owned |
| `owned_trinkets` | Array[String] | All trinket IDs owned |

Helper API:
```gdscript
SaveManager.add_equipment(item_id, slot)          # routes to correct owned array
SaveManager.equip_item(item_id, slot)             # sets correct equipped field
SaveManager.get_owned_by_slot(slot) -> Array[String]
SaveManager.get_equipped_by_slot(slot) -> String
```

`equip_weapon(id)` is kept for backward compatibility (used by InventoryScene weapons tab). New code should use `equip_item(id, slot)`.

### Built-in Weapons

| ID | Effect |
|---|---|
| `rusty_dagger` | `deck_inject` — injects 3× `dagger_throw` (cost-0 auto-resolve spell) |

---

## Auto-Resolve Cards

`CardData` has an `auto_resolve: bool` field (default `false`). When a card with `auto_resolve = true` is drawn:
- It is never placed in the player's hand
- Its `spell_effect` fires immediately via `PlayerState.pending_auto_spells`
- `BattleScene._flush_auto_spells()` drains that queue and calls `_resolve_spell_effect()` for each card

This mechanism is used by weapon-injected spell cards so they fire automatically without requiring the player to spend mana or make a choice.

| Card | `spell_effect` | Behaviour |
|---|---|---|
| `dagger_throw` | `deal_damage_random` | Hits a random enemy minion for `spell_power` damage; targets the enemy hero if the board is empty |

The `dagger_throw` card has `cost = 0` and `auto_resolve = true`. It is defined in `data/cards/dagger_throw.tres`.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **SaveManager** | Read + Write | Source of truth for `owned_cards`, `player_deck`, all four `equipped_*` and `owned_*` equipment arrays; InventoryScene reads and writes card arrays; CharacterScene reads and writes equipment |
| **CardRegistry** | Data source | `CardRegistry.get_card(id)` resolves name/cost/stats for display in the UI |
| **BattleScene** | Consumer | Reads `SaveManager.player_deck` at battle start; calls `_apply_equipment_effects()` to apply all four slot bonuses before opening hand |
| **WeaponRegistry** | Data source | Resolves `WeaponData` by id from `data/weapons/`; used by `BattleScene._apply_equipment_effects()`; `get_by_slot()` filters by slot for CharacterScene pickers |
| **Chest entity** | Card source | `Chest.gd` calls `SaveManager.add_card()` on open; marks chest ID in `SaveManager.opened_chests` |
| **GameBus** | Signal | `inventory_requested` opens the overlay; `chest_opened(card_id)` delivers card drops |
| **SceneManager** | Overlay router | Instantiates and removes `InventoryScene` in response to `GameBus.inventory_requested` |

---

## Endless Spire: Run-Local Deck Isolation

During an Endless Spire run the player's battle deck is separate from their persistent `player_deck`. It is built up by drafting cards after each floor victory.

### How it works

- `SaveManager.spire_run.draft_deck` is a plain `Array` of card IDs accumulated via `add_drafted_card(id)`.
- `BattleScene._ready()` checks `SaveManager.is_spire_active()` first:
  - If active and `draft_deck` is non-empty → build deck from `draft_deck`.
  - If active and `draft_deck` is empty (floor 1, before first draft) → use an 8-card starter (`ghost×2, skeleton×2, zombie×2, ghoul×2`).
  - If not active → fall through to the normal `player_deck` path.
- The persistent `player_deck` is never modified during a Spire run.

### Draft pick flow

After each floor victory the floor scene instantiates `SpireDraftScene`:

```gdscript
var draft := preload("res://scenes/ui/SpireDraftScene.tscn").instantiate()
add_child(draft)
draft.setup(floor_number)
draft.picked.connect(_on_draft_picked)
```

`SpireDraftScene` calls `SpireDraft.generate_picks(floor, rng, pool_templates)` where `pool_templates` is a `{card_id: template_dict}` Dictionary built from `CardRegistry.get_all_ids()`. This design keeps `SpireDraft` pure and testable without an autoload dependency.

### SpireDraft tier system

| Tier | Card class | Cost range |
|---|---|---|
| 0 — Basic | minion | 1–2 |
| 1 — Standard | minion / spell | 3–4 / 1–2 |
| 2 — Premium | minion / spell | 5+ / 3+ |
| 3 — Legendary | legendary | any |

Floor-weighted distribution:

| Floors | T0 | T1 | T2 | T3 |
|---|---|---|---|---|
| 1–3 | 60 | 30 | 10 | 0 |
| 4–6 | 35 | 40 | 20 | 5 |
| 7+ | 15 | 35 | 35 | 15 |

### Signals

`GameBus.spire_card_drafted(card_id: String)` — emitted by `SpireDraftScene._on_pick()` after each pick so other systems can react (achievements, analytics, etc.).

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| InventoryScene | `scenes/ui/InventoryScene.tscn` | Root scene for the deck builder overlay |
| `InventoryScene.gd` | `scenes/ui/InventoryScene.gd` | Script driving the collection + deck panels |
| Card data resources | `data/cards/*.tres` | One `CardData` per card type; fields: id, display_name, cost, attack, health |
| Card textures (optional) | `assets/textures/` | Per-card art; falls back to coloured panel if absent |
| Save file | `user://save.json` | Written by `SaveManager`; v11 format adds all four equipment slot fields |
| WeaponData script | `data/WeaponData.gd` | Resource class for all equipment types; `slot` field distinguishes them |
| Equipment resources | `data/weapons/*.tres` | One `WeaponData` per item (all slots); each needs a `.uid` sidecar |
| `WeaponRegistry.gd` | `autoloads/WeaponRegistry.gd` | Static registry; scans and indexes all equipment resources |
