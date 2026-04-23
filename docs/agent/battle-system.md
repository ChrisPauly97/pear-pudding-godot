# Battle System

## Key Features

- Turn-based collectible card game (TCG) battles between the player and an enemy
- Four card types: Ghost, Skeleton, Zombie, Ghoul — each with distinct mana cost, attack, and health
- Per-player 5-slot board zone for deploying minions
- Mana system that grows by 1 each turn, capped at 10
- Summoning sickness: newly played minions cannot attack on their first turn
- One attack per minion per turn (reset at turn start)
- Hero health: 30 HP per player; reduce the opponent's hero to 0 to win
- Basic AI that auto-plays and attacks on the enemy turn
- Drag-to-play card UI with hand, board, and hero views

---

## How It Works

### Data Model

All battle state is pure GDScript with no rendering dependency:

```
GameState          — root object; owns two PlayerState instances, tracks whose turn it is
  PlayerState[0]   — human player (hero, hand, board, draw pile, discard pile)
  PlayerState[1]   — AI enemy  (same structure)
    HeroState      — current HP, current mana, max mana
    ZoneState      — 5 board slots; each slot holds a CardInstance or null
    CardInstance   — runtime card (template ref, current HP, summoning_sick flag, attacks_this_turn)
```

`CardInstance` wraps a `CardData` resource (loaded from `data/cards/*.tres`) and tracks mutable runtime state separately from the static template data. Runtime-only keyword state: `shroud_active: bool` starts `true` for Shroud minions and is set `false` by game logic after the first hit is absorbed.

### Turn Sequence

1. **Turn start** — active player's max mana increments (min 1, max 10); current mana refills to max; all minion `attacks_this_turn` reset to 0; all `summoning_sick` flags cleared.
2. **Draw** — active player draws one card from their draw pile (shuffles discard into draw if empty).
3. **Action phase** — active player plays cards and/or attacks until they press "End Turn":
   - *Play card*: costs mana equal to `CardData.cost`; card moves from hand to an empty board slot; new `CardInstance` is created with `summoning_sick = true`.
   - *Attack with minion*: target is any enemy minion or the enemy hero; damage is applied to both combatants; destroyed minions move to discard.
   - *Attack hero directly*: if no enemy minions block, or player targets hero explicitly.
4. **AI turn** — `BasicAI` evaluates board state, plays affordable cards greedily (lowest cost first), then attacks with every available minion (targets minions before hero).
5. **Win check** — after any damage event, if either hero drops to 0 HP `GameState` emits `battle_ended` with the result.

### Card Data

Each `CardData` resource (`data/cards/*.tres`) stores:
- `id: String` — canonical identifier (e.g. `"ghost"`)
- `display_name: String`
- `cost: int` — mana cost
- `attack: int`
- `health: int`
- `card_class: String` — `"minion"` (default) or `"spell"`
- `magic_type: String` — `"light"` | `"dark"` | `""` (non-magic cards)
- `magic_branch: String` — `"ember"` | `"dawn"` | `"dusk"` | `"ash"` | `""`
- `keywords: Array[String]` — passive keyword abilities; valid values are the constants in `game_logic/battle/Keywords.gd`: `"ward"`, `"surge"`, `"shroud"`. Defaults to `[]`; omitting from a `.tres` file is safe.
- `spell_effect: String` — canonical effect key dispatched by `_resolve_spell_effect` in `BattleScene.gd`; `""` for minions. Supported values:
  - `deal_damage_single` — deal spell_power damage to first enemy minion (or hero if board empty)
  - `deal_damage_all` — deal spell_power damage to all enemy minions
  - `deal_damage_random` — deal spell_power damage to a random enemy minion (or hero if board empty)
  - `debuff_attack` — reduce all enemy minion attack by spell_power (floor 0)
  - `destroy_low_hp` — destroy all enemy minions with health ≤ spell_power
  - `resurrect_last` — resurrect last friendly minion from discard with full HP
  - `heal_single` — restore spell_power HP to first friendly minion (cap at max_health)
  - `heal_all` — restore spell_power HP to all friendly minions (cap at max_health)
  - `shield_minion` — add spell_power armor to first friendly minion (armor reduces incoming damage)
  - `buff_attack` — increase attack of first friendly minion by spell_power
  - `lifesteal_hit` — deal spell_power damage to first enemy minion; heal caster hero by same amount
  - `mana_drain` — reduce enemy hero current mana by spell_power (floor 0)
  - `curse_minion` — reduce first enemy minion attack and health by spell_power (destroy if health ≤ 0)
  - `draw_card` — caster draws spell_power additional cards from their deck
- `spell_power: int` — numeric parameter for the effect (damage amount, stat reduction, etc.); `0` for minions

Minion cards (Ghost, Skeleton, Zombie, Ghoul) leave the four spell fields at their defaults (`""` / `0`) and are unaffected.

`CardRegistry` (autoload) loads all `.tres` files from `data/cards/` at startup and exposes `get_card(id)` for lookups.

### BasicAI Logic (`ai/BasicAI.gd`)

```
1. Collect playable cards (cost ≤ current mana), sort by cost ascending
2. For each card: play it into the first empty slot, subtract mana; repeat until no affordable cards or no empty slots
3. For each non-sick minion with attacks_this_turn == 0:
   a. If enemy has minions → attack the weakest (lowest HP) minion
   b. Otherwise → attack enemy hero directly
```

### BattleScene UI (`scenes/battle/BattleScene.gd`)

- Renders hand as a horizontal row of card buttons
- Renders each player's board as 5 slot panels with status icons (P/A/F/S colored labels)
- Hero panels show current/max HP, mana pips, and status icons
- Drag-to-play: card dragged from hand onto an empty board slot triggers `GameState.play_card()`
- **Spell targeting (TID-058):** targeted spells (`_TARGETED_EFFECTS = ["deal_damage_single"]`) show a cyan-border highlight on valid targets; player clicks to resolve; "Cancel Spell" button returns card to hand
- **Enemy intent banner (TID-059):** before AI actions execute, a centered panel shows what the AI plans (e.g. "Enemy will play Ghost"); hides when actions complete
- **Battle SFX (TID-080):** Full coverage — `card_draw` plays at player turn start (after game-over check in `_on_turn_ended(0)`); `card_play` plays on card drop; `spell_resolve` plays at the top of `_resolve_spell_effect` (covers player, AI, and auto-resolved spells); `attack` plays on all minion attacks; `battle_win`/`battle_lose` play at game end. All SFX are registered in `AudioManager.SFX_PATHS`; AudioManager silently no-ops if the wav file is absent.
- **Background music (TID-081):** `AudioManager.play_music(path)` loads an OGG file, plays it at −6 dB (≈0.5 linear), and loops via `finished` signal reconnect; same-track guard prevents restarts; graceful no-op if file absent. `BattleScene._ready()` calls `AudioManager.play_music("res://assets/audio/music/battle.ogg")`. `WorldScene` detects biome changes in `_update_chunks()` via `InfiniteWorldGen.biome_for_chunk()` and plays the matching track from `_BIOME_MUSIC` (grasslands / forest / desert / scorched / mountains). Named-map worlds play `dungeon.ogg`. On `GameBus.battle_won`, WorldScene resumes the correct world track (biome or dungeon). All music files are under `assets/audio/music/*.ogg`; absent files are silently skipped.
- **Status effect processing (TID-061):** at start of each player's turn, poison ticks (damage = value, decrement), freeze decrements, hero stun decrements; minion stun handled by `CardInstance.start_turn()` via `out_of_play`
- **Screen shake (TID-079):** `_trigger_shake(magnitude, duration)` tweens the BattleScene root Control's `position` through random ±magnitude offsets every 0.05s for the specified duration, then snaps back to origin. `_is_shaking` flag prevents overlapping shakes. `_check_shake_from_snapshot(snap)` evaluates the HP-diff snapshot: hero death triggers a 10px/0.35s shake; any single-step hit of ≥5 HP triggers a 5px/0.2s shake. Called at all 8 snapshot sites.
- **Hit flash (TID-078):** `_flash_node(node, color)` instantly sets a node's `modulate` to the flash color then tweens back to white over 0.25s. Red `(1, 0.3, 0.3)` for damage, green `(0.3, 1, 0.5)` for healing. At direct attack sites the target/attacker panels are captured before damage and flashed immediately (before `remove_card`, so dying minions flash too). At spell/AI/status sites `_flash_from_snapshot()` reuses the HP-diff snapshot to flash all surviving cards/heroes that had HP changes.
- **Floating damage/heal numbers (TID-077):** a `CanvasLayer` at layer 128 holds transient Label nodes. Before each damage/healing action, `_snapshot_hp_positions()` captures the HP and screen position of every card and hero on the board. After the action, `_spawn_float_labels_from_snapshot()` compares current HP to the snapshot and spawns labels for any delta. Labels tween upward 70px and fade from opaque to transparent over 0.8s, then `queue_free()`. Red (`#FF4444`) for damage, green (`#44FF88`) for healing. Covers: player minion attacks, player spells (non-targeted and targeted), AI actions, status tick damage, and auto-spell resolution.
- "End Turn" button calls `GameState.end_turn()`; AI actions fire after a short delay for readability
- Listens to `GameBus` signals to refresh UI after each state change

### Status Effects Data Model (TID-060)

`CardInstance` and `HeroState` each carry a `status_effects: Dictionary` (key: effect_id, value: int duration/stacks):

| Effect | Stored on | Behaviour |
|---|---|---|
| `poison` | CardInstance, HeroState | Deal value damage at turn start; value decrements each tick; removed at 0 |
| `armor` | CardInstance, HeroState | Absorbs incoming damage in `take_damage()`; remaining armor updated after each hit |
| `freeze` | CardInstance, HeroState | Minion: blocks `can_attack()`; hero: blocks `can_play()` via PlayerState; decrements at turn start |
| `stun` | CardInstance, HeroState | Like freeze but also bridges to `CardInstance.out_of_play` for minion attack blocking; hero stun decremented in BattleScene |

Helper methods on both types: `apply_status(id, val)`, `has_status(id)`, `get_status_value(id)`, `clear_status(id)`, `take_damage(dmg)`.

New GameBus signals: `status_applied(entity_id, effect_id, value)`, `status_ticked(entity_id, effect_id, remaining)`.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **World / Enemies** | Trigger → Battle | `GameBus.enemy_engaged(enemy_data)` fires when the player walks into an enemy; `enemy_data["enemy_deck"]` carries the enemy's card list |
| **EnemyRegistry** | Data source | `EnemyRegistry.get_enemy(type)` returns enemy deck composition by type string |
| **CardRegistry** | Data source | `CardRegistry.get_card(id)` resolves card template for each card in the deck |
| **SaveManager** | Player deck | `SaveManager.player_deck` is the `Array[String]` of card IDs loaded into `PlayerState[0]` at battle start |
| **SceneManager** | Scene routing | `GameBus.battle_won` → SceneManager grants reward card + restores WorldScene; `GameBus.battle_lost` → SceneManager loads GameOverScene |
| **EnemyRegistry** | Drop pool | `EnemyRegistry.get_drop_pool(enemy_type)` returns cards that may drop; BattleScene picks one at random and shows the victory overlay |
| **Inventory / Deck** | Deck source | Player's active battle deck is built from `SaveManager.player_deck` (managed in InventoryScene) |
| **GameBus signals** | Both | `card_played`, `card_attacked`, `turn_ended`, `battle_ended`, `status_applied`, `status_ticked` — BattleScene listens to turn_ended to refresh the UI; status signals available for future subscribers |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Card data resources | `data/cards/*.tres` | One `CardData` resource per card type; minion fields: id, display_name, cost, attack, health; spell fields: card_class="spell", magic_type, magic_branch, spell_effect, spell_power |
| Enemy data resources | `data/enemies/*.tres` | `EnemyData` resource with id, display_name, deck (Array of card id strings) |
| BattleScene scene | `scenes/battle/BattleScene.tscn` | Root scene for battle UI overlay |
| Card slot textures | `assets/textures/` | Optional card art per id (falls back to colored panel if missing) |

No 3D geometry or shaders are required — the battle system is a 2D UI overlay.

---

## Battle UX Essentials (GID-026)

### Card Inspect Overlay (TID-086)

`scenes/battle/CardInspectOverlay.gd` — instantiated by `BattleScene._show_card_inspect(card)`.

- Full-screen dimmed backdrop (tap outside → dismiss)
- Centered panel showing: card color bar, name, class/magic type, cost/attack/health, description, spell effect in plain English, active status effects
- Close button + Escape key to dismiss
- Trigger: right-click on any card panel (all zones, always active via `_bind_card_input`)
- Mobile/touch: tap a hand card without dragging (tracked via `_drag_moved` flag in `_input()`)
- `_SPELL_EFFECT_LABELS` dictionary maps effect IDs to human-readable strings with `[power]` substitution

### Pause System (TID-088)

`BattleScene` manages pause state via `_paused: bool` and `_pause_overlay: CanvasLayer`.

- Pause button ("II") at top of SidePanel, `process_mode = ALWAYS`, `~5% vh` square
- `get_tree().paused = true/false` — pauses all non-ALWAYS nodes (AI timers, process loop, tweens)
- Pause overlay: `CanvasLayer` layer 200 with `process_mode = ALWAYS`; contains: Resume, Settings, Return to Menu
- "Return to Menu" shows inline confirm dialog before navigating away
- "Settings" opens `SettingsScene` inline in the pause overlay's CanvasLayer
- Escape key toggles pause (desktop only)
- `NOTIFICATION_APPLICATION_FOCUS_OUT` auto-pauses on app backgrounding (mobile)
