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

Note: `owned_cards` is actually `Array[Dictionary]` of card **instances** (uid, template_id, rarity, rolled attack/health/cost, kills, custom_name, …), not an `Array[String]` of card IDs — every instance rolls its own stats, so even two commons of the same template can differ. See `_CardInstanceUtil.make()`.

### Backpack Capacity (the "Bag")

`SaveManager.bag_size` caps how many card instances the player can hold **outside their active deck**. Every owned instance takes exactly one backpack slot — there is no stacking, since same-rarity copies can roll different stats — except instances currently in the active deck, which don't count against the cap at all (they've "moved" into the deck).

```gdscript
SaveManager.get_slot_count(deck_uids: Array = []) -> int   # counts owned_cards not in deck_uids (default: player_deck)
SaveManager.is_bag_full() -> bool                          # get_slot_count() >= bag_size
```

`InventoryScene` passes `_working_deck` into `get_slot_count()`. Since GID-180 every deck edit is committed at once (`_edit_deck` → `set_active_deck`), so the working deck always equals `player_deck`. `add_card_instance()` rejects new cards (returns `""`, emits `GameBus.bag_full`) once the bag is full; automatic rewards go through `grant_card_reward()`, which routes to the mailbox instead (see TID-743).

The collection panel renders the backpack as an `HFlowContainer` of card-face tiles (`_make_card_tile` → `scenes/ui/inventory/CardTile.gd`), one per instance: cost gem, rarity-coloured frame + rarity letter, illustration (or a monogram on the card colour), name, ⚔ATK ♥HP (or "Spell"), veterancy chevrons, and an "In <deck>" tag when the card sits in another loadout. Right-click (desktop) or tap-and-hold (mobile, via `LongPressDetector`) opens a detail popup: mana/class/stats, rules text, kills/battles, a warning if the card is in a deck, Add to Deck, Inspect (full `CardInspectOverlay`), Sell/Scrap, Combine 3 → next tier (any tier below legendary, with an n/3 count) and Rename. A plain tap/click adds the card to the working deck.

#### Bag tools (GID-148)

- **Tabs** — Cards / Craft / Items (`UiUtil.make_tab_row`), with one shared wallet line: `Bag used/cap  gold  essence` (red when the bag is full).
- **Toolbar** — search (name, rules text, keywords), a sort cycle (Name → Rarity → Cost → Power → Newest) and a **Select** toggle. The class/cost/rarity filter row stays below it; a hint line explains the gestures for the current mode.
- **Bulk select** — in Select mode a tap toggles a card's selection (green frame + ✓). The bulk bar shows `N selected`, **Extras**, **None**, `Sell +Xg`, `Scrap +Ye`; either action opens a confirm summarising the count per rarity and the payout, and re-checks each card at apply time. Cards in any deck (saved loadouts or the working deck) and unique cards can't be selected (dimmed).
- **Extras** — `BagOps.pick_extras()` keeps the best copy of each card (rarity → ATK+HP → lower cost) and selects every other copy that isn't in a deck, unique, renamed or a veteran.

Pure logic lives in `game_logic/inventory/BagOps.gd` (sort, search, deck membership, extras, bulk value; templates via a `tmpl_for` Callable) and is covered by `test_bag_ops`. `menu_hub_smoke` drives sort, search, the Craft/Items tabs and an Extras → bulk scrap in a live tree.

#### Craft and Items panels

`scenes/ui/inventory/CraftPanel.gd` (a `VBoxContainer`, `setup(ref)` / `refresh()`, emits `crafted`): cards only. Rarity chips with the essence price, a recipe search, then one row per recipe with cost gem, name in rarity colour, Minion ⚔/♥ or Spell, rules text, `Owned ×N` and a `Craft  Ne` button (disabled with a tooltip reason when short on essence or the bag is full — the bag is checked **before** essence is spent, and refunded if `add_card_instance` still refuses). A status line confirms each craft. Potions are no longer on this tab (GID-182 / TID-764): they are brewed at the alchemy table through the profession panel, and that station is gated on the Alchemy feature (`docs/agent/professions.md`).

`scenes/ui/inventory/ItemsPanel.gd` lists non-card bag contents: potions (count + battle effect, with the quick-slot assignment) and garden herbs (count, description, and the profession recipes that use them, via `ProfessionDefs.recipes_using`). Descriptions come from the `description` field on `GardenDefs.POTIONS` / `GardenDefs.PLANTS`. Gathered materials and enemy drops (`SaveManager.professions.materials`: ore, hide, fish, meat, core and the wild herbs) are not shown in the bag yet; the profession panel shows the counts a recipe needs.

`DeckAutoFill.fill()` treats the highest-rarity owned copy of each template as the "primary" pick for that card and fills the whole deck from primary picks before falling back to lower-rarity duplicates of an already-represented card — so Auto-Fill favors card diversity plus best-copy-per-card over just piling in extra copies of the same name.

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

**Visual (GID-118/TID-447+):** `Chest.gd` renders as a billboard `Sprite3D`
using `SpriteRegistry.chest_closed_texture()` / `chest_open_texture()` (0x72
pack chest frames — see `docs/agent/art-sprites.md`), falling back to the
original procedural `BoxMesh` body + hinged lid + flat materials if the
registry has no art. `_ready()` reads `_opened` (already set by
`init_from_data()`, which always runs first) to pick the correct starting
texture directly — no lid-geometry timing dance needed in sprite mode.

**Open ceremony (TID-427, sprite mode):** `Chest.mark_opened()` swaps the
sprite texture to the open frame and plays a quick squash/settle scale tween
(mirroring `Player._squash_sprite`), plus the same one-shot gold
`GPUParticles3D` burst as before. `Chest.init_from_data()`'s save-restore path
for an already-opened chest just sets the open texture directly (no tween).

**Fallback mode (no sprite art):** `Chest.mark_opened()` hinges a per-instance
lid `MeshInstance3D` open (`_lid_hinge`, `TRANS_BACK`/`EASE_OUT`, 0.3s) and
darkens the body material, same as originally shipped. `_show_opened()` sets
both the lid rotation and body material instantly for save-restored chests.
The lid is built in `_ready()`, which runs *after* `init_from_data()` (Godot
calls `init_from_data` pre-`add_child`), so `_ready()` re-applies
`_show_opened()` once the lid exists if the chest was restored already-opened.

The card ID is chosen randomly from the full card pool weighted by rarity (currently uniform).

### Accessing the Inventory

The player presses `I` in the world view:
1. `WorldScene` emits `GameBus.inventory_requested`
2. `SceneManager` instantiates `InventoryScene` as a full-screen overlay
3. Closing the inventory removes the overlay and resumes the world

---

## Mailbox: Overflow Storage for Bag-Full Card Rewards (GID-110)

### The problem

Before GID-110, `add_card_instance()` returned `""` and **silently dropped** any card reward whenever `is_bag_full()` was true. Every automatic reward call site (battle wins, chest/dig/burial-mound/world-item loot, landmark discovery, achievements, pack opening, story/quest/duel rewards, siege victory) was vulnerable to silent loss with no player-facing indication.

### The fix — `grant_card_reward()` and the Mailbox overflow queue

`SaveManager.grant_card_reward(template_id, rarity, attack=-1, health=-1, cost=-1) -> String` is a drop-in replacement for `add_card_instance()` at every **automatic** reward call site (same signature, same return-a-uid contract). Instead of dropping the card when the bag is full, it appends the instance to `SaveManager.mailbox_cards: Array[Dictionary]` — a separate persisted array that never counts against `bag_size` and is not indexed in `_uid_index` until claimed — and emits `GameBus.card_routed_to_mailbox(template_id: String)` so the player gets a toast (`"<name> couldn't fit in your bag — sent to the mailbox."`, wired in `SceneManager._ready()` next to the existing `bag_full` handler).

**Player-initiated spends keep blocking as before** — `add_card_instance()` is unchanged and is still called directly by `ShopScene`, `InventoryScene` crafting, and `SaveManager.combine_cards()` (a full bag is the correct UX for a deliberate purchase/craft). Deterministic startup seeding (`new_game()`, `ensure_coop_deck()`, `adopt_session_character()`) also keeps calling `add_card_instance()` directly.

### Mailbox API (`autoloads/SaveManager.gd`)

```gdscript
SaveManager.grant_card_reward(template_id, rarity, attack=-1, health=-1, cost=-1) -> String
SaveManager.mailbox.get_mailbox_instances() -> Array[Dictionary]
SaveManager.mailbox.claim_mailbox_card(uid: String) -> bool        # false if uid missing or bag still full
SaveManager.mailbox.claim_all_mailbox_cards() -> int               # claims until full or empty; returns count claimed
SaveManager.mailbox.sell_mailbox_card(uid: String) -> void          # gold via IsoConst.RARITY_CONFIG, same as sell_card_instance
SaveManager.mailbox.scrap_mailbox_card(uid: String) -> void         # essence, same as scrap_card_instance
```

`mailbox_cards` persists in `save.json` (save version 41; migration `[41, {"mailbox_cards": []}]` backfills old saves) and round-trips through `export_session_character()`/`adopt_session_character()` for co-op session characters.

### World entity (`scenes/world/entities/MailboxNPC.gd`)

The Mailbox is a physical interactable, not a menu tab — structurally mirrors **Waystone** (own tracking dicts `_mailbox_nodes`/`_active_mailbox_data` on `WorldScene`, own interact-range check `_find_nearby_mailbox()`), not the generic NPC pipeline. It's injection-only (no `MailboxData` resource type on named-map `.tres` files): `NamedMapProps._spawn_mailbox()` places one near spawn on `madrian`, `maykalene`, `blancogov`, and `player_home` (gated on `SaveManager.home_owned` — safe to check at map-load time since home purchase always completes at the door panel before `enter_map("player_home", ...)` runs). Interacting emits `GameBus.mailbox_requested`, which `SceneManager` routes to the `MailboxScene` overlay (`State.MAILBOX`), following the same `_open_overlay()` pattern as every other world-triggered overlay (compare `bounty_board_requested`).

**Where "near spawn" actually lands.** Injected entities are invisible to the map author, so a fixed offset eventually collides with something the `.tres` does place — `spawn + (5, 0)` put the Madrian mailbox on Maiteln's exact NPC tile (45, 36). `WorldMap.pick_free_tile_near_spawn(offsets, clearance_tiles, extra_occupied)` picks instead: the first of `WorldScene.NamedMapProps.MAILBOX_TILE_OFFSETS` (tile deltas from the spawn, tried in order) that is walkable and at least `_MAILBOX_CLEARANCE_TILES` (2) from every NPC, door, chest, scroll, shrine, enemy and waystone on the map, falling back to the first merely-walkable candidate and then to the spawn tile. Waystones are passed in via `extra_occupied` from `_active_waystone_data` rather than read off `world_map.waystones`, because town maps get theirs injected too — `NamedMapProps._spawn_waystones()` runs first, so that table is the complete picture. Any future injected entity should place itself the same way.

### Overlay UI (`scenes/ui/MailboxScene.gd`)

Extends `BaseOverlay.gd`. Renders `SaveManager.mailbox.get_mailbox_instances()` as the same Diablo-3-style cube-tile grid used by `InventoryScene`'s backpack (tile/detail-popup code is duplicated, not shared, since the two scenes' action sets diverge — Claim/Sell/Scrap here vs. Add-to-deck/Combine/Rename there). Tapping a tile opens a non-modal detail popup with rolled stats and Claim / Sell / Scrap buttons; a header-level **Claim All** button drains the queue until the bag fills or it's empty. Claim is a no-op with a "Bag is full" toast when `SaveManager.is_bag_full()`.

---

## Equipment System

### Overview

The player can equip items across eight slots: **weapon**, **offhand**, **armor**, **shoulders** (GID-137: leather/iron pauldrons, spiked spaulders), **helmet** (TID-563: leather cap +3 HP, iron helm +2 armor, hooded cowl +1 mana), **boots** (TID-563: travel boots +3 HP, iron greaves +2 armor, spurred boots +1 attack), **ring**, and **trinket**. CharacterScene lays the slot buttons out two per row. Each slot holds one item ID (empty string = nothing equipped). At battle start `BattleScene.modifiers._apply_equipment_effects()` loops over every slot, resolves each item via `WeaponRegistry`, and applies its effect to `PlayerState[0]` before the opening hand is drawn. All slot types use the same `WeaponData` resource and registry — the `slot` field distinguishes them.

**Rarity & item level (GID-136 / TID-538):** every owned item has one roll, `{"rarity", "ilvl"}`, in
`SaveManager.gear_rolls` (keyed by item id; missing = common, ilvl 1, so no migration). Rarities reuse the card
ones (common / rare / epic / legendary, `UiUtil.rarity_color`). `GearRolls.mult(roll)` = rarity multiplier
(1 / 1.25 / 1.5 / 2) × (1 + 2 % per item level above 1) feeds `UpgradeDefs.effective_stat(weapon, level, mult)`
(rounded, never below the base value) — battle effects (`BattleModifiers._apply_equipment_effects`, real-time
off-hand damage) and every display string (`get_display_string(…, mult)`). Sources: chests
(`ChestLoot._maybe_drop_equipment(chance, tier, level)` — rarity weights by chest tier, item level = zone level
on the overworld, else the player's level; 30 % of drops re-roll an owned item), victory weapon rewards (enemy
difficulty tier, enemy level), shop purchases (common at your level) and quest turn-ins with a `gear_choice`
(pick one of three, a rare roll at quest level + 1; `SaveQuests.turn_in(id, pick)`, the turn-in panel shows the
three items with their rolled stats). `SaveManager.gear.grant(id, roll)` adds a new item or keeps the better roll
("new" / "upgraded" / "kept"); an upgrade to an equipped item emits `equipment_changed`. CharacterScene colours
item names by rarity and shows "Rare · ilvl 7". Co-op session characters (BID-033) carry their own `gear_rolls`,
and need/greed loot is rolled on the authority (BID-075).

**School affixes (GID-181 / TID-754):** a roll may also carry `"affix": {"kind", "school", "pct"}`, on top of the
rarity and item level (never replacing them). Kinds: `school_dmg` (outgoing power for that school),
`school_resist` (a hero resist fraction) and `convert` (weapons only: the auto-attack and Strike hit as that
school). `GearRolls.roll(tier, level, rng, weapon)` rolls it by tier; `SaveGear.roll_for(item, tier, level, rng)`
is the drop entry point and passes `weapon` from the item's slot. The affix rides in `gear_rolls`, so
`normalize` drops a malformed one and an old save reads as no affix (no migration). `GearRolls.affix_label`
names it in the CharacterScene gear picker and in `SaveGear.drop_message`. Battle effects are read in
`BattleSetup.apply_school_power` and `school_resist_sources`; see `damage-schools.md`.

**Visuals (GID-137):** equipping emits `GameBus.equipment_changed(slot, id)` and the hero sprite redraws in the new gear. Every armour/shoulders/helmet/boots/weapon/offhand/trinket item needs a `PaperDoll.GEAR_VISUALS` entry (see `camera-and-player.md` → Paper-doll hero); rings are not drawn.

Mana cap invariant: max_mana never permanently exceeds 10. The `starting_mana` effect grants a one-time turn-1 burst; `PlayerState.gain_mana_for_turn(turn)` resets `max_mana = min(10, turn)` on every subsequent turn, naturally undoing the boost.

If multiple equipped items inject cards, all injections happen first and the deck is shuffled once at the end.

### WeaponData Resource (`data/WeaponData.gd`)

All equipment types share this resource class.

| Field | Type | Purpose |
|---|---|---|
| `id` | String | Unique identifier (matches filename without `.tres`) |
| `display_name` | String | Human-readable item name |
| `description` | String | Flavour / tooltip text |
| `slot` | String | `"weapon"` \| `"offhand"` \| `"armor"` \| `"ring"` \| `"trinket"` (default `"weapon"`) |
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
| `starting_armor` | Grants `battle_effect_value` armor (`hero.apply_status("armor", value)`) at battle start. Shares the single `"armor"` status key with the Maiteln companion's `hero_armor` passive — whichever applies later (equipment before companion) overwrites rather than stacks. |
| `offhand_atk` (off-hand slot only, GID-135 / TID-545) | **Real time:** sets `RealtimeCombat.offhand_damage[PLAYER]` to `battle_effect_value` — the off-hand swings on its own `offhand_swing` `CombatTuning` timer, independent of the main hand. **Turn-based:** there is no off-hand swing timer, so it instead adds a smaller always-on bonus, `UpgradeDefs.offhand_turnbased_bonus(value)` = `max(1, value / 2)`, to `hero.attack` for the whole fight. `BattleModifiers._apply_equipment_effects` picks the turn-based path only when `battle_mode` doesn't start with `"realtime"`, so the two never double-count. |

### SaveManager Equipment Fields

| Field | Type | Description |
|---|---|---|
| `equipped_weapon` | String | ID of currently equipped weapon (`""` = none) |
| `equipped_armor` | String | ID of currently equipped armor |
| `equipped_ring` | String | ID of currently equipped ring |
| `equipped_trinket` | String | ID of currently equipped trinket |
| `equipped_offhand` | String | ID of currently equipped off-hand item (GID-135 / TID-545) |
| `owned_weapons` | Array[Dictionary] | Weapon instances: `{weapon_id: String, upgrade_level: int}` (GID-052) |
| `owned_armor` | Array[String] | All armor IDs owned |
| `owned_rings` | Array[String] | All ring IDs owned |
| `owned_trinkets` | Array[String] | All trinket IDs owned |
| `owned_offhands` | Array[String] | All off-hand item IDs owned — plain strings like armor/ring/trinket, no upgrade-level dict (off-hand items don't upgrade) |

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

### Built-in Off-Hand Items (GID-135 / TID-545)

| ID | Effect |
|---|---|
| `parrying_dagger` | `offhand_atk` 4 — off-hand swing damage in real time; +2 hero attack in turn-based |
| `buckler` | `starting_armor` 5 — 5 armor at battle start, both modes |
| `arcane_focus` | `starting_mana` 1 — reuses the existing mana-bonus effect, both modes |

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
| **WeaponRegistry** | Data source | Resolves `WeaponData` by id from `data/weapons/`; used by `BattleScene.modifiers._apply_equipment_effects()`; `get_by_slot()` filters by slot for CharacterScene pickers |
| **Chest entity** | Card source | `Chest.gd` calls `SaveManager.add_card()` on open; marks chest ID in `SaveManager.opened_chests` |
| **GameBus** | Signal | `inventory_requested` opens the overlay; `chest_opened(card_id)` delivers card drops |
| **SceneManager** | Overlay router | Instantiates and removes `InventoryScene` in response to `GameBus.inventory_requested` |

---

## Endless Spire: Run-Local Deck Isolation

> **GID-142:** the Spire is now per-biome **rifts** with tier ladders — see `docs/agent/rifts.md`. Sections below describe the original Endless Spire machinery the rifts are built on.

During an Endless Spire run the player's battle deck is separate from their persistent `player_deck`. It is built up by drafting cards after each floor victory.

### How it works

- `SaveManager.spire_run.draft_deck` is a plain `Array` of card IDs accumulated via `add_drafted_card(id)`.
- `BattleScene._ready()` checks `SaveManager.spire.is_spire_active()` first:
  - If active and `draft_deck` is non-empty → build deck from `draft_deck`.
  - If active and `draft_deck` is empty (floor 1, before first draft) → use an 8-card starter (`ghost×2, skeleton×2, zombie×2, ghoul×2`).
  - If not active → fall through to the normal `player_deck` path.
- The persistent `player_deck` is never modified during a Spire run.

### Draft pick flow

After each floor victory `SceneManager._show_spire_draft(floor)` instantiates `SpireDraftScene` and parents it to the live `WorldScene`:

```gdscript
var draft := preload("res://scenes/ui/SpireDraftScene.tscn").instantiate()
add_child(draft)
draft.setup(floor_number)
draft.picked.connect(_on_draft_picked)
```

It is only ever called from `_restore_world(after)`'s post-swap callback — see the Draft integration section of `named-maps-and-dungeons.md` for why parenting it inline after a `_restore_world()` call silently destroys it.

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

## Deck Loadouts (GID-058)

The player can maintain up to **5 named deck loadouts** instead of a single deck.

### Data model (`SaveManager`)

| Field | Type | Notes |
|---|---|---|
| `loadouts` | `Array[Dictionary]` | Up to `MAX_LOADOUTS` (5) entries, each `{name: String, cards: Array[String]}` |
| `active_loadout` | `int` | Index into `loadouts`; 0-based |
| `player_deck` | `Array[String]` | Always mirrors `loadouts[active_loadout].cards` — kept in sync |
| `MAX_LOADOUTS` | `const int = 5` | Maximum named loadouts |

`player_deck` is the canonical active deck as before — all existing call sites (BattleScene, InventoryScene, SceneManager) continue reading/writing it unchanged. After any change that modifies `player_deck`, the active loadout's cards array is synced. When the active loadout changes, `player_deck` is synced from it.

### Save migration

Version 33 → 34: `_migrate_v33_to_v34()` wraps the existing `player_deck` into `loadouts = [{"name": "Deck 1", "cards": existing_deck}]` with `active_loadout = 0`. Old saves load cleanly with no data loss.

### Pruning on card removal

`remove_card_instance(uid)` now iterates all loadout cards arrays and removes the uid from each, not just from `player_deck`. This means selling/scrapping/combining a card removes it from every loadout that referenced it.

### Validation

`is_loadout_valid(index)` returns true iff `loadouts[index].cards.size()` is in `[DECK_MIN, DECK_MAX]`. An invalid active loadout blocks battle engagement via the existing SceneManager size check (which reads `player_deck.size()`).

### Loadout CRUD API

```gdscript
SaveManager.decks.set_active_loadout(index: int) -> bool    # switches and syncs player_deck
SaveManager.decks.add_loadout(name: String) -> int          # returns new index, or -1 if at cap
SaveManager.decks.rename_loadout(index: int, new_name: String) -> void
SaveManager.decks.duplicate_loadout(index: int) -> int      # returns new index, or -1 if at cap
SaveManager.decks.delete_loadout(index: int) -> bool        # false if last loadout
SaveManager.decks.get_loadout_names() -> Array[String]
SaveManager.decks.is_loadout_valid(index: int) -> bool
```

### Loadout UI (`InventoryScene.gd`)

A **loadout tab row** and **action row** sit above the `_deck_count_label` in the deck panel.

**Tab row** (`_loadout_tab_row: HBoxContainer`):
- One flat `Button` per loadout, built by `_rebuild_loadout_bar()` from `_refresh_cards()` — skipped when the tab signature (names, active index, validity, size) is unchanged (GID-164 / TID-684).
- **Refresh cost (TID-684):** bag tiles are reused across refreshes through `scenes/ui/inventory/TileCache.gd` (detached before the old grid is freed; rebuilt only when the instance hash, deck tag, selection, select mode, face or size changes; swept when no longer shown); search refreshes 0.15 s after typing pauses (`_search_timer`); `_template()` reads the cached read-only `CardRegistry.get_template_view`. Covered by `tests/inventory_tiles_smoke.gd` (in CI).
- Active tab: `modulate = Color.WHITE`; inactive: `Color(0.7, 0.7, 0.7)`.
- Invalid loadout (< DECK_MIN or > DECK_MAX): red tint (`Color(1.0, 0.35, 0.35)` active, darker for inactive). The active tab uses `_working_deck.size()` so it reflects in-flight edits immediately.
- "+" button appended after the tabs; `disabled = true` when at `MAX_LOADOUTS` (5).

**Action row** (`_loadout_action_row: HBoxContainer`): Rename / Copy / Delete buttons always visible.
- Delete: `modulate = Color(1.0, 0.4, 0.4)`, `disabled = true` when only one loadout remains.
- Copy: `disabled = true` when at cap.

**Tab switching** (`_on_loadout_tab(index)`): auto-saves the current `_working_deck` to the active loadout via `sm.set_active_deck()` before switching, so in-progress edits are preserved.

**Rename popup** (`_on_rename_loadout()`): `PopupPanel` with a `LineEdit` (max 20 chars), positioned in the top half of the screen (`position.y = viewport_h * 0.08`) so the Android virtual keyboard doesn't cover it. `grab_focus()` is called to trigger the keyboard on Android.

**Delete popup** (`_on_del_loadout()`): `PopupPanel` confirmation with "Yes, Delete" / "Cancel". Guard: function returns early if only one loadout remains (button is also `disabled`), so the last loadout can never be deleted.

### Matchup Swap Row (TID-756)

Before a fight, the saved loadouts are ranked against the enemy's known weak schools
(`game_logic/battle/LoadoutMatchup.gd`, pure). `scenes/ui/LoadoutSwapRow.gd` draws them as a row of
buttons: the best match starred and tinted, the active loadout and too-small ones disabled, and the
enemy's weak schools as colour chips. A tap calls `SaveManager.decks.set_active_loadout(i)`, so the next
battle uses that deck. The row appears in the gambit picker (`GambitPickerOverlay`) and, with gambits
auto-skipped, in a world "Swap deck" modal (`scenes/world/modules/SwapDeckPrompt.gd`). The deck builder
itself is unchanged. Full rules in `docs/agent/damage-schools.md` ("Matchup Loadouts").

---

## Veterancy System (GID-060)

Each owned card instance tracks battle memory: `kills`, `battles_survived`, and `custom_name` are persisted alongside the existing instance fields in `SaveManager.owned_cards`.

### Data model

New fields on every `owned_cards` Dictionary entry (save version 35):

| Field | Type | Description |
|---|---|---|
| `kills` | int | Total enemy minions this card has killed in battle |
| `battles_survived` | int | Battles this card has participated in and survived |
| `custom_name` | String | Player-set rename (`""` = none) |

`_migrate_v34_to_v35()` backfills all three fields with defaults (`0`, `0`, `""`) on old saves. `add_card_instance()` initialises them to those defaults on new cards.

### Rank thresholds (`IsoConst.VETERANCY_RANKS`)

Rank is OR-based: earned when `kills >= kills_threshold` **or** `battles_survived >= battles_threshold`. Stat bonuses are cumulative totals at that rank.

| Rank | Kills | Battles | HP Bonus | ATK Bonus | Title |
|---|---|---|---|---|---|
| 1 | 5 | 10 | +1 | +0 | "the Seasoned" |
| 2 | 15 | 25 | +2 | +1 | "the Veteran" |
| 3 | 40 | 60 | +3 | +2 | "the Legendary" |

### VeterancyUtil (`game_logic/VeterancyUtil.gd`)

Pure static helper (no class_name, no autoload deps). Preload directly at call sites:

```gdscript
const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")

var rank: int = VeterancyUtil.rank_for(kills, battles_survived)       # 0–3
var title: String = VeterancyUtil.title_for(rank)                     # "" if rank 0
var hp_bonus: int = VeterancyUtil.hp_bonus_for(rank)
var atk_bonus: int = VeterancyUtil.atk_bonus_for(rank)
var name: String = VeterancyUtil.display_name(inst, base_name)
```

`display_name` precedence: `custom_name` (if non-empty) → `"base_name the Title"` (rank ≥ 1) → `base_name`.

`rank_chevrons(rank)` returns `""`, `"▲"`, `"▲▲"`, or `"▲▲▲"` for use in UI labels.

`SaveManager.set_card_custom_name(uid, name)` — stores a player rename on the live instance dict (strips edge whitespace, caps at 24 chars, marks dirty). Empty string clears the custom name.

### Attribution (TID-216)

After a won battle, `kills` made by each player deck card and `battles_survived` are written back to the matching collection instance via its `collection_uid`. Lost battles grant nothing. The `collection_uid` field is threaded through `CardInstance` so mid-battle save/resume (GID-034) does not lose attribution.

### Inventory UI (TID-217)

Veterancy is visible in `InventoryScene` for rare/epic/legendary cards (per-instance rows):

- **Display name** — `_make_collection_row_instance` and `_make_deck_row_instance` show `VeterancyUtil.display_name(inst, card_name)` in the name Label instead of the raw template name, so custom renames and earned titles appear immediately.
- **Rank chevrons** — if `rank > 0`, a golden `▲`/`▲▲`/`▲▲▲` Label appears after the name in the top row.
- **Rename button** — `"✏ Rename"` Button in the action row (collection rows only) toggles an inline rename panel containing a `LineEdit` (pre-filled with current custom_name, max 24 chars), Save, and ✕ Cancel. Tapping Save calls `set_card_custom_name` then `_refresh_cards()`.

### Battle card name (TID-217)

`PlayerState.build_deck_from_instances` sets `ci.name = VeterancyUtil.display_name(inst, tmpl_name)` on each CardInstance before adding it to the deck. The `name` field round-trips through `CardInstance.to_dict()`/`from_dict()`, so the titled/custom name appears in the battle card face (`NameLabel`) and persists through mid-battle save/resume without any change to `BattleScene`.

---

## Deck Builder QoL: Filters & Auto-Fill (GID-069 TID-253)

### Collection filters

A horizontal row of toggle buttons above the collection scroll lets the player narrow the card list. Filters are session-only state; no SaveManager field is needed.

**Filter dimensions (AND across groups, OR within):**

| Group | Buttons | State var | Discriminator |
|---|---|---|---|
| Card class | All / Minion / Spell | `_filter_class: String` | `CardData.card_class` (`""` = spell via `spell_effect != ""`) |
| Mana cost | All / 0-2 / 3-5 / 6+ | `_filter_cost: String` | `CardData.cost` |
| Rarity | All / C / R / E / L | `_filter_rarity: String` | Instance rarity or template rarity |

`_passes_filter(tid, rarity) -> bool` checks all three active filters against the card template returned by `CardRegistry.get_template(tid)`. An empty string value means "All" (no filter).

Pressing the already-active button toggles it off (`_filter_x = "" if _filter_x == val else val`), allowing quick deselection.

### Auto-Fill button

An **Auto-Fill** button sits below the deck count label in the deck panel. It calls `DeckAutoFill.fill(working_deck, available, target)` and writes the result back to `_working_deck` then to `SaveManager.set_active_deck()`.

**Disabled when:** `available` cards can't bring the deck to `IsoConst.DECK_MIN`.

### DeckAutoFill (`game_logic/DeckAutoFill.gd`)

Pure static file. No class_name, no autoload deps. Preload at call sites:
```gdscript
const DeckAutoFill = preload("res://game_logic/DeckAutoFill.gd")
```

`fill(working_deck: Array[String], available: Array[Dictionary], target_size: int) -> Array[String]`:
- Returns a new working deck extended up to `target_size` (capped at `DECK_MAX`).
- Does not modify inputs — returns a copy.
- Heuristic: rarity-first (legendary > epic > rare > common), then mana-curve balancing: among equal-rarity candidates, pick the card whose cost bucket (low/mid/high) is most under-represented in the current deck.
- Respects ownership: never adds more copies of an instance than exist in `available`.
- Skips instances already in `working_deck`.
- Deterministic for a given sorted input (no RNG).

**Mana buckets:** `"low"` = cost 0–2, `"mid"` = 3–5, `"high"` = 6+. Instance cost falls back to template cost when `cost == -1`.

**Tests:** `tests/unit/test_deck_autofill.gd` — 7 tests covering fill-to-min, no-exceeds-target, no-duplicates, skips-existing, rarity-preference, already-at-target, empty-available.

---

## Dual-Faced Card Indicator (GID-062)

`InventoryScene` resolves each card's display face using `CardRegistry.is_dark_aligned()` (same helper used at battle start). For dual-faced cards the collection and deck rows show the face matching current alignment, plus a `◑` badge in blue-teal (`Color(0.6, 0.85, 1.0)`) in the top-right of the card name row.

- The `◑` badge is added to `top_row` by all four card-row builders (`_make_collection_row_stacked`, `_make_collection_row_instance`, `_make_deck_row_stacked`, `_make_deck_row_instance`) when `str(tmpl.get("dual_card_id", "")) != ""`.
- Templates are fetched via `CardRegistry.get_template_for_face(tid, face)` (replaces the old `get_template(tid)` call in these four builders).
- Rank chevrons and the `◑` badge coexist in the top row: chevrons first, then the dual badge.

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

---

## Deck Table (GID-180)

Deck building and bag management as a tactile "card table" — see `tasks/goals/GID-180--deck-table/goal.md`.
Selling happens **only at vendors**; the bag offers Scrap and "flag for sale".

### DeckInsights (`game_logic/inventory/DeckInsights.gd`, TID-736)

Pure statics over card instances plus an optional `templates` table (empty → `CardRegistry`), so tests pass a
hand-built table. Used by the deck table header, binder, compare popup and Maiteln's deck barks.

| Function | Returns |
|---|---|
| `mana_curve(instances)` | `Array[int]` buckets 0..`CURVE_MAX` (7+ share the last bar) |
| `dominant_branch` / `branch_counts` | most common `magic_branch` (ties alphabetical, "" if none) |
| `archetype` | `bulwark` (≥30 % ward), `rush` (≥30 % surge), `titans` (avg cost ≥4.5), `tempo`/`grimoire` (≥60 % spells, cheap/dear), `swarm` (avg ≤2.5), else `host` |
| `deck_name` | `BRANCH_WORDS[branch] + ARCHETYPE_NOUNS[archetype]`, e.g. "Bone-Choir Swarm"; "Empty Deck" |
| `crest` | `{color, glyph (archetype), branch, rarity (average tier)}` |
| `synergy_pairs` | ≤12 links `{a, b, kind: keyword|branch, tag}`: cards of one tag **chained** in deck order (one per template), keyword links first, keyword-linked cards skip branch links |
| `sample_hand(insts, n, seed)` | every technique + `n` shuffled others (like a real-time opening hand) |
| `roll_quality` / `is_perfect_roll` / `has_roll_range` | 0..1 position in the rarity's `RARITY_CONFIG` variance band; perfect = top of every variable stat (commons never) |
| `compare(a, b)` | stat deltas a − b incl. rarity tier |
| `power_score` / `replace_target` / `is_upgrade` | rarity tier, then atk+hp, then cheaper; upgrade = beats the weakest same-template deck copy |

### Card table layout (TID-737)

- Binder (bag grid) left / top; **deck pile** right (landscape) or below (portrait): `scenes/ui/inventory/DeckPile.gd`,
  a pure view (header: count, ↶ Undo, ★ Best deck; `loadout_slot` for the loadout tabs; deck as `CardTile`s at
  `TILE_SCALE` 0.78). InventoryScene wires each deck tile in `_decorate_deck_tile`: tap = take out, hold = inspect,
  sideways drag = back to the binder.
- **No Save Deck button.** Every change goes through `_edit_deck(next)`: snapshot into `DeckUndo`
  (`game_logic/inventory/DeckUndo.gd`, cap 20, duplicate snapshots skipped), then `set_active_deck`. Undo = button or
  Ctrl/Cmd+Z (Cards tab only). Switching loadout clears the undo stack. Scrap/combine/sell call `_prune_working_deck()`.
- Class/cost/rarity filters fold behind the toolbar's **Filters** toggle (shows "•" while a filter is active).
- Tests: `tests/unit/test_deck_undo.gd`; `tests/inventory_tiles_smoke.gd` checks auto-save + undo.

### Card juice (TID-738)

`scenes/ui/inventory/CardJuice.gd` (statics) gives every deck-table surface the same feel:
`drag_preview` (a `DragCardPreview` — lifted ×1.08 mini card over a soft shadow, tilting toward the drag direction),
`sparkle` (one-shot `CPUParticles2D`, count/size by rarity tier), `pop` (TRANS_BACK scale punch), `shimmer`
(looping `self_modulate` glow on legendary tiles, idempotent via meta, tween dies with the tile) and `sound`
(`pick` / `place` / `return` / `shuffle` over `card_draw` / `card_play` takes with pitch jitter).
InventoryScene: a drag start plays `pick` + sparkles; `_edit_deck` calls `DeckPile.land(uid)` (tile bounce, sparkles,
count thump) and `place` / `return`. CardJuice names `AudioManager`, so `-s` tools must `load()` it at runtime
(`tools/capture_inventory.gd` `DRAG=1` does). No hum loop for legendaries: the visual shimmer only, a looping sound in
a menu got tiresome on paper.

### Binder (TID-739)

- **Pages**: tab row `All · Light · Dark · Verdant · Rift · Neutral` (`BinderOps.PAGES`; page = template `magic_type`,
  else neutral). A magic-type page shows "Found X / Y" and **silhouettes** (`CardTile.build_silhouette`: dark art,
  "?", no foil) of collectable templates the player owns no copy of — techniques and `coop_` cards excluded
  (`_collectable_ids`). Tapping one says how to get it (Craft tab if craftable). Silhouettes hide while searching,
  filtering, selecting or browsing one stack.
- **Stacks**: `BinderOps.stack(insts, membership)` groups template+rarity copies in display order; `best` = strongest
  copy (`DeckInsights.power_score`) preferring one in no deck. The tile shows the best copy plus an "×N" pill
  (`CardTile.add_count`); tap adds the best copy. The detail popup's **All N copies** button sets `_expand_key`
  (one stack's copies, best first, with "‹ Back to binder"). Select mode always shows single copies.
- **Perfect roll**: gold ✦ (`CardTile.add_perfect_mark`, twinkled by `CardJuice.twinkle`) when
  `DeckInsights.is_perfect_roll`. **Veterancy gilding**: bronze / silver / gold edge by rank (`CardTile._gild`).
- Filters + page state live in `scenes/ui/inventory/BagFilters.gd` (moved out of InventoryScene).
- `tools/capture_inventory.gd` `PAGE=dark` captures a page.

### Deck personality (TID-740)

`DeckPile` now opens with a `DeckIdentity` row: crest (`DeckInsights.crest` — branch colour, archetype glyph from
`DeckIdentity.GLYPHS`, border = average rarity), the generated name (TitleLabel; pops + sparkles when it changes) and a
`CurveSkyline` (one lit building per cost bucket, heights ease to the new curve). The deck grid shares a
MarginContainer with `SynergyThreads`, which draws pulsing lines between `synergy_pairs` tiles (keyword = gold, branch =
branch colour). **✋ Try a hand** opens `TestHandOverlay`: shuffle sound, `sample_hand` with
`CombatOnboarding.opening_hand(level)` draws, cards dealt one by one; "Shuffle & draw again" reseeds.
`tools/capture_inventory.gd`: `ADD=<n>` fills the deck, `HAND=1` opens the overlay.

### Compare + Best deck (TID-741)

- **▲ upgrade mark** (`CardTile.add_upgrade_mark`) on binder tiles where `DeckInsights.is_upgrade(inst, deck)`.
- **Compare by hovering**: deck tiles take drops (`_make_card_draggable` now forwards `can_drop`/`drop`). A bag copy
  of the same template held over a deck tile shows `_compare_tip` (⚔ / ♥ / mana / tier diffs, green ▲ better, red ▼
  worse; mana is better when lower); dropping swaps them (`_swap_in`). Other cards dropped on a deck tile just join
  the deck. The tip hides on `NOTIFICATION_DRAG_END`.
- **Tap path**: the detail popup shows the same diff vs `replace_target` and a **⇄ Swap into deck** button
  (gold when it is an upgrade).
- **★ Best deck** (`_on_auto_fill`): first `DeckInsights.upgrade_swaps` (each deck card → strongest unused bag copy
  of its template that beats it), then `DeckAutoFill.fill` to the same target as before; HUD line reports
  "N upgraded, M added". `DeckAutoFill` now picks the primary copy by `power_score` (rarity, then roll).

### Forge, combine ritual, flag for sale (TID-742)

**Selling happens only at vendors.** The bag has no Sell: the detail popup offers **For sale (Ng)** (toggle) and
**Scrap**, bulk Select offers **For sale** and **Scrap**; `MailboxScene` lost its Sell button and
`SaveMailbox.sell_mailbox_card` is gone.

- `SaveManager.for_sale_uids` (persisted): `toggle_for_sale(uid)` (deck and unique cards refuse), `is_for_sale(uid)`.
  `remove_card_instance` and `set_active_deck` prune it. Flagged tiles carry a "For sale" tag.
- **Forge**: a drop zone under the binder (`_forge`). A bag card dropped there scraps at once (commons/rares) or after
  the bulk confirm (epic+). Every scrap goes through `_forge_scrap(uid, from_rect)`: `ForgeFx.burn` (ember tint,
  shrink, fade, `burn` sound, essence motes flying to the wallet) then `scrap_card_instance`.
- **Combine ritual**: the popup's Combine runs `_combine` → `combine_cards` → `CombineRitual` overlay (three copies
  orbit and spiral in, white flash, the new card lands big with sparkles and "Forged a Rare Ghost!"; tap or 2.2 s
  closes). `tools/capture_inventory.gd COMBINE=ghost`.

### Module map (deck table)

InventoryScene coordinates; views live in `scenes/ui/inventory/`: `DeckPile` (deck side), `LoadoutBar` (loadout tabs +
Rename / Copy / Delete; emits `switched` / `loadout_renamed`, host reloads `_working_deck`), `DeckIdentity`,
`CurveSkyline`, `SynergyThreads`, `BagFilters`, `CardTile`, `CardJuice`, `DragCardPreview`, `CompareTip`
(`rows()` shared with the detail popup), `ForgeFx`, `CombineRitual`, `TestHandOverlay`. Pure rules in
`game_logic/inventory/`: `DeckInsights`, `BinderOps`, `DeckUndo`, `BagOps`.

### Never-lost loot + satchel (TID-743)

- Audit (GID-180): every automatic reward already goes through `grant_card_reward` (mailbox overflow). The remaining
  `add_card_instance` callers are the new-game / co-op starter decks (empty bag), `combine_cards` (frees 3 slots
  first), and player spends that intentionally block on a full bag (ShopScene buy, CraftPanel craft).
- `scenes/ui/inventory/Satchel.gd` replaces the "Bag X/Y" text: a drawn leather satchel whose fill rises with use,
  bulges at ≥ 90 % with cards poking out (3 at full), "used/cap  ✉N" (N = waiting mailbox cards); tap = hint line.
- `game_logic/inventory/SatchelLines.gd`: `line(kind, companion, n, card_name)` ("full" / "mailbox"; Maiteln's voice
  when the companion is learned and active, else the satchel), `fullness(used, cap)` 0–3.
  `SceneManager` routes `GameBus.bag_full` / `card_routed_to_mailbox` through it (`_grumbler()`, rotating `_grumbles`).

### Maiteln's deck barks (TID-744)

`game_logic/inventory/DeckBarkRules.gd` mirrors the battle `BarkRules`: `LINES` + `ORDER` (too_small, top_heavy
(≥ 35 % cost 5+), no_early (< 3 cards at cost ≤ 2), no_allies, no_spells, upgrade (a bag copy beats a deck copy),
synergy (≥ 2 keyword links), full), `candidates(deck, bag)` (techniques ignored), `next_bark(cands, last_id,
since_last_s)` (top candidate that isn't the last line, ≥ `MIN_INTERVAL_S` 6 s apart) and `is_eligible` (Maiteln is the
active companion, or the companion system isn't learned yet — he's the starter mentor). InventoryScene calls
`_maybe_bark()` on open and after each deck edit; `DeckPile.say()` shows the parchment bubble for ~6 s (it fades but
keeps its space so the grid doesn't jump).

### Vendor counter (TID-745)

`ShopScene` has **Buy / Sell** tabs. Sell is `scenes/ui/shop/VendorCounter.gd`: the vendor's speech line, a wooden
counter (drop zone) with a `CoinPile` (drawn coins that drop in) and "+Ng this visit", a **Sell basket: N cards +Xg**
button (every `for_sale_uids` card) and the sellable cards below (bag, in no deck, not unique; flagged first, gold
price pill via `CardTile.add_price`). Tap or drag a card onto the counter: a copy slides across and fades, the vendor
reacts (`game_logic/inventory/VendorReactions.gd`: perfect → legendary/epic → preferred → veteran → duplicate (sold
this visit) → plain; rotating lines), coins drop, `SaveManager.sell_card_instance(uid, gold)` (optional price for
vendor bonuses). `price_for` / `prefers` are Callables the shop sets (TID-746). `tools/capture_inventory.gd`
`SCENE=shop TAB=1 FLAG=4 SELL=1`.

### Vendor tastes + buyback (TID-746)

- `game_logic/inventory/VendorPrefs.gd`: `TOWNS` (madrian → Light, maykalene → Rift, blancogov → Verdant, larik → Dark,
  marsax_hold → Neutral), `town_of(place)` (town or `<town>_interior`), `prefers`, `price` (+`BONUS` 25 %), `pitch`
  ("Maykalene's dockmaster pays +25% for Rift cards."). `VendorCounter.setup(ref, place)` builds `price_for` /
  `prefers` from it; favoured cards get the "preferred" reaction.
- The shop's `town_name` is now the **story place** (`WorldScene.story_place()`), not `current_map` (which is `main`
  in the stitched towns — BID-096), so the siege discount works there too.
- **Buyback shelf**: `SaveManager.buyback_cards` (persisted, newest first, `BUYBACK_CAP` 8, each with `_sold_for`);
  `sell_card_instance` shelves a copy, `buy_back(index)` returns the exact card (uid, rolls, history) for what it sold
  for (needs coins and bag room). Shown on the counter as small priced tiles.
- **Ally stock (TID-770):** the town shop sells every unlocked, non-signature card regardless of town, so the
  verdant and rift Allies are sold in all towns. Vendor tastes change only the sell price (Verdant at Blancogov,
  Rift at Maykalene). The traveling merchant's premium `_MERCHANT_CARD_POOL` carries the four cost-5 Allies.

### World loop: new cards, HUD badge, campfire (TID-747)

- `SaveManager.new_card_uids` (persisted): every card entering the bag (`add_card_instance`, `grant_card_reward`
  bag path) is marked via `_mark_new` → `GameBus.new_cards_changed(count)`; starter decks clear it;
  `remove_card_instance` prunes; `mark_cards_seen()` clears (InventoryScene `_exit_tree`).
- Binder tiles of new cards carry a "✦ NEW" tag and a green-gold pulse (`CardJuice.new_glow`).
- `scenes/world/BagBadge.gd` (owned by WorldHUD, set up on the Menu/Bag button): red count badge; a count rise while
  the world is up flies little card backs from the screen centre into the button. Rewards granted during a battle
  (world detached) are caught up 0.8 s after the HUD re-enters the tree (after the transition wipe).
- Dungeon/cave **rest-site campfires** (`DungeonSessionUI.show_rest_site_panel`) offer **Tend your deck by the fire**
  (opens the deck table) — also at a used fire, where Rest / Cull are disabled instead of the panel refusing.
