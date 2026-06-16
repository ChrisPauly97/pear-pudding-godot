# Enemies and NPCs

## Key Features

- Four overworld enemy types with escalating difficulty, each carrying a specific deck composition
- Enemy type selection driven by biome and distance from the world origin
- Mixed engagement: aggressive enemies (`undead_elite`, `ghoul_pack`, `roaming_terror`) attack on proximity via Area3D; wanderers (`undead_basic`, `undead_horde`) wait for player interaction
- Interact-to-engage works on all enemies via E key / interact button regardless of tracking mode
- Defeated enemies are persisted in `SaveManager` so they do not respawn on reload
- Town-person NPCs are static, non-hostile, and display biome-flavoured dialogue on interaction
- **Boss system**: `is_boss` flag on `EnemyData` triggers enhanced battle presentation, optional phase-2 deck swap at 50% HP, and guaranteed full drop_pool rewards

---

## How It Works

### Enemy Types (`autoloads/EnemyRegistry.gd`)

`EnemyRegistry` is an autoload that loads all `EnemyData` resources from `data/enemies/*.tres` at startup and exposes `get_enemy(type_id)` and `type_for_biome(biome, distance)`.

| Type ID | Deck | Coin reward | Intended zone |
|---|---|---|---|
| `undead_basic` | 4× Ghost + 4× Skeleton | 5 | Early game (grasslands, close to origin) |
| `undead_horde` | 4× Skeleton + 4× Zombie | 8 | Mid game (forest, medium distance) |
| `ghoul_pack` | 4× Zombie + 4× Ghoul | 12 | Late game (desert, scorched, far) |
| `undead_elite` | 8× Ghoul | 20 | End game (mountains, very far) |

`type_for_biome()` uses a distance threshold table per biome to return the appropriate type ID:

```gdscript
# Example (simplified)
func type_for_biome(biome: String, distance: float) -> String:
    match biome:
        "grasslands": return "undead_basic" if distance < 200 else "undead_horde"
        "forest":     return "undead_horde" if distance < 300 else "ghoul_pack"
        "scorched":   return "ghoul_pack"   if distance < 400 else "undead_elite"
        "mountains":  return "undead_elite"
        _:            return "undead_basic"
```

### EnemyData Resource

Each `data/enemies/<type>.tres` stores:
- `id: String` — matches the type ID key above
- `display_name: String`
- `deck: Array` — card ID strings (converted to `Array[String]` with `assign()` on load)
- `drop_pool: PackedStringArray` — cards that can drop on defeat
- `coin_reward: int` — coins awarded on victory
- `is_boss: bool` — enables boss battle presentation (default false)
- `boss_hp: int` — override enemy hero HP (0 = default 30)
- `phase2_deck: PackedStringArray` — if non-empty, swapped in when enemy HP ≤ 50%

### Boss Battle Framework

When `is_boss` is true in the engaged `enemy_data` dict, `BattleScene` applies:

1. **HP override**: sets enemy hero HP to `boss_hp` (if `boss_hp > 0`)
2. **Boss banner**: fading label showing the enemy's display name at the top of the screen for 2.5 s
3. **Enemy name**: shows the boss's display name in the hero panel instead of "ENEMY"
4. **Phase 2**: when enemy HP first drops to ≤ 50%, discards enemy hand, rebuilds draw deck from `phase2_deck`, draws 4 cards, shows "PHASE 2" banner
5. **Full drop**: on victory, drops all cards in `drop_pool` (emits `{"card_rewards": [...]}` instead of `{"card_reward": "..."}`)

`EnemyNPC` in the world scene: boss enemies render at 1.3× scale with gold materials to distinguish them visually. Roaming boss enemies (type `roaming_terror`) render at 1.5× scale with crimson materials; see **Roaming Boss** below.

### Roaming Boss (`roaming_terror`)

Spawned by `WorldEventManager` via `game_logic/WorldEvents.gd` on a 15–25 minute randomised interval of overworld play. Only one event fires at a time (WorldEventManager single-active rule).

**Spawn:** `WorldEvents._spawn_roaming_boss()` calls `WorldEventManager.find_spawn_tile()` to find a walkable grass tile 20–40 world-units from the player, instantiates `EnemyNPC.tscn` with `is_roaming_boss=true` (crimson 1.5× visual), registers it in `WorldScene._enemy_nodes` under the ID `"roaming_boss"`, and emits a HUD toast "A powerful presence approaches…".

**Minimap:** The boss appears as a bright-red dot (radius 7, vs. 4 for regular enemies). When the boss is outside the minimap radius, a faded edge indicator points toward it.

**Despawn conditions (whichever comes first):**
- Player defeats it in battle → `SceneManager._on_battle_won()` calls `WorldEventManager.end_event("roaming_boss")`
- Player moves >160 world units (~80 tiles) away → `WorldScene._tick_roaming_boss()` calls `end_event`
- 5 minutes (300 s) elapse → same despawn path

**Rewards:** `is_boss=true` → BattleScene applies 50 HP override, phase-2 deck swap at 50% HP, and drops all cards from `drop_pool` (7 rare/unique cards). Coin reward: 40. XP: 150.

**Not persisted as defeated:** the roaming boss has no fixed entity ID in `SaveManager.defeated_enemies`, so it can respawn after its cooldown expires.

`SceneManager._on_battle_won()` handles both `"card_reward"` (single string, regular) and `"card_rewards"` (list, boss).

### EnemyNPC Scene (`scenes/world/entities/EnemyNPC.gd`)

Static entity — no movement AI. Engagement happens in two ways:

**Interact-to-engage (all enemies):**
Player presses E / taps interact button within `INTERACT_RANGE` (1.5 units). `WorldScene._handle_interact()` calls `enemy.engage()`. Works on every enemy type.

**Proximity-engage (tracking enemies only):**
Enemies with `tracking: true` in their spawn data have an `Area3D` (sphere, radius = `AUTO_BATTLE_RANGE` = 1.5 units) added at `_ready()`. When the player's `CharacterBody3D` (layer 1) enters the sphere, `_on_body_entered()` fires and calls `engage()` with the following guards:
- `_alive` must be true (prevents double-trigger)
- `SceneManager.can_proximity_engage()` must be true — returns false while `_state != State.WORLD` or `_proximity_engage_blocked` is set (2 s immunity window after returning from battle)
- `SaveManager.is_enemy_defeated(id)` must be false (already-defeated enemies with stale Area3D state)

**Tracking split (per enemy type):**
`EnemyRegistry.is_tracking(type_id)` encodes the aggressiveness split:
- Aggressive (tracking = true): `undead_elite`, `ghoul_pack`, `roaming_terror`
- Wanderer (tracking = false, interact-only): `undead_basic`, `undead_horde`, duelists

Dungeon, spire, and depth-placed named-map enemies always have `tracking: true`.

**Post-battle immunity:** `SceneManager._restore_world()` sets `_proximity_engage_blocked = true` and creates a 2 s `SceneTreeTimer` to clear it. This prevents chain-engagement immediately after respawning near an enemy.

**`engage()` method:** Sets `_alive = false`, deduplicates the enemy data dict, resolves deck / boss flags from `EnemyRegistry`, plays `enemy_engage` SFX, emits `GameBus.enemy_engaged(data)`, and calls `queue_free()`.

`EnemyNPC` is placed by `TerrainMath.spawn_entity()` (called from `ChunkRenderer` for infinite world, or via the chunk-data system for named maps). `init_from_data(data)` is always called before `add_child()`, so `_tracking` is set before `_ready()` runs.

### TownspersonNPC Scene (`scenes/world/entities/TownspersonNPC.gd`)

- Static `CharacterBody3D` (no movement)
- Shows dialogue string above head for 4 seconds after the player presses E within `INTERACT_RANGE`
- Dialogue is supplied by `BiomeDef.npc_dialogue[]` (randomly picked at spawn time)
- Re-triggers on each new interaction; no branching or quest state

### Duelist NPC (MapNpc variant)

Duelists are regular TownspersonNPCs that have `npc_type = "duelist"` in their `MapNpc` resource. They are wired entirely in data — no separate scene is needed.

**MapNpc duelist fields:**
- `duelist_enemy_id: String` — key into `EnemyRegistry` (e.g. `"duelist_novice"`)
- `wager_coins: int` — coins at stake per duel
- `required_duelist_ids: PackedStringArray` — `entity_id`s that must appear in `SaveManager.defeated_duelists` before this NPC will accept a duel (champion gate)
- `champion_reward_card: String` — card ID awarded once on first defeat (leave empty for regular duelists)

**Interact flow (`WorldScene._show_duel_offer_panel`):**
1. **Champion gate**: if `required_duelist_ids` is non-empty and any listed ID is not in `defeated_duelists` → shows "I only duel proven players. Beat the others in town first. (N more to go.)" — only Decline button shown.
2. If the player has fewer coins than the wager → shows "Come back when you can cover the wager."
3. If the NPC's `entity_id` is in `SaveManager.defeated_duelists` → rematch: wager is halved, prompt changes to "A rematch?".
4. Otherwise → "Care for a friendly duel? Wager: N coins."
5. **Duel** button: builds `enemy_data` dict (deck from `EnemyRegistry`, `duel_npc_id`, `champion_reward_card`) and emits `GameBus.duel_requested(enemy_data, wager)`.
6. **Decline** button: dismisses the panel.

Buttons are sized relative to viewport height (18 % × 7 %) for mobile parity.

**Save tracking:**
- `SaveManager.defeated_duelists: Array[String]` — list of `entity_id` strings for beaten duelists.
- Populated by `SaveManager.mark_duelist_defeated(npc_id)`, called from `SceneManager._on_duel_won()`.

**Champion legendary reward (`SceneManager._on_duel_won`):**
- If `champion_reward_card` is set and the NPC's `entity_id` is NOT already in `defeated_duelists` (first win), `add_card_instance(card_id, "legendary")` is called.
- Story flag `"champion_blancogov_defeated"` is set, which triggers the `regional_champion` achievement.
- A HUD message confirms the legendary award.

**Duelist enemy resources (placed in `data/enemies/`):**

| ID | Deck | Wager | Placed in |
|---|---|---|---|
| `duelist_novice` | Ghost×3, Skeleton×3, Zombie×2, Ghoul, Mend | 15 | madrian (tile 30,20) |
| `duelist_adept` | Ghost×2, Skeleton×2, Zombie×2, Ghoul×2, Mend, Wither, SurgeSpirit, EmberImp | 25 | blancogov (tile 35,50) |
| `duelist_champion` | Ghoul×2, BlitzGhoul×2, ShroudedWraith, VoidWyrm, Wither×2, SoulRend, DarkPact | 50 | blancogov (tile 55,50) — gated behind adept |

### Traveling Merchant Event

Spawned by `WorldEventManager` via `game_logic/WorldEvents.gd` on a 10–20 minute randomised interval of overworld play. Only fires when no other world event is active.

**Spawn:** `WorldEvents._spawn_traveling_merchant()` calls `WorldEventManager.find_spawn_tile()` to find a walkable grass tile 15–30 world-units from the player. The merchant's stock of 3 cards is seeded from `hash(Time.get_unix_time_from_system())` at spawn time, picked without replacement from `_MERCHANT_CARD_POOL` (18 rare/high-impact cards). The NPC is instantiated with `is_traveling=true` so it renders with a violet robe and "Traveling Merchant" label in purple.

**Interaction flow:**
1. Player presses E / taps interact prompt within `INTERACT_RANGE`
2. `WorldScene._handle_interact()` detects `npc_type == "traveling_merchant"` (checked before the base `"merchant"` case)
3. Emits `GameBus.traveling_shop_requested(stock, 30)` (30 coins per card)
4. `SceneManager._on_traveling_shop_requested()` opens `ShopScene` with `_custom_stock`, `_custom_price = 30`, `_custom_title = "Traveling Merchant's Rare Wares"` set before `add_child()`
5. `ShopScene._refresh()` branches on non-empty `_custom_stock` — shows only those cards at the custom price, no weapons/armor

**Despawn:** after 5 minutes (300 s) of overworld time, `WorldScene._tick_traveling_merchant()` calls `WorldEventManager.end_event("traveling_merchant")`. The cleanup callable removes the NPC from `_npc_nodes` and `_active_npc_data` and calls `queue_free()`.

**HUD toast on spawn:** "You hear distant wagon wheels…" (no minimap marker — discovery by chance is intentional).

**Premium card pool** (18 cards, 3 selected per event):  
`void_wyrm`, `iron_revenant`, `phoenix_rise`, `ancient_guardian`, `dusk_vampire`, `soul_harvest`, `time_warp`, `dark_pact`, `soul_rend`, `shrouded_wraith`, `veiled_paladin`, `ash_warden`, `duel_crown`, `surge_spirit`, `dawn_guardian`, `dawn_paladin`, `blitz_ghoul`, `void_creeper`

**No persistence as defeated** — the merchant has no fixed entity ID in `SaveManager`; it can reappear after its cooldown.

### MerchantNPC Scene (`scenes/world/entities/MerchantNPC.gd`)

- Static NPC with gold-coloured robe to distinguish it from regular townspeople
- NPC data dictionary has `"npc_type": "merchant"` set in the data; `WorldScene._handle_interact()` checks this field and emits `GameBus.shop_requested` instead of showing dialogue
- Placeable in named maps via the `MERCHANT x z` directive in `.txt` map files; `WorldMap` parser adds the merchant to the `npcs` array with `npc_type: "merchant"`
- Spawned procedurally in infinite-world grassland and forest biomes at ~5% chance per chunk by `InfiniteWorldGen._gen_entities()`
- `ChunkRenderer._spawn_entities()` instantiates `MerchantNPC.tscn` when `npc_type == "merchant"`, `TownspersonNPC.tscn` otherwise
- Opening the shop: `SceneManager._on_shop_requested()` instantiates `ShopScene` as an overlay on the current world scene and tracks state `State.SHOP`

### Spawn Persistence

On `WorldScene._ready()`, before placing entities:
1. Query `SaveManager.defeated_enemies` for IDs
2. Skip instantiating any entity whose ID is in that set

This means defeated enemies stay gone across sessions.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **EnemyRegistry** | Data source | Resolves `EnemyData` (deck array) by type ID at spawn and at battle start |
| **InfiniteWorldGen** | Spawner | Calls `EnemyRegistry.type_for_biome()` during `_gen_entities()` to pick enemy type per chunk |
| **WorldMap** | Spawner | Named-map ENEMY lines optionally include a type string; resolved via `EnemyRegistry` |
| **GameBus** | Signal hub | `enemy_engaged(data)` → SceneManager triggers BattleScene; `battle_won` / `battle_lost` → enemy reacts |
| **BattleScene** | Consumer | Reads `enemy_data["deck"]` from the engaged signal to build `PlayerState[1].draw_pile` |
| **SaveManager** | Persistence | `mark_enemy_defeated(id)` and `defeated_enemies` set prevent respawn |
| **BiomeDef** | Dialogue source | `BiomeDef.npc_dialogue[]` supplies TownspersonNPC dialogue lines |
| **GameBus** | Signal | `shop_requested` emitted when player interacts with a MerchantNPC; routed to `SceneManager._on_shop_requested()` |
| **GameBus** | Signal | `duel_requested(enemy_data, wager)` emitted from duel offer panel; `duel_won` / `duel_lost` resolve wager and update `SaveManager.defeated_duelists` |
| **ShopScene** | Overlay | Opened on `shop_requested`; lists all cards for 15 coins each; emits `closed` when player leaves |
| **IsoConst** | Constants | `AUTO_BATTLE_RANGE` (1.5 — proximity sphere radius), `INTERACT_RANGE` (1.5 — E-key range), `TRACKING_SPEED` (2.5 — reserved for future movement AI) |
| **SceneManager** | Guard | `can_proximity_engage()` returns false during battle or 2 s post-battle immunity window |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Enemy data resources | `data/enemies/*.tres` | One per enemy type: `undead_basic.tres`, `undead_horde.tres`, `ghoul_pack.tres`, `undead_elite.tres`, `roaming_terror.tres` |
| `EnemyRegistry.gd` | `autoloads/EnemyRegistry.gd` | Autoload singleton; registered in `project.godot` |
| EnemyNPC scene | `scenes/world/entities/EnemyNPC.tscn` | `CharacterBody3D` + `Sprite3D` + `CollisionShape3D` |
| TownspersonNPC scene | `scenes/world/entities/TownspersonNPC.tscn` | Static NPC with dialogue label |
| Enemy sprite texture | `assets/textures/pixel_art/` | Per-enemy-type sprite; falls back to placeholder if missing |
| NPC sprite texture | `assets/textures/pixel_art/` | Townsperson sprite |
